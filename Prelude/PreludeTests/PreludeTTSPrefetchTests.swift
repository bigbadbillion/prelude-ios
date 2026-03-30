import AVFoundation
import XCTest

@testable import Prelude

/// Validates the OS voice-asset prefetch *pattern* (speak minimal utterance + immediate stop).
/// iOS does not expose Premium voice **install progress** or a “download finished” callback—only whether
/// `AVSpeechSynthesisVoice(identifier:)` / `speechVoices()` can resolve Premium/Enhanced yet; the wait sheet polls that.
@MainActor
final class PreludeTTSPrefetchTests: XCTestCase {
    final class MockSynth: PreludeSpeechSynthesizing {
        var utterancesSpoken: [AVSpeechUtterance] = []
        var stopBoundary: AVSpeechBoundary?

        func speak(_ utterance: AVSpeechUtterance) {
            utterancesSpoken.append(utterance)
        }

        func stopSpeaking(at boundary: AVSpeechBoundary) {
            stopBoundary = boundary
        }
    }

    func testPrefetchMechanismCallsSpeakThenStopWhenVoiceProvided() {
        let mock = MockSynth()
        guard let voice = AVSpeechSynthesisVoice(language: "en-US") else {
            XCTFail("Expected built-in en-US voice in test environment")
            return
        }
        PreludeTTS.runOSVoiceAssetPrefetch(synthesizer: mock, voice: voice)
        XCTAssertEqual(mock.utterancesSpoken.count, 1)
        XCTAssertEqual(mock.utterancesSpoken.first?.voice?.identifier, voice.identifier)
        XCTAssertEqual(mock.stopBoundary, .immediate)
    }

    func testPrefetchMechanismNoOpsWhenVoiceNil() {
        let mock = MockSynth()
        PreludeTTS.runOSVoiceAssetPrefetch(synthesizer: mock, voice: nil)
        XCTAssertTrue(mock.utterancesSpoken.isEmpty)
        XCTAssertNil(mock.stopBoundary)
    }

    /// After any completed session, Home must not block on voice tier (no modal)—pure policy, no device voices needed.
    func testVoiceWaitNotRequiredAfterUserHasCompletedSession() {
        XCTAssertFalse(PreludeTTS.shouldWaitForPremiumVoiceBeforeFirstSession(userHasCompletedSession: true))
    }
}
