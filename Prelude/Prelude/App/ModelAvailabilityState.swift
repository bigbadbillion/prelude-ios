import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// PRD §3 — warm availability UX before sessions.
enum PreludeModelAvailability: Equatable {
    case available
    case notSupported
    case disabled
    case downloading
    case lowPower
    case thermalThrottle
    case unknown

    var title: String {
        switch self {
        case .available: return "Ready"
        case .notSupported: return "Apple Intelligence required"
        case .disabled: return "Turn on Apple Intelligence"
        case .downloading: return "Getting ready"
        case .lowPower: return "Low Power Mode"
        case .thermalThrottle: return "Cooling down"
        case .unknown: return "Checking availability"
        }
    }

    var message: String {
        switch self {
        case .available:
            return "Prelude is ready when you are."
        case .notSupported:
            return "Prelude requires Apple Intelligence. It's available on iPhone 15 Pro and later."
        case .disabled:
            return "Turn on Apple Intelligence in Settings → Apple Intelligence & Siri to use Prelude."
        case .downloading:
            return "Prelude is getting ready — Apple Intelligence is setting up in the background. This only happens once."
        case .lowPower:
            return "Connect to power to start a session — Prelude needs full performance to run."
        case .thermalThrottle:
            return "Your iPhone needs a moment to cool down. Prelude will be ready shortly."
        case .unknown:
            return "We couldn't verify Apple Intelligence status. You can still explore the app."
        }
    }

    /// Resolves UI / session gating from device state and (on iOS 26+) **SystemLanguageModel** availability.
    static func resolve() -> PreludeModelAvailability {
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return .lowPower }
        if ProcessInfo.processInfo.thermalState == .critical { return .thermalThrottle }

        #if targetEnvironment(simulator)
        // Simulator: UI and scripted session flow; on-device model runs on physical hardware only.
        return .available
        #else
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return mapSystemLanguageModelAvailability(SystemLanguageModel.default.availability)
        }
        #endif
        return .unknown
        #endif
    }

    /// `true` when we should run **LanguageModelSession** (device, iOS 26+, model ready). Scripted fallback otherwise.
    static var shouldAttemptFoundationModels: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return false }
        if ProcessInfo.processInfo.thermalState == .critical { return false }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func mapSystemLanguageModelAvailability(_ status: SystemLanguageModel.Availability) -> PreludeModelAvailability {
        switch status {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .notSupported
        case .unavailable(.appleIntelligenceNotEnabled):
            return .disabled
        case .unavailable(.modelNotReady):
            return .downloading
        case .unavailable:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    @available(iOS 26.0, *)
    private static func systemLanguageModelDiagnostics() -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "SystemLanguageModel.default.availability == .available"
        case .unavailable(.deviceNotEligible):
            return "SystemLanguageModel: unavailable · device not eligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "SystemLanguageModel: unavailable · Apple Intelligence off"
        case .unavailable(.modelNotReady):
            return "SystemLanguageModel: unavailable · model not ready (downloading / system)"
        case .unavailable:
            return "SystemLanguageModel: unavailable · other reason"
        @unknown default:
            return "SystemLanguageModel: unknown availability state"
        }
    }
    #endif

    /// Short label for Settings: whether turns use **LanguageModelSession** or the scripted path.
    static var isLiveFoundationModelActive: Bool { shouldAttemptFoundationModels }

    /// Extra line under the indicator (Simulator vs device + warm copy / diagnostics).
    static func settingsSessionDriverFootnote() -> String {
        if shouldAttemptFoundationModels {
            return "Reflection turns use the on-device Apple Intelligence model."
        }
        #if targetEnvironment(simulator)
        return "Simulator cannot run the on-device model — Prelude uses a scripted conversation."
        #else
        return resolve().message
        #endif
    }

    /// Compact technical line for Settings (helps debug “scripted only” on device).
    static func settingsDiagnosticsLine() -> String {
        #if targetEnvironment(simulator)
        return "Runtime: iOS Simulator (FoundationModels session disabled)."
        #else
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return systemLanguageModelDiagnostics()
        }
        return "iOS version does not expose SystemLanguageModel (need iOS 26+)."
        #else
        return "This build has no FoundationModels module."
        #endif
        #endif
    }
}
