import AVFoundation
import Foundation

/// Abstraction so unit tests can assert speak/stop without relying on real audio output.
@MainActor
protocol PreludeSpeechSynthesizing: AnyObject {
    func speak(_ utterance: AVSpeechUtterance)
    func stopSpeaking(at boundary: AVSpeechBoundary)
}

@MainActor
private final class PreludeAVSpeechSynthAdapter: PreludeSpeechSynthesizing {
    private let synthesizer: AVSpeechSynthesizer = {
        let s = AVSpeechSynthesizer()
        // Separate session from app `playAndRecord` (STT) and from system Siri routing quirks.
        s.usesApplicationAudioSession = false
        return s
    }()

    func speak(_ utterance: AVSpeechUtterance) {
        synthesizer.speak(utterance)
    }

    func stopSpeaking(at boundary: AVSpeechBoundary) {
        synthesizer.stopSpeaking(at: boundary)
    }
}

/// PRD §7 — premium / enhanced voices; rate 0.48, pitch 0.95, volume 0.9
enum PreludeTTS {
    /// Preferred **default** voices (Zoe/Evan). `pickVoice()` still upgrades to **any** English Premium/Enhanced
    /// from `speechVoices()` if these identifiers are not installed yet—so we are not limited to only these names.
    private static let preferredVoiceIdentifiers = [
        "com.apple.voice.premium.en-US.Zoe",
        "com.apple.voice.premium.en-US.Evan",
        "com.apple.voice.enhanced.en-US.Zoe",
        "com.apple.voice.enhanced.en-US.Evan",
    ]

    /// True when the resolved voice is Premium or Enhanced (not the built‑in compact/default tier).
    static func isPremiumOrEnhancedVoiceAvailable() -> Bool {
        guard let v = pickVoice() else { return false }
        switch v.quality {
        case .premium, .enhanced:
            return true
        default:
            return false
        }
    }

    /// First session only: wait if we would still use the standard (compact) tier so the user doesn’t hear robotic TTS by accident.
    /// There is no public API for install **progress**—only “ready or not”; UI should use an indeterminate indicator while polling.
    static func shouldWaitForPremiumVoiceBeforeFirstSession(userHasCompletedSession: Bool) -> Bool {
        !userHasCompletedSession && !isPremiumOrEnhancedVoiceAvailable()
    }

    static func pickVoice() -> AVSpeechSynthesisVoice? {
        for id in preferredVoiceIdentifiers {
            if let v = AVSpeechSynthesisVoice(identifier: id) {
                return v
            }
        }
        if let v = bestEnglishVoiceFromSpeechVoicesPreferringPremium() {
            return v
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Queues an OS-managed voice asset download when Premium/Enhanced isn’t local yet (no in-app UI).
    /// Schedules work on the main actor (`AVSpeechSynthesizer`); does not block app launch.
    static func prefetchPreferredVoiceAssets() {
        Task { @MainActor in
            let voice = voiceForOSAssetPrefetch()
            runOSVoiceAssetPrefetch(synthesizer: PreludeAVSpeechSynthAdapter(), voice: voice)
        }
    }

    /// Runs the AVFoundation prefetch pattern: assign voice, `speak` minimal utterance, stop immediately.
    /// - Parameter voice: Use only Premium or Enhanced; Compact does not queue higher-tier downloads.
    @MainActor
    static func runOSVoiceAssetPrefetch(synthesizer: PreludeSpeechSynthesizing, voice: AVSpeechSynthesisVoice?) {
        guard let voice else { return }
        let utterance = AVSpeechUtterance(string: " ")
        utterance.voice = voice
        synthesizer.speak(utterance)
        synthesizer.stopSpeaking(at: .immediate)
    }

    static func configure(_ utterance: AVSpeechUtterance) {
        utterance.rate = 0.48
        utterance.pitchMultiplier = 0.95
        utterance.volume = 0.9
        if let v = pickVoice() {
            utterance.voice = v
        }
    }

    // MARK: - Private

    private static func bestEnglishVoiceFromSpeechVoicesPreferringPremium() -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let english = all.filter { $0.language.hasPrefix("en") && !$0.voiceTraits.contains(.isNoveltyVoice) }
        if let v = english.first(where: { $0.quality == .premium }) { return v }
        if let v = english.first(where: { $0.quality == .enhanced }) { return v }
        return nil
    }

    /// Voice used only to nudge the OS to fetch Premium/Enhanced assets — not for playback fallback.
    private static func voiceForOSAssetPrefetch() -> AVSpeechSynthesisVoice? {
        for id in preferredVoiceIdentifiers {
            if let v = AVSpeechSynthesisVoice(identifier: id) {
                return v
            }
        }
        return bestEnglishVoiceFromSpeechVoicesPreferringPremium()
    }
}
