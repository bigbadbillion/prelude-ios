import Foundation

/// PRD §7 + AppContext alignment; includes `interrupted` per PRD
enum VoiceState: String, Codable, Sendable {
    case idle
    case listening
    case processing
    case speaking
    case interrupted
    case paused
    case ended
}
