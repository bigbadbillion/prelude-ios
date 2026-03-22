import SwiftUI

/// PRD §10.7 animation tokens
enum PreludeMotion {
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let gentle = Animation.easeInOut(duration: 0.4)
    static let ambient = Animation.easeInOut(duration: 3.8).repeatForever(autoreverses: true)
    static let reveal = Animation.easeOut(duration: 0.6)
    static let cardStagger: TimeInterval = 0.2
    static let sessionBackgroundShift: TimeInterval = 1.5
}
