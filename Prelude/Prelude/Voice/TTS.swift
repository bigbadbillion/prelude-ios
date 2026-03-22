import AVFoundation
import Foundation

/// PRD §7 — premium / enhanced voices; rate 0.48, pitch 0.95, volume 0.9
enum PreludeTTS {
    private static let preferredVoiceIdentifiers = [
        "com.apple.voice.premium.en-US.Zoe",
        "com.apple.voice.premium.en-US.Evan",
        "com.apple.voice.enhanced.en-US.Zoe",
        "com.apple.voice.enhanced.en-US.Evan",
    ]

    static func pickVoice() -> AVSpeechSynthesisVoice? {
        for id in preferredVoiceIdentifiers {
            if let v = AVSpeechSynthesisVoice(identifier: id) {
                return v
            }
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    static func configure(_ utterance: AVSpeechUtterance) {
        utterance.rate = 0.48
        utterance.pitchMultiplier = 0.95
        utterance.volume = 0.9
        if let v = pickVoice() {
            utterance.voice = v
        }
    }
}
