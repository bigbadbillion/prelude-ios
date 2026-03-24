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

    private var onUserTurnComplete: ((String) async -> (line: String?, endSessionAfter: Bool))?
    private var onSessionEnd: (() -> Void)?
    private var onLiveTranscriptScrollHint: (() -> Void)?
    private var onCrisis: (() -> Void)?
    private var endSessionAfterThisUtterance = false

    private var scriptResponseIndex = 1
    private var isPaused = false

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
        onUserTurnComplete: @escaping (String) async -> (line: String?, endSessionAfter: Bool),
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
        synthesizer.pauseSpeaking(at: .word)
        voiceState = .paused
        cancelSilenceTimer()
        invalidateTTSTimer()
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
        synthesizer.stopSpeaking(at: .immediate)
        voiceState = .ended
        errorMessage = nil
        liveTranscript = ""
        agentSpeechEnvelope = 0
        amplitude = 0
        micSmoothed = 0
    }

    private func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        resetPresenceLevelsForSpeaking()
        let u = AVSpeechUtterance(string: trimmed)
        PreludeTTS.configure(u)
        synthesizer.speak(u)
    }

    private func agentDidFinishSpeaking() async {
        guard !isPaused else { return }
        if voiceState == .ended { return }
        resetPresenceLevelsAfterSpeaking()
        if endSessionAfterThisUtterance {
            endSessionAfterThisUtterance = false
            end()
            onSessionEnd?()
            return
        }
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
        cancelSilenceTimer()
        micSmoothed = 0
        amplitude = 0

        do {
            try speech.startCapturing { [weak self] text, isFinal in
                Task { @MainActor in
                    self?.handlePartial(text: text, isFinal: isFinal)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            voiceState = .idle

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

    private func handlePartial(text: String, isFinal: Bool) {
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
        speech.stopCapturing()

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await beginListening()
            return
        }

        transcriptLines.append(trimmed)
        voiceState = .processing
        micSmoothed = 0
        amplitude = 0

        if CrisisDetection.indicatesCrisis(trimmed) {
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
            let result = await cb(trimmed)
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
