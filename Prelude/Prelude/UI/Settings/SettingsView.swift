import AVFoundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(AppState.self) private var appState
    @State private var name: String = UserSettings.userName
    @State private var voiceLabel: String = "Checking…"

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }

    private var liveModelActive: Bool { PreludeModelAvailability.isLiveFoundationModelActive }

    var body: some View {
        @Bindable var app = appState

        ZStack {
            palette.depth.ignoresSafeArea()
            Form {
                Section {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: liveModelActive ? "sparkles" : "text.bubble")
                            .font(.title2)
                            .foregroundStyle(liveModelActive ? palette.sage : palette.secondary)
                            .frame(width: 28, alignment: .center)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(liveModelActive ? "On-device model active" : "Scripted session mode")
                                .font(PreludeTypeScale.label())
                                .foregroundStyle(palette.primary)
                            Text(PreludeModelAvailability.settingsSessionDriverFootnote())
                                .font(PreludeTypeScale.caption())
                                .foregroundStyle(palette.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Divider()
                                .padding(.vertical, 4)
                            Text("Session start: \(app.availability.title)")
                                .font(PreludeTypeScale.caption())
                                .foregroundStyle(palette.tertiary)
                            Text(app.availability.message)
                                .font(PreludeTypeScale.caption())
                                .foregroundStyle(palette.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(PreludeModelAvailability.settingsDiagnosticsLine())
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(palette.tertiary.opacity(0.9))
                                .padding(.top, 4)
                                .textSelection(.enabled)
                        }
                    }
                    Button("Refresh status") {
                        app.refreshAvailability()
                    }
                    .font(PreludeTypeScale.label())
                    .foregroundStyle(palette.amber)
                } header: {
                    Text("Apple Intelligence")
                        .font(PreludeTypeScale.caption())
                } footer: {
                    Text(
                        "If this shows the on-device model as active but replies still feel scripted, the model request may be failing silently — check Xcode’s console while you speak."
                    )
                    .font(PreludeTypeScale.caption())
                    .foregroundStyle(palette.tertiary)
                }

                Section {
                    TextField("Your first name", text: $name)
                        .onChange(of: name) { _, v in
                            UserSettings.userName = v
                        }
                        .font(PreludeTypeScale.cardBody())
                } header: {
                    Text("Profile")
                        .font(PreludeTypeScale.caption())
                }

                Section {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(palette.amber)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Voice quality")
                                .font(PreludeTypeScale.label())
                            Text(voiceLabel)
                                .font(PreludeTypeScale.caption())
                                .foregroundStyle(palette.secondary)
                        }
                    }
                } header: {
                    Text("Voice")
                }

                Section {
                    Text(CrisisDetection.disclaimer)
                        .font(PreludeTypeScale.caption())
                        .foregroundStyle(palette.secondary)
                    Link("Call or text 988", destination: URL(string: "tel:988")!)
                        .font(PreludeTypeScale.label())
                        .accessibilityLabel("988 Suicide and Crisis Lifeline")
                } header: {
                    Text("Medical disclaimer")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            refreshVoice()
            appState.refreshAvailability()
        }
    }

    private func refreshVoice() {
        let ids = [
            "com.apple.voice.premium.en-US.Zoe",
            "com.apple.voice.enhanced.en-US.Zoe",
        ]
        // Avoid `AVSpeechSynthesisVoice.speechVoices()` on simulator; it can trigger heavy decoding/logs.
        // We only check by identifier (cheap) and fall back to Standard.
        if AVSpeechSynthesisVoice(identifier: ids[0]) != nil {
            voiceLabel = "Premium · Neural"
        } else if AVSpeechSynthesisVoice(identifier: ids[1]) != nil {
            voiceLabel = "Enhanced"
        } else {
            voiceLabel = "Standard"
        }
    }
}
