import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class AppState {
    var availability: PreludeModelAvailability = .resolve()
    var selectedTab: PreludeTab = .home
    var showSession: Bool = false
    /// After session completes, present brief for this session id (sheet).
    var sessionBriefToPresent: UUID?
    var showCrisisResources: Bool = false

    func refreshAvailability() {
        availability = PreludeModelAvailability.resolve()
    }

    func canStartSession() -> Bool {
        switch availability {
        case .available, .unknown:
            return true
        case .notSupported, .disabled, .downloading, .lowPower, .thermalThrottle:
            return false
        }
    }
}

enum PreludeTab: String, CaseIterable, Hashable {
    case home
    case history
    case weekly
    case settings
}
