import SwiftUI

/// Settings sheet for routing, provider credentials, local model discovery, and appearance.
struct SettingsView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: AppViewModel

    @State private var draft = AIProviderSettingsDraft()
    @State private var selectedColorPalette: AppColorPalette = .harbor
    @State private var openAIAPIKey = ""
    @State private var anthropicAPIKey = ""
    @State private var discoveredModelsByProvider: [AIProviderKind: [String]] = [:]
    @State private var discoveryMessagesByProvider: [AIProviderKind: String] = [:]
    @State private var discoveringProviders: Set<AIProviderKind> = []

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        appearancePanel
                        routingPanel
                        providerConfigurationPanel
                        toolingPanel
                        privacyPanel
                    }
                    .padding(.bottom, 6)
                }
                .scrollIndicators(.hidden)

                footer
            }
            .padding(24)
        }
        .environment(\.appTheme, selectedColorPalette.theme)
        .onAppear(perform: loadDraft)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI Settings")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("Configure local and cloud providers, then choose whether prompts route through one model or an ensemble.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(AppReleaseInfo.current.releaseSummary)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
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
            .help("Close settings without saving changes.")
            .buttonStyle(.plain)
            .background(selectedColorPalette.theme.accent.opacity(0.18), in: Circle())
        }
    }

    private var appearancePanel: some View {
        AppPanel(title: "Appearance", subtitle: "Swap the shell palette without editing code.") {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Palette", selection: $selectedColorPalette) {
                    ForEach(AppColorPalette.allCases) { palette in
                        Text(palette.displayName).tag(palette)
                    }
                }
                .help("Choose the color palette for the AppForge workspace.")
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    PaletteSwatchRow(theme: selectedColorPalette.theme)
                    Text(selectedColorPalette.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var routingPanel: some View {
        let routingStatus = viewModel.routingStatus(for: draft)

        return AppPanel(
            title: "Provider Routing",
            subtitle: "Use one provider or merge several providers into a single scaffold plan."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Routing Mode", selection: $draft.routingMode) {
                    ForEach(AIRoutingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .help("Single uses one provider. Ensemble queries multiple enabled providers in parallel and merges the results.")
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    InfoPill(title: "Mode", value: routingStatus.modeLabel, tint: theme.accent)
                    InfoPill(title: "Providers", value: routingStatus.providerLabel, tint: theme.glow)
                    InfoPill(title: "Network", value: routingStatus.networkLabel, tint: theme.accentSoft)
                    InfoPill(title: "Auth", value: routingStatus.authLabel, tint: theme.accent)
                }

                Text(routingStatus.detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if draft.routingMode == .single {
                    Picker("Provider", selection: $draft.selectedProvider) {
                        ForEach(AIProviderKind.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .help("Choose the single provider AppForge should use for planning.")
                    .pickerStyle(.segmented)
                    .onChange(of: draft.selectedProvider) { _, provider in
                        draft.setEnabled(true, for: provider)
                        draft = draft.normalized()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lead Provider")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))

                        Picker("Lead Provider", selection: $draft.selectedProvider) {
                            ForEach(draft.enabledProviders.isEmpty ? AIProviderKind.allCases : draft.enabledProviders) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .help("The lead provider breaks ties when AppForge merges several provider blueprints.")
                        .pickerStyle(.menu)

                        Text("Active Providers")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(AIProviderKind.allCases) { provider in
                                ProviderToggleTile(
                                    provider: provider,
                                    isEnabled: providerToggleBinding(for: provider),
                                    isLead: draft.selectedProvider == provider
                                )
                            }
                        }
                    }
                }

                providerStatusList(routingStatus.providerStatuses)
            }
        }
    }

    private var providerConfigurationPanel: some View {
        AppPanel(title: "Provider Configuration", subtitle: providerConfigurationSubtitle) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(configurationProviders) { provider in
                    ProviderConfigurationCard(
                        provider: provider,
                        routingMode: draft.routingMode,
                        isEnabledInEnsemble: draft.isEnabled(provider),
                        theme: theme
                    ) {
                        providerConfigurationSection(for: provider)
                    }
                }
            }
        }
    }

    private var toolingPanel: some View {
        AppPanel(title: "Local Tooling", subtitle: "Build prerequisites detected on this Mac.") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    InfoPill(title: "Xcode", value: viewModel.capability.xcodeVersion ?? "Not detected", tint: theme.accent)
                    InfoPill(title: "xcodebuild", value: viewModel.capability.xcodebuildStatusLabel, tint: theme.glow)
                    InfoPill(title: "XcodeGen", value: viewModel.capability.xcodegenStatusLabel, tint: theme.accentSoft)
                }

                Text(viewModel.capability.buildPipelineSummary)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if let xcodebuildPath = viewModel.capability.xcodebuildPath {
                    Text("xcodebuild: \(xcodebuildPath)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if let xcodegenPath = viewModel.capability.xcodegenPath {
                    Text("xcodegen: \(xcodegenPath)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var privacyPanel: some View {
        AppPanel(title: "Privacy & Support", subtitle: "How AppForge stores data and where to find the repo support link.") {
            VStack(alignment: .leading, spacing: 14) {
                Text(AppReleaseInfo.current.releaseSummary)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text("API keys are stored in the macOS Keychain, generated projects are written to ~/AppForge, and this repository keeps third-party license notices in dedicated documentation files.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Reveal Workspace") {
                        viewModel.revealWorkspace()
                    }
                    .help("Open the portable AppForge workspace in Finder.")
                    .buttonStyle(AppActionButtonStyle(emphasized: false))

                    Button("Buy Me a Coffee") {
                        guard let url = URL(string: "https://buymeacoffee.com/einnovoeg") else { return }
                        openURL(url)
                    }
                    .help("Open the project support page in your browser.")
                    .buttonStyle(AppActionButtonStyle(emphasized: true))
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                viewModel.isShowingSettings = false
            }
            .help("Discard changes made in this settings session.")
            .buttonStyle(AppActionButtonStyle(emphasized: false))
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Save") {
                persistDraft()
            }
            .help("Save routing, appearance, and provider settings.")
            .buttonStyle(AppActionButtonStyle(emphasized: true))
            .keyboardShortcut(.defaultAction)
        }
    }

    private var configurationProviders: [AIProviderKind] {
        switch draft.routingMode {
        case .single:
            return [draft.selectedProvider]
        case .ensemble:
            return AIProviderKind.allCases
        }
    }

    private var providerConfigurationSubtitle: String {
        switch draft.routingMode {
        case .single:
            return "Configure the currently selected planning backend."
        case .ensemble:
            return "Configure every provider you may want to include in ensemble planning."
        }
    }

    @ViewBuilder
    private func providerConfigurationSection(for provider: AIProviderKind) -> some View {
        switch provider {
        case .openAI:
            cloudProviderSection(
                provider: provider,
                modelName: $draft.openAIModelName,
                apiKeyValue: $openAIAPIKey,
                apiKeyHint: viewModel.apiKeyHint(for: .openAI),
                apiKeyLabel: "OpenAI API Key"
            )
        case .anthropic:
            cloudProviderSection(
                provider: provider,
                modelName: $draft.anthropicModelName,
                apiKeyValue: $anthropicAPIKey,
                apiKeyHint: viewModel.apiKeyHint(for: .anthropic),
                apiKeyLabel: "Anthropic API Key"
            )
        case .ollama:
            localProviderSection(
                provider: provider,
                endpoint: $draft.ollamaEndpointURLString,
                modelName: $draft.ollamaModelName
            )
        case .lmStudio:
            localProviderSection(
                provider: provider,
                endpoint: $draft.lmStudioEndpointURLString,
                modelName: $draft.lmStudioModelName
            )
        }
    }

    private func cloudProviderSection(
        provider: AIProviderKind,
        modelName: Binding<String>,
        apiKeyValue: Binding<String>,
        apiKeyHint: String,
        apiKeyLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !provider.suggestedModels.isEmpty {
                Picker("Suggested Model", selection: modelName) {
                    ForEach(provider.suggestedModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .help("Choose from the common model IDs for \(provider.displayName).")
                .pickerStyle(.menu)
            }

            TextField("Model", text: modelName)
                .help("Enter the exact model identifier AppForge should request from \(provider.displayName).")
                .textFieldStyle(.roundedBorder)

            SecureField("\(apiKeyLabel) (leave blank to keep current key)", text: apiKeyValue)
                .help("Paste a new \(provider.displayName) API key only if you want to replace the currently stored key.")
                .textFieldStyle(.roundedBorder)

            Text(apiKeyHint)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Clear Stored Key") {
                    apiKeyValue.wrappedValue = ""
                    viewModel.saveAPIKey("", for: provider)
                }
                .help("Remove the saved \(provider.displayName) API key from the macOS Keychain.")
                .buttonStyle(AppActionButtonStyle(emphasized: false))

                Text("Cloud providers currently use API keys stored in Keychain. Browser-account sign-in is not wired into AppForge.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func localProviderSection(
        provider: AIProviderKind,
        endpoint: Binding<String>,
        modelName: Binding<String>
    ) -> some View {
        let discoveredModels = discoveredModelsByProvider[provider] ?? []
        let isDiscoveringModels = discoveringProviders.contains(provider)

        return VStack(alignment: .leading, spacing: 12) {
            TextField("Server URL", text: endpoint)
                .help("Enter the loopback URL for the local \(provider.displayName) server.")
                .textFieldStyle(.roundedBorder)

            if !discoveredModels.isEmpty {
                Picker("Detected Model", selection: modelName) {
                    ForEach(discoveredModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .help("Choose one of the models returned by the local \(provider.displayName) server.")
                .pickerStyle(.menu)
            }

            TextField("Model", text: modelName)
                .help("Enter the exact model identifier that the local \(provider.displayName) server exposes.")
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button(isDiscoveringModels ? "Detecting…" : "Detect Models") {
                    Task {
                        await detectModels(for: provider)
                    }
                }
                .help("Query the local \(provider.displayName) server for available models.")
                .buttonStyle(AppActionButtonStyle(emphasized: false))
                .disabled(isDiscoveringModels)

                Text("AppForge queries the local server for installed or loaded models.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let discoveryMessage = discoveryMessagesByProvider[provider], !discoveryMessage.isEmpty {
                Text(discoveryMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func providerStatusList(_ statuses: [AIProviderStatus]) -> some View {
        if !statuses.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(statuses, id: \.badge) { status in
                    HStack(spacing: 10) {
                        InfoPill(title: status.providerLabel, value: status.modelLabel, tint: status.isReady ? theme.accent : .red)
                        Text(status.detail)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func providerToggleBinding(for provider: AIProviderKind) -> Binding<Bool> {
        Binding(
            get: { draft.isEnabled(provider) },
            set: { newValue in
                draft.setEnabled(newValue, for: provider)
                draft = draft.normalized()
            }
        )
    }

    @MainActor
    private func detectModels(for provider: AIProviderKind) async {
        discoveringProviders.insert(provider)
        defer { discoveringProviders.remove(provider) }

        do {
            let configuration = draft.configuration(for: provider)
            let models = try await viewModel.discoverModels(for: configuration)
            discoveredModelsByProvider[provider] = models

            if let first = models.first, configuration.trimmedModelName.isEmpty {
                switch provider {
                case .ollama:
                    draft.ollamaModelName = first
                case .lmStudio:
                    draft.lmStudioModelName = first
                case .openAI, .anthropic:
                    break
                }
            }

            discoveryMessagesByProvider[provider] = models.isEmpty
                ? "No models were returned by the local server."
                : "Detected \(models.count) model\(models.count == 1 ? "" : "s")."
        } catch {
            discoveryMessagesByProvider[provider] = error.localizedDescription
        }
    }

    private func loadDraft() {
        draft = viewModel.providerSettings.normalized()
        selectedColorPalette = viewModel.colorPalette
        openAIAPIKey = ""
        anthropicAPIKey = ""
        discoveredModelsByProvider = [:]
        discoveryMessagesByProvider = [:]
        discoveringProviders = []
    }

    private func persistDraft() {
        let normalizedDraft = draft.normalized()
        draft = normalizedDraft

        viewModel.saveColorPalette(selectedColorPalette)
        viewModel.saveProviderSettings(normalizedDraft)

        if !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.saveAPIKey(openAIAPIKey, for: .openAI)
        }

        if !anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.saveAPIKey(anthropicAPIKey, for: .anthropic)
        }

        viewModel.isShowingSettings = false
    }
}

private struct ProviderToggleTile: View {
    let provider: AIProviderKind
    @Binding var isEnabled: Bool
    let isLead: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(provider.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                    if isLead {
                        Text("Lead")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.16), in: Capsule())
                    }
                }

                Text(provider.networkLabel)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .help("Toggle \(provider.displayName) on or off for ensemble planning.")
        .toggleStyle(.switch)
        .padding(14)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ProviderConfigurationCard<Content: View>: View {
    let provider: AIProviderKind
    let routingMode: AIRoutingMode
    let isEnabledInEnsemble: Bool
    let theme: AppTheme
    let content: () -> Content

    init(
        provider: AIProviderKind,
        routingMode: AIRoutingMode,
        isEnabledInEnsemble: Bool,
        theme: AppTheme,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.provider = provider
        self.routingMode = routingMode
        self.isEnabledInEnsemble = isEnabledInEnsemble
        self.theme = theme
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(provider.displayName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                Text(statusLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(statusTint.opacity(0.18), in: Capsule())
                    .foregroundStyle(statusTint)
            }

            Text(provider.setupSummary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            content()
        }
        .padding(18)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var statusLabel: String {
        switch routingMode {
        case .single:
            return "Active"
        case .ensemble:
            return isEnabledInEnsemble ? "Enabled" : "Standby"
        }
    }

    private var statusTint: Color {
        switch routingMode {
        case .single:
            return theme.accent
        case .ensemble:
            return isEnabledInEnsemble ? theme.accent : .secondary
        }
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
