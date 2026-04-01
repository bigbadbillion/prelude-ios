import AVFoundation
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @AppStorage(UserSettings.colorSchemeStorageKey) private var colorSchemeRaw = PreludeColorSchemePreference.system.rawValue
    @State private var name: String = UserSettings.userName
    @State private var voiceLabel: String = "Checking…"
    @State private var showClearAllConfirm = false
    @State private var clearAllFailed = false

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }

    private var liveModelActive: Bool { PreludeModelAvailability.isLiveFoundationModelActive }

    private var colorSchemePreference: Binding<PreludeColorSchemePreference> {
        Binding(
            get: { PreludeColorSchemePreference(rawValue: colorSchemeRaw) ?? .system },
            set: { colorSchemeRaw = $0.rawValue }
        )
    }

    var body: some View {
        @Bindable var app = appState

        ZStack {
            palette.depth.ignoresSafeArea()
            Form {
                Section {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: liveModelActive ? "sparkles" : "text.bubble")
                            .font(.title2)
                            .foregroundStyle(liveModelActive ? palette.sage : palette.secondary)
                            .frame(width: 28, alignment: .center)
                            .accessibilityHidden(true)
                        Text(liveModelActive ? "On-device model active" : "Scripted session mode")
                            .font(PreludeTypeScale.label())
                            .foregroundStyle(palette.primary)
                    }
                } header: {
                    Text("Apple Intelligence")
                        .font(PreludeTypeScale.caption())
                }

                Section {
                    Picker("Appearance", selection: colorSchemePreference) {
                        ForEach(PreludeColorSchemePreference.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                        .font(PreludeTypeScale.caption())
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
                    Link("Contact support", destination: URL(string: "mailto:ugo@echovault.me")!)
                        .font(PreludeTypeScale.label())
                } header: {
                    Text("Medical disclaimer")
                }

                Section {
                    Button(role: .destructive) {
                        showClearAllConfirm = true
                    } label: {
                        Text("Clear all Prelude data")
                    }
                    .font(PreludeTypeScale.label())
                } header: {
                    Text("Danger")
                        .font(PreludeTypeScale.caption())
                } footer: {
                    Text(
                        "Removes every session, brief, weekly summary, and saved settings on this device. You’ll go through the disclaimer again on the next step."
                    )
                    .font(PreludeTypeScale.caption())
                    .foregroundStyle(palette.tertiary)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Clear all Prelude data?",
            isPresented: $showClearAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear everything", role: .destructive) {
                clearAllPreludeData(app: app)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Couldn’t clear data", isPresented: $clearAllFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try again or restart the app.")
        }
        .onAppear {
            refreshVoice()
        }
    }

    private func clearAllPreludeData(app: AppState) {
        do {
            try MemoryStore.clearAllLocalData(modelContext: modelContext)
            app.sessionBriefToPresent = nil
            app.showSession = false
            app.localDataResetCount += 1
            name = ""
            PreludeHaptics.destructiveActionCommitted()
        } catch {
            clearAllFailed = true
            PreludeHaptics.errorTap()
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
