import Foundation
import SwiftData

/// Tools are the only writers to persistence (PRD §6).
struct ToolExecutionContext {
    let modelContext: ModelContext
    var session: Session?
}

protocol PreludeAgentTool {
    var name: String { get }
    func execute(_ ctx: ToolExecutionContext) async throws
}

/// Holds SwiftData handles for **FoundationModels** `Tool` adapters (`Sendable`; used only on the main actor inside `call`).
final class PreludeToolContextBox: @unchecked Sendable {
    let modelContext: ModelContext
    var session: Session?

    init(modelContext: ModelContext, session: Session?) {
        self.modelContext = modelContext
        self.session = session
    }
}
