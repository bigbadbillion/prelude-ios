import Foundation

/// PRD §9 — lightweight keyword guard; replace with model-assisted detection when agent is live.
enum CrisisDetection {
    private static let phrases = [
        "kill myself", "end it all", "want to die", "suicide", "hurt myself",
        "can't go on", "no point living",
    ]

    static func indicatesCrisis(_ text: String) -> Bool {
        let t = text.lowercased()
        return phrases.contains { t.contains($0) }
    }

    static let spokenAcknowledgment = """
    I hear that things feel really heavy right now. I'm not the right support for what you're describing — but support is available. Please reach out to the 988 Suicide and Crisis Lifeline by calling or texting 988. They're there for exactly this.
    """

    static let disclaimer = """
    Prelude is a personal reflection and preparation tool. It is not therapy, and it is not a substitute for professional mental health care. If you are in crisis, please contact the 988 Suicide & Crisis Lifeline (call or text 988).
    """
}
