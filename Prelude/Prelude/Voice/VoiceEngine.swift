import AVFoundation
import Combine
import Foundation
import Speech

private final class TTSDelegateBox: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?
    var onWillSpeakRange: ((NSRange, AVSpeechUtterance) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        onWillSpeakRange?(characterRange, utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
    }
}

/// Coordinates STT, TTS, silence detection (800ms), and **VoiceState** (PRD §7).
@MainActor
final class VoiceEngine: ObservableObject {
    @Published private(set) var voiceState: VoiceState = .idle
    @Published private(set) var amplitude: Double = 0
    @Published private(set) var agentText: String = ""
    @Published private(set) var transcriptLines: [String] = []
    @Published private(set) var liveTranscript: String = ""
    @Published private(set) var micPermissionGranted: Bool?
    @Published private(set) var errorMessage: String?

    private let speech = SpeechRecognizerService()
    private let synthesizer = AVSpeechSynthesizer()
    private let ttsDelegate = TTSDelegateBox()

    private var silenceThresholdMs: Int = 800
    private var silenceWorkItem: DispatchWorkItem?

    /// First string is the **clean** user line for logs; second adds optional host context (e.g. barge-in) for the model only.
    private var onUserTurnComplete: ((String, String) async -> (line: String?, endSessionAfter: Bool))?
    private var onSessionEnd: (() -> Void)?
    private var onLiveTranscriptScrollHint: (() -> Void)?
    private var onCrisis: (() -> Void)?
    private var endSessionAfterThisUtterance = false

    /// After barge-in, `didFinish`/`didCancel` must not tear down STT that is still collecting the user’s interrupt.
    private var suppressListenRestartAfterTTS = false
    /// Prepended once to the next finalized user transcript so the agent knows audio was cut short.
    private var pendingBargeInPreamble: String?

    private var scriptResponseIndex = 1
    private var isPaused = false

    /// After we stop TTS due to barge-in, ignore ASR finals briefly.
    /// This reduces "phantom words" caused by the stop transition / speaker bleed.
    private var bargeInIgnoreUntil: Date?

    /// Tracks whether the STT engine is currently capturing so we can avoid stop/start churn
    /// (which can lead to audio render errors and session freezes).
    private var isSpeechCapturing = false

    /// Minimum characters in a partial transcript before we stop TTS (barge-in).
    /// Kept relatively high to avoid canceling TTS on playback artifacts when ASR misfires.
    private static let bargeInMinCharacters = 12

    /// Smoothed mic level (~PRD §10.5 — avoid twitchy motion).
    private var micSmoothed: Double = 0
    /// Envelope driven by `willSpeakRangeOfSpeechString` + decay while agent TTS runs.
    private var agentSpeechEnvelope: Double = 0
    private var ttsDecayTimer: Timer?

    /// Opening line is index 0; responses start at 1 (matches Expo `session.tsx`).
    private static var agentScript: [String] { VoiceEngineScript.lines }

    init() {
        ttsDelegate.onFinish = { [weak self] in
            Task { @MainActor in
                await self?.agentDidFinishSpeaking()
            }
        }
        ttsDelegate.onWillSpeakRange = { [weak self] range, utterance in
            Task { @MainActor in
                self?.applyAgentSpeechBurst(range: range, utterance: utterance)
            }
        }
        synthesizer.delegate = ttsDelegate
        // Use the default system audio session for TTS to avoid fighting with the mic/STT audio graph.
        // (The earlier duplex/AEC changes caused instability; this restores the prior stable split.)
        synthesizer.usesApplicationAudioSession = false
        speech.onAmplitude = { [weak self] v in
            Task { @MainActor in
                self?.applyMicAmplitude(v)
            }
        }
    }

    deinit {
        ttsDecayTimer?.invalidate()
    }

    private func invalidateTTSTimer() {
        ttsDecayTimer?.invalidate()
        ttsDecayTimer = nil
    }

