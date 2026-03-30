import SwiftData
import SwiftUI

struct SessionView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @StateObject private var voice = VoiceEngine()
    @StateObject private var agent = AgentController()

    @State private var activeSession: Session?
    /// Stable id for finalization after the full-screen cover may dismiss (`activeSession` must not be relied on).
    @State private var sessionID: UUID?
    @State private var showHelpSheet = false
    @State private var didFinalize = false
    /// First agent line for this session (model, fallback, or script) — reused after mic “Try again”.
    @State private var sessionOpeningLine: String = VoiceEngineScript.lines[0]
    @State private var transcriptScrollNonce: UInt = 0

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }

    var body: some View {
        @Bindable var app = appState

        ZStack {
            palette.depth.ignoresSafeArea()
            GeometryReader { geo in
                let h = geo.size.height
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: h * 0.06)
                    PresenceShapeView(
                        voiceState: voice.voiceState,
                        size: min(260, geo.size.width * 0.65),
                        amplitude: CGFloat(voice.amplitude)
                    )
                    .frame(height: h * 0.48)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(voice.agentText)
                            .font(PreludeTypeScale.cardBody())
                            .foregroundStyle(palette.primary)
                            .multilineTextAlignment(.leading)
                            .animation(PreludeMotion.reveal, value: voice.agentText)
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(voice.transcriptLines.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(PreludeTypeScale.transcript())
                                            .foregroundStyle(palette.secondary.opacity(0.7))
                                    }
                                    if !voice.liveTranscript.isEmpty {
                                        Text(voice.liveTranscript)
                                            .font(PreludeTypeScale.transcript())
                                            .foregroundStyle(palette.tertiary.opacity(0.7))
                                    }
                                    Color.clear
                                        .frame(height: 1)
                                        .id("transcriptBottom")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: min(140, h * 0.18))
                            .onChange(of: transcriptScrollNonce) { _, _ in
                                Task { @MainActor in
                                    await Task.yield()
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        proxy.scrollTo("transcriptBottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(height: h * 0.28, alignment: .top)

                HStack {
                    Button("Pause") {
                        if voice.voiceState == .paused {
                            voice.resume()
                        } else {
                            voice.pause()
                        }
                    }
                    .font(PreludeTypeScale.label())
                    .foregroundStyle(palette.secondary)
                    Spacer()
                    Button("End") {
                        guard let sid = sessionID else { return }
                        if let s = SessionStore.session(id: sid, in: context) {
                            let live = voice.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !live.isEmpty {
                                s.appendUserTurn(live)
                            }
                            try? context.save()
                        }
                        voice.end()
                        Task { await finalizeSession(sessionId: sid) }
                    }
                    .font(PreludeTypeScale.label())
                    .foregroundStyle(palette.amber)
                    Spacer()
                    Button {
                        showHelpSheet = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(palette.tertiary)
                    }
                    .accessibilityLabel("Crisis and help resources")
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                Spacer(minLength: 0)
                }
            }
        }
        .overlay {
            micErrorOverlay
        }
        .statusBarHidden(true)
        .onAppear {
            agent.resetForNewSession()
            let session = Session()
            context.insert(session)
            activeSession = session
            sessionID = session.id
            agent.attachToolContext(modelContext: context, session: session)

            voice.configure(
                onUserTurnComplete: { rawTranscript, modelUtterance in
                    session.appendUserTurn(rawTranscript)
                    try? context.save()
                    return await agent.respondToUserTurn(
                        userUtteranceForModel: modelUtterance,
                        rawTranscriptLine: rawTranscript,
                        modelContext: context,
                        session: session
                    )
                },
                onSessionEnd: {
                    guard let sid = sessionID else { return }
                    Task { await finalizeSession(sessionId: sid) }
                },
                onLiveTranscript: {
                    transcriptScrollNonce &+= 1
                },
                onCrisis: {
                    appState.showCrisisResources = true
                }
            )
            Task { @MainActor in
                let opening: String
                if PreludeModelAvailability.shouldAttemptFoundationModels {
                    opening = await agent.generateOpeningLine(modelContext: context, session: session)
                        ?? AgentController.liveAgentOpeningFallback
                } else {
                    opening = VoiceEngineScript.lines[0]
                }
                sessionOpeningLine = opening
                await voice.start(openingText: opening)
            }
            PreludeHaptics.sessionBegin()
        }
        .onDisappear {
            voice.end()
        }
        .sheet(isPresented: $showHelpSheet) {
            crisisSheet
        }
        .sheet(isPresented: $app.showCrisisResources) {
            crisisSheet
        }
    }

    private var crisisSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Support")
                        .font(PreludeTypeScale.title())
                    Text(CrisisDetection.disclaimer)
                        .font(PreludeTypeScale.cardBody())
                        .foregroundStyle(.secondary)
                    Link("Call or text 988", destination: URL(string: "tel:988")!)
                        .font(PreludeTypeScale.label())
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showHelpSheet = false
                        appState.showCrisisResources = false
                    }
                }
            }
        }
    }

    @MainActor
    private func finalizeSession(sessionId: UUID) async {
        guard !didFinalize else { return }
        didFinalize = true

        guard let session = SessionStore.session(id: sessionId, in: context) else {
            didFinalize = false
            return
        }

        session.completedAt = .now
        session.durationSeconds = Int(Date().timeIntervalSince(session.startedAt))
        session.phase = .closing
        try? context.save()

        await BriefStore.synthesizeAndAttachSessionBrief(modelContext: context, sessionId: sessionId)
        try? context.save()

        PreludeHaptics.sessionEnd()

        PreludeHaptics.briefReady()
        #if targetEnvironment(simulator)
        try? await Task.sleep(nanoseconds: 120_000_000)
        #else
        try? await Task.sleep(nanoseconds: 900_000_000)
        #endif

        await BriefStore.refreshWeeklyBriefIfNeeded(modelContext: context)
        try? context.save()

        appState.showSession = false
        appState.sessionBriefToPresent = sessionId
        activeSession = nil
    }
}

// MARK: - Permission / unavailability UI helpers

private extension SessionView {
    @ViewBuilder
    var micErrorOverlay: some View {
        if let msg = voice.errorMessage, !msg.isEmpty, voice.voiceState == .idle {
            VStack(spacing: 16) {
                Text("Microphone unavailable")
                    .font(PreludeTypeScale.title())
                    .foregroundStyle(palette.primary)
                Text(msg)
                    .font(PreludeTypeScale.cardBody())
                    .foregroundStyle(palette.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await voice.start(openingText: sessionOpeningLine) }
                } label: {
                    Text("Try again")
                        .font(PreludeTypeScale.cardTitle())
                        .foregroundStyle(palette.amber)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.raised.opacity(0.7))
            )
            .preludeGlassSheet()
            .padding(.horizontal, 24)
        }
    }
}
