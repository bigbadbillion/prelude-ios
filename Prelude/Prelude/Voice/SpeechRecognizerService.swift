import AVFoundation
import Foundation
import Speech

/// Streaming STT with amplitude for **PresenceShape**. PRD prefers **SpeechAnalyzer** when available; this uses **SFSpeechRecognizer** (PRD §14 fallback).
@MainActor
final class SpeechRecognizerService: NSObject {
    enum SpeechRecognizerServiceError: Error {
        case simulatorUnavailable
        case invalidAudioFormat(sampleRate: Double, channelCount: Double)
    }

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private(set) var amplitude: Double = 0
    private(set) var liveTranscript: String = ""

    private var onPartial: ((String, Bool) -> Void)?
    var onAmplitude: ((Double) -> Void)?

    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
    }

    func startCapturing(
        onPartial: @escaping (String, Bool) -> Void,
        onError: ((Error) -> Void)? = nil
    ) throws {
        stopCapturing()
        self.onPartial = onPartial
        liveTranscript = ""

        #if targetEnvironment(simulator)
        // iOS Simulator microphone/audio input is not reliable for AVAudioEngine taps.
        // The simulator can produce an invalid audio format, which AVFAudio throws as an NSException.
        // We treat it as "unavailable" and let the caller fall back to scripted text.
        throw SpeechRecognizerServiceError.simulatorUnavailable
        #else
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = audioEngine.inputNode

        let format = input.inputFormat(forBus: 0)
        let sampleRate = Double(format.sampleRate)
        let channelCount = Double(format.channelCount)
        guard sampleRate > 0, channelCount > 0 else {
            throw SpeechRecognizerServiceError.invalidAudioFormat(sampleRate: sampleRate, channelCount: channelCount)
        }
        #endif

        // The `input`/`format` are defined inside the non-simulator branch.
        #if !targetEnvironment(simulator)
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            self?.updateAmplitude(buffer: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                    self.onPartial?(self.liveTranscript, result.isFinal)
                }
                if let error {
                    onError?(error)
                }
            }
        }
        #endif
    }

    private nonisolated func updateAmplitude(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let n = Int(buffer.frameLength)
        if n == 0 { return }
        var sum: Float = 0
        for i in 0 ..< n {
            // We only read channel 0; if channel 0 isn't present, floatChannelData will be nil above.
            let s = data[0][i]
            sum += s * s
        }
        let rms = sqrt(sum / Float(n))
        let level = min(1, max(0, Double(rms) * 8))
        Task { @MainActor in
            self.amplitude = level
            self.onAmplitude?(level)
        }
    }

    func stopCapturing() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        onPartial = nil
        amplitude = 0
    }
}