    /// EMA toward raw mic level while listening (PRD §10.5 — averaged feel).
    private func applyMicAmplitude(_ raw: Double) {
        guard voiceState == .listening else { return }
        let alpha = 0.22
        micSmoothed = micSmoothed * (1 - alpha) + raw * alpha
        amplitude = micSmoothed
    }

    private func applyAgentSpeechBurst(range: NSRange, utterance: AVSpeechUtterance) {
        guard voiceState == .speaking else { return }
        let len = max(1, range.length)
        let boost = min(1, 0.18 + Double(len) * 0.038)
        agentSpeechEnvelope = min(1, agentSpeechEnvelope + boost)
        amplitude = agentSpeechEnvelope
        ensureTTSDecayTimer()
    }

    private func ensureTTSDecayTimer() {
        guard ttsDecayTimer == nil || !(ttsDecayTimer?.isValid ?? false) else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickAgentSpeechDecay()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ttsDecayTimer = timer
    }

    private func tickAgentSpeechDecay() {
        guard voiceState == .speaking, synthesizer.isSpeaking else {
            invalidateTTSTimer()
            return
        }
        agentSpeechEnvelope *= 0.87
        if agentSpeechEnvelope < 0.018 {
            agentSpeechEnvelope = 0
        }
        amplitude = agentSpeechEnvelope
    }

    private func resetPresenceLevelsForSpeaking() {
        invalidateTTSTimer()
        micSmoothed = 0
        agentSpeechEnvelope = 0.1
        amplitude = agentSpeechEnvelope
        ensureTTSDecayTimer()
    }

    private func resetPresenceLevelsAfterSpeaking() {
        invalidateTTSTimer()
        agentSpeechEnvelope = 0
        amplitude = 0
        micSmoothed = 0
    }

    func configure(
        silenceThresholdMs: Int = 800,
        onUserTurnComplete: @escaping (String, String) async -> (line: String?, endSessionAfter: Bool),
        onSessionEnd: @escaping () -> Void,
        onLiveTranscript: (() -> Void)? = nil,
        onCrisis: (() -> Void)? = nil
    ) {
        self.silenceThresholdMs = silenceThresholdMs
        self.onUserTurnComplete = onUserTurnComplete
        self.onSessionEnd = onSessionEnd
        onLiveTranscriptScrollHint = onLiveTranscript
        self.onCrisis = onCrisis
    }

    /// - Parameter openingText: Spoken first line; pass `nil` to use the default Expo script opening.
    func start(openingText: String? = nil) async {
        errorMessage = nil
        let speechStatus = await speech.requestAuthorization()
        let micGranted = await requestMicPermission()

        micPermissionGranted = micGranted && speechStatus == .authorized
        guard micPermissionGranted == true else {
            errorMessage = "Microphone or speech recognition permission is required."
            return
        }

        scriptResponseIndex = 1
        voiceState = .speaking
        let trimmed = openingText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let first = trimmed.isEmpty ? Self.agentScript[0] : trimmed
        agentText = first
        speak(first)
    }

    func pause() {
        isPaused = true
        speech.stopCapturing()
        isSpeechCapturing = false
        synthesizer.pauseSpeaking(at: .word)
        voiceState = .paused
        cancelSilenceTimer()
        invalidateTTSTimer()
        bargeInIgnoreUntil = nil
    }

    func resume() {
        isPaused = false
        if synthesizer.isSpeaking {
            synthesizer.continueSpeaking()
            voiceState = .speaking
            ensureTTSDecayTimer()
        } else {
            Task { await beginListening() }
            voiceState = .listening
        }
    }

    func end() {
        cancelSilenceTimer()
        invalidateTTSTimer()
        speech.stopCapturing()
        isSpeechCapturing = false
        synthesizer.stopSpeaking(at: .immediate)
        voiceState = .ended
        errorMessage = nil
        liveTranscript = ""
        agentSpeechEnvelope = 0
        amplitude = 0
        micSmoothed = 0
        suppressListenRestartAfterTTS = false
        pendingBargeInPreamble = nil
        bargeInIgnoreUntil = nil
    }

