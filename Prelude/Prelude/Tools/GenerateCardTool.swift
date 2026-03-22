import Foundation

struct GenerateCardTool: PreludeAgentTool {
    let name = "generateCard"

    var cardType: CardType = .emotionalState
    var cardText: String = "Present and reflective"

    init(cardType: CardType = .emotionalState, cardText: String = "Present and reflective") {
        self.cardType = cardType
        self.cardText = cardText
    }

    func execute(_ ctx: ToolExecutionContext) async throws {
        guard let session = ctx.session else { return }
        let card = SessionCard(type: cardType, text: cardText, session: session)
        ctx.modelContext.insert(card)
    }
}
