import SwiftUI

/// Settings sheet for AI routing, appearance, and local model discovery.
struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: AppViewModel

    @State private var draft = AIProviderSettingsDraft()
    @State private var selectedColorPalette: AppColorPalette = .harbor
    @State private var openAIAPIKey = ""
    @State private var anthropicAPIKey = ""
    @State private var discoveredModels: [String] = []
    @State private var discoveryMessage: String?
    @State private var isDiscoveringModels = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AppPanel(title: "Appearance", subtitle: "Swap the shell palette without editing code.") {
                            VStack(alignment: .leading, spacing: 14) {
                                Picker("Palette", selection: $selectedColorPalette) {
                                    ForEach(AppColorPalette.allCases) { palette in
                                        Text(palette.displayName).tag(palette)
                                    }
                                }
                                .pickerStyle(.segmented)

                                HStack(spacing: 10) {
                                    PaletteSwatchRow(theme: selectedColorPalette.theme)
                                    Text(selectedColorPalette.displayName)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        AppPanel(title: "Provider Routing", subtitle: "Choose whether AppForge plans through a cloud API or a local model server.") {
                            VStack(alignment: .leading, spacing: 14) {
                                Picker("Provider", selection: $draft.selectedProvider) {
                                    ForEach(AIProviderKind.allCases) { provider in
                                        Text(provider.displayName).tag(provider)
                                    }
                                }
                                .pickerStyle(.segmented)

                                HStack(spacing: 10) {
                                    let status = viewModel.providerStatus(for: draft)
                                    InfoPill(title: "Provider", value: status.providerLabel, tint: selectedColorPalette.theme.accent)
                                    InfoPill(title: "Model", value: status.modelLabel, tint: selectedColorPalette.theme.glow)
                                    InfoPill(title: "Network", value: status.networkLabel, tint: selectedColorPalette.theme.accentSoft)
                                }

                                Text(viewModel.providerStatus(for: draft).detail)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        AppPanel(title: draft.selectedProvider.displayName, subtitle: draft.selectedProvider.setupSummary) {
                            providerConfigurationSection
                        }

                        if let discoveryMessage, !discoveryMessage.isEmpty {
                            AppPanel(title: "Discovery", subtitle: "Local model detection feedback.") {
                                Text(discoveryMessage)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        AppPanel(title: "Privacy & Support", subtitle: "How AppForge stores data and where to find the repo support link.") {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("API keys are stored in the macOS Keychain, generated projects are written to ~/AppForge, and this repository keeps third-party license notices in dedicated documentation files.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 10) {
                                    Button("Reveal Workspace") {
                                        viewModel.revealWorkspace()
                                    }
                                    .buttonStyle(AppActionButtonStyle(emphasized: false))

                                    Button("Buy Me a Coffee") {
                                        guard let url = URL(string: "https://buymeacoffee.com/einnovoeg") else { return }
                                        openURL(url)
                                    }
                                    .buttonStyle(AppActionButtonStyle(emphasized: true))
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
                .scrollIndicators(.hidden)

                HStack {
                    Button("Cancel") {
                        viewModel.isShowingSettings = false
                    }
                    .buttonStyle(AppActionButtonStyle(emphasized: false))
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Save") {
                        persistDraft()
                    }
                    .buttonStyle(AppActionButtonStyle(emphasized: true))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .environment(\.appTheme, selectedColorPalette.theme)
        .onAppear {
            draft = viewModel.providerSettings
            selectedColorPalette = viewModel.colorPalette
            openAIAPIKey = ""
            anthropicAPIKey = ""
            discoveredModels = []
            discoveryMessage = nil
        }
        .onChange(of: draft.selectedProvider) { _, _ in
            discoveredModels = []
            discoveryMessage = nil
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI Settings")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("Configure Anthropic, OpenAI, Ollama, or LM Studio. Xcode coding intelligence is still not integrated.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.isShowingSettings = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .padding(12)
            }
            .buttonStyle(.plain)
            .background(selectedColorPalette.theme.accent.opacity(0.18), in: Circle())
        }
    }

    @ViewBuilder
    private var providerConfigurationSection: some View {
        switch draft.selectedProvider {
        case .openAI:
            cloudProviderSection(
                title: "OpenAI API",
                modelName: $draft.openAIModelName,
                apiKeyValue: $openAIAPIKey,
                apiKeyHint: viewModel.apiKeyHint(for: .openAI),
                apiKeyLabel: "OpenAI API Key",
                clearProvider: .openAI
            )
        case .anthropic:
            cloudProviderSection(
                title: "Anthropic API",
                modelName: $draft.anthropicModelName,
                apiKeyValue: $anthropicAPIKey,
                apiKeyHint: viewModel.apiKeyHint(for: .anthropic),
                apiKeyLabel: "Anthropic API Key",
                clearProvider: .anthropic
            )
        case .ollama:
            localProviderSection(
                title: "Ollama",
                endpoint: $draft.ollamaEndpointURLString,
                modelName: $draft.ollamaModelName
            )
        case .lmStudio:
            localProviderSection(
                title: "LM Studio",
                endpoint: $draft.lmStudioEndpointURLString,
                modelName: $draft.lmStudioModelName
            )
        }
    }

    private func cloudProviderSection(
        title: String,
        modelName: Binding<String>,
        apiKeyValue: Binding<String>,
        apiKeyHint: String,
        apiKeyLabel: String,
        clearProvider: AIProviderKind
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))

            if !draft.selectedProvider.suggestedModels.isEmpty {
                Picker("Suggested Model", selection: modelName) {
                    ForEach(draft.selectedProvider.suggestedModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
            }

            TextField("Model", text: modelName)
                .textFieldStyle(.roundedBorder)

            SecureField("\(apiKeyLabel) (leave blank to keep current key)", text: apiKeyValue)
                .textFieldStyle(.roundedBorder)

            Text(apiKeyHint)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Clear Stored Key") {
                    apiKeyValue.wrappedValue = ""
                    viewModel.saveAPIKey("", for: clearProvider)
                }
                .buttonStyle(AppActionButtonStyle(emphasized: false))

                Text("Account sign-in is not wired into AppForge yet; this build uses API keys for cloud providers.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func localProviderSection(
        title: String,
        endpoint: Binding<String>,
        modelName: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))

            TextField("Server URL", text: endpoint)
                .textFieldStyle(.roundedBorder)

            if !discoveredModels.isEmpty {
                Picker("Detected Model", selection: modelName) {
                    ForEach(discoveredModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
            }

            TextField("Model", text: modelName)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button(isDiscoveringModels ? "Detecting…" : "Detect Models") {
                    Task {
                        await detectModels()
                    }
                }
                .buttonStyle(AppActionButtonStyle(emphasized: false))
                .disabled(isDiscoveringModels)

                Text("AppForge queries the local server for installed or loaded models.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @MainActor
    private func detectModels() async {
        isDiscoveringModels = true
        defer { isDiscoveringModels = false }

        do {
            let models = try await viewModel.discoverModels(for: draft.selectedConfiguration)
            discoveredModels = models
            if let first = models.first, draft.selectedConfiguration.trimmedModelName.isEmpty {
                switch draft.selectedProvider {
                case .ollama:
                    draft.ollamaModelName = first
                case .lmStudio:
                    draft.lmStudioModelName = first
                case .openAI, .anthropic:
                    break
                }
            }
            discoveryMessage = models.isEmpty ? "No models were returned by the selected local server." : "Detected \(models.count) model\(models.count == 1 ? "" : "s")."
        } catch {
            discoveryMessage = error.localizedDescription
        }
    }

    private func persistDraft() {
        viewModel.saveColorPalette(selectedColorPalette)
        viewModel.saveProviderSettings(draft)

        if !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.saveAPIKey(openAIAPIKey, for: .openAI)
        }

        if !anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.saveAPIKey(anthropicAPIKey, for: .anthropic)
        }

        viewModel.isShowingSettings = false
    }
}

private struct PaletteSwatchRow: View {
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(theme.accent)
                .frame(width: 18, height: 18)

            Circle()
                .fill(theme.accentSoft)
                .frame(width: 18, height: 18)

            Circle()
                .fill(theme.glow)
                .frame(width: 18, height: 18)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12), in: Capsule())
    }
}