    private func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Prevent stale STT errors from showing the mic overlay during agent speech.
        errorMessage = nil
        resetPresenceLevelsForSpeaking()
        let u = AVSpeechUtterance(string: trimmed)
        PreludeTTS.configure(u)
        // Duplex barge-in (mic while TTS speaks) is disabled during the recovery path.
        // We return to the stable behavior: start listening after TTS finishes.
        isSpeechCapturing = false
        bargeInIgnoreUntil = nil
        pendingBargeInPreamble = nil
        suppressListenRestartAfterTTS = false
        synthesizer.speak(u)
    }

    /// Duplex barge-in path (disabled in recovery mode).
    private func runDuplexSpeak(utterance: AVSpeechUtterance) {
        // Keep method for future re-enabling, but do not start STT here.
        synthesizer.speak(utterance)
    }

    private func agentDidFinishSpeaking() async {
        guard !isPaused else { return }
        if voiceState == .ended { return }

        // Barge-in can trigger `didCancel`/`didFinish` delegate callbacks even after we already
        // transitioned into `.listening`. In that case, tearing down STT here makes the session
        // feel frozen and causes missing transcripts.
        if voiceState == .listening {
            suppressListenRestartAfterTTS = false
            return
        }

        if suppressListenRestartAfterTTS {
            suppressListenRestartAfterTTS = false
            resetPresenceLevelsAfterSpeaking()
            return
        }

        resetPresenceLevelsAfterSpeaking()
        if endSessionAfterThisUtterance {
            endSessionAfterThisUtterance = false
            end()
            onSessionEnd?()
            return
        }
        // In duplex mode we might already have STT capturing running. Restarting it here can
        // cause audio render errors and "freezes", so only stop/restart when needed.
        if isSpeechCapturing {
            bargeInIgnoreUntil = nil
            voiceState = .listening
            liveTranscript = ""
            cancelSilenceTimer()
            micSmoothed = 0
            amplitude = 0
            return
        }

        speech.stopCapturing()
        isSpeechCapturing = false
        await beginListening()
    }

    private func requestMicPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { cont in
                    AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
                }
            @unknown default:
                return false
            }
        } else {
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { cont in
                    session.requestRecordPermission { cont.resume(returning: $0) }
                }
            @unknown default:
                return false
            }
        }
    }

    private func beginListening() async {
        guard !isPaused else { return }
        voiceState = .listening
        liveTranscript = ""
        errorMessage = nil
        bargeInIgnoreUntil = nil
        cancelSilenceTimer()
        micSmoothed = 0
        amplitude = 0

        do {
            try speech.startCapturing(
                onPartial: { [weak self] text, isFinal in
                    Task { @MainActor in
                        self?.handleSpeechPartial(text: text, isFinal: isFinal)
                    }
                },
                onError: { [weak self] error in
                    Task { @MainActor in
                        self?.handleSTTError(error)
                    }
                }
            )
            isSpeechCapturing = true
        } catch {
            errorMessage = error.localizedDescription
            voiceState = .idle
            isSpeechCapturing = false

            // On iOS Simulator, audio capture is intentionally unavailable (see SpeechRecognizerService).
            // For UI testing, advance the scripted conversation so the session doesn't feel "frozen".
            if case SpeechRecognizerService.SpeechRecognizerServiceError.simulatorUnavailable = error {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    await self.finalizeUserTurn(transcript: "Simulated voice input")
                }
            }
        }
    }

    private func handleSTTError(_ error: Error) {
        // STT can emit late errors during our own stopCapturing() call
        // when we are already transitioning into `.processing`/`.speaking`.
        // In that case, don't clobber the UI or tear down the turn.
        guard voiceState == .listening || voiceState == .idle else { return }

        // Keep this path user-visible so TestFlight testers can recover.
        errorMessage = "Speech recognition error. Please tap Try again."
        voiceState = .idle
        cancelSilenceTimer()
        pendingBargeInPreamble = nil
        bargeInIgnoreUntil = nil
        isSpeechCapturing = false
        speech.stopCapturing()
    }

    private func handleSpeechPartial(text: String, isFinal: Bool) {
        if voiceState == .speaking {
            liveTranscript = text
            onLiveTranscriptScrollHint?()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // Barge-in is error-prone when ASR hears speaker/room bleed.
            // Only barge-in on a final segment reduces phantom cutoffs.
            let shouldBargeIn = isFinal && trimmed.count >= Self.bargeInMinCharacters

            if shouldBargeIn {
                suppressListenRestartAfterTTS = true
                pendingBargeInPreamble = "(They spoke over your last line.) "
                synthesizer.stopSpeaking(at: .immediate)
                voiceState = .listening
                bargeInIgnoreUntil = Date().addingTimeInterval(0.35)
                cancelSilenceTimer()
                micSmoothed = 0
                amplitude = 0
                liveTranscript = ""
            }
            return
        }

        guard voiceState == .listening else { return }

        if let until = bargeInIgnoreUntil, Date() < until {
            // Ignore ASR "finals" temporarily right after barge-in to avoid phantom words.
            // We still update UI so the user sees recognition progressing.
            liveTranscript = text
            onLiveTranscriptScrollHint?()
            cancelSilenceTimer()
            return
        }

        liveTranscript = text
        onLiveTranscriptScrollHint?()
        cancelSilenceTimer()

        if isFinal, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task { @MainActor in
                await finalizeUserTurn(transcript: text)
            }
            return
        }

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.finalizeUserTurn(transcript: self?.liveTranscript ?? "")
            }
        }
        silenceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(silenceThresholdMs), execute: work)
    }

    private func cancelSilenceTimer() {
        silenceWorkItem?.cancel()
        silenceWorkItem = nil
    }

    private func finalizeUserTurn(transcript: String) async {
        cancelSilenceTimer()
        // Set state early so any late STT errors from our own stopCapturing()
        // don't flip the UI back to `.idle` (which triggers the mic-unavailable overlay).
        errorMessage = nil
        voiceState = .processing
        speech.stopCapturing()
        isSpeechCapturing = false
        bargeInIgnoreUntil = nil

        let raw = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let agentPayload: String
        if let pre = pendingBargeInPreamble {
            agentPayload = pre + raw
            pendingBargeInPreamble = nil
        } else {
            agentPayload = raw
        }
        guard !raw.isEmpty else {
            pendingBargeInPreamble = nil
            await beginListening()
            return
        }

        transcriptLines.append(raw)
        onLiveTranscriptScrollHint?()
        micSmoothed = 0
        amplitude = 0

        if CrisisDetection.indicatesCrisis(raw) {
            onCrisis?()
            let line = CrisisDetection.spokenAcknowledgment
            agentText = line
            voiceState = .speaking
            endSessionAfterThisUtterance = true
            speak(line)
            return
        }

        let nextLine: String?
        let endAfter: Bool
        if let cb = onUserTurnComplete {
            let result = await cb(raw, agentPayload)
            nextLine = result.line
            endAfter = result.endSessionAfter
        } else {
            endAfter = false
            let idx = scriptResponseIndex
            if idx >= Self.agentScript.count {
                nextLine = nil
            } else {
                nextLine = Self.agentScript[idx]
                scriptResponseIndex += 1
            }
        }

        guard let line = nextLine, !line.isEmpty else {
            agentText = ""
            end()
            onSessionEnd?()
            return
        }

        agentText = line
        voiceState = .speaking
        if endAfter {
            endSessionAfterThisUtterance = true
        }
        speak(line)
    }
}
