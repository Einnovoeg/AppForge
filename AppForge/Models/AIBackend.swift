import Foundation

/// Supported planning backends for AppForge.
enum AIProviderKind: String, CaseIterable, Identifiable, Codable {
    case openAI
    case anthropic
    case ollama
    case lmStudio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .ollama:
            return "Ollama"
        case .lmStudio:
            return "LM Studio"
        }
    }

    var networkLabel: String {
        switch self {
        case .openAI, .anthropic:
            return "Internet"
        case .ollama, .lmStudio:
            return "Localhost"
        }
    }

    var authLabel: String {
        switch self {
        case .openAI, .anthropic:
            return "API key"
        case .ollama, .lmStudio:
            return "Local server"
        }
    }

    var defaultModelName: String {
        switch self {
        case .openAI:
            return "gpt-5.3-codex"
        case .anthropic:
            return "claude-sonnet-4-20250514"
        case .ollama, .lmStudio:
            return ""
        }
    }

    var suggestedModels: [String] {
        switch self {
        case .openAI:
            return [
                "gpt-5.3-codex",
                "gpt-5.2-codex",
                "gpt-5.1",
                "gpt-5"
            ]
        case .anthropic:
            return [
                "claude-opus-4-1-20250805",
                "claude-opus-4-20250514",
                "claude-sonnet-4-20250514"
            ]
        case .ollama, .lmStudio:
            return []
        }
    }

    var defaultEndpointURLString: String? {
        switch self {
        case .openAI, .anthropic:
            return nil
        case .ollama:
            return "http://localhost:11434"
        case .lmStudio:
            return "http://127.0.0.1:1234"
        }
    }

    var supportsEndpointConfiguration: Bool {
        switch self {
        case .openAI, .anthropic:
            return false
        case .ollama, .lmStudio:
            return true
        }
    }

    var supportsModelDiscovery: Bool {
        switch self {
        case .openAI, .ollama, .lmStudio:
            return true
        case .anthropic:
            return false
        }
    }

    var keychainAccountName: String? {
        switch self {
        case .openAI:
            return "openai-api-key"
        case .anthropic:
            return "anthropic-api-key"
        case .ollama, .lmStudio:
            return nil
        }
    }

    var setupSummary: String {
        switch self {
        case .openAI:
            return "Use the OpenAI API with an API key. Account-based Codex sign-in is not wired into AppForge yet."
        case .anthropic:
            return "Use the Anthropic API with an API key. Claude.ai account sign-in is not wired into AppForge yet."
        case .ollama:
            return "Connect to a local Ollama server and choose one of its installed models."
        case .lmStudio:
            return "Connect to LM Studio’s local server and choose a loaded model."
        }
    }
}

/// Controls whether AppForge routes a prompt through one provider or an ensemble of providers.
enum AIRoutingMode: String, CaseIterable, Identifiable, Codable {
    case single
    case ensemble

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single:
            return "Single"
        case .ensemble:
            return "Ensemble"
        }
    }

    var setupSummary: String {
        switch self {
        case .single:
            return "Use one configured provider for planning."
        case .ensemble:
            return "Run multiple configured providers in parallel and merge their blueprints into one plan."
        }
    }
}

/// Normalized provider configuration used by the planning service.
struct AIProviderConfiguration: Equatable {
    let kind: AIProviderKind
    let modelName: String
    let endpointURLString: String?

    var trimmedModelName: String {
        modelName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedEndpointURLString: String? {
        endpointURLString?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var badge: String {
        "\(kind.displayName) · \(trimmedModelName.isEmpty ? "No model selected" : trimmedModelName)"
    }
}

/// Readiness snapshot rendered throughout the UI.
struct AIProviderStatus {
    let configuration: AIProviderConfiguration
    let isReady: Bool
    let detail: String

    var providerLabel: String { configuration.kind.displayName }
    var modelLabel: String {
        configuration.trimmedModelName.isEmpty ? "No model selected" : configuration.trimmedModelName
    }
    var authLabel: String { configuration.kind.authLabel }
    var networkLabel: String { configuration.kind.networkLabel }
    var endpointLabel: String {
        if configuration.kind.supportsEndpointConfiguration {
            return configuration.trimmedEndpointURLString ?? "Not set"
        }
        return "Managed by AppForge"
    }
    var badge: String { "\(providerLabel) · \(modelLabel)" }
}

/// Aggregated routing readiness rendered throughout the UI.
struct AIRoutingStatus {
    let mode: AIRoutingMode
    let selectedProvider: AIProviderKind
    let providerStatuses: [AIProviderStatus]
    let detail: String

    var isReady: Bool {
        !providerStatuses.isEmpty && providerStatuses.allSatisfy(\.isReady)
    }

    var modeLabel: String { mode.displayName }

    var providerLabel: String {
        switch mode {
        case .single:
            return providerStatuses.first?.providerLabel ?? selectedProvider.displayName
        case .ensemble:
            return providerStatuses.isEmpty ? "No providers" : "\(providerStatuses.count) providers"
        }
    }

    var leadProviderLabel: String {
        selectedProvider.displayName
    }

    var contributorSummary: String {
        let names = providerStatuses.map(\.providerLabel)
        return names.isEmpty ? "No providers enabled" : names.joined(separator: ", ")
    }

    var modelLabel: String {
        switch mode {
        case .single:
            return providerStatuses.first?.modelLabel ?? "No model selected"
        case .ensemble:
            return providerStatuses.isEmpty ? "No models selected" : "\(providerStatuses.count) active models"
        }
    }

    var modelSummary: String {
        let models = providerStatuses.map(\.badge)
        return models.isEmpty ? "No models configured" : models.joined(separator: " | ")
    }

    var networkLabel: String {
        let labels = Array(Set(providerStatuses.map(\.networkLabel))).sorted()
        switch labels.count {
        case 0:
            return "Unconfigured"
        case 1:
            return labels[0]
        default:
            return "Hybrid"
        }
    }

    var authLabel: String {
        let labels = Array(Set(providerStatuses.map(\.authLabel))).sorted()
        switch labels.count {
        case 0:
            return "Unconfigured"
        case 1:
            return labels[0]
        default:
            return "Mixed"
        }
    }

    var badge: String {
        switch mode {
        case .single:
            return providerStatuses.first?.badge ?? selectedProvider.displayName
        case .ensemble:
            return "Ensemble · \(providerStatuses.count) active"
        }
    }
}

/// User-editable routing and provider settings persisted in UserDefaults.
struct AIProviderSettingsDraft: Equatable {
    var routingMode: AIRoutingMode = .single
    var selectedProvider: AIProviderKind = .openAI
    var openAIEnabled = true
    var anthropicEnabled = false
    var ollamaEnabled = false
    var lmStudioEnabled = false
    var openAIModelName: String = AIProviderKind.openAI.defaultModelName
    var anthropicModelName: String = AIProviderKind.anthropic.defaultModelName
    var ollamaEndpointURLString: String = AIProviderKind.ollama.defaultEndpointURLString ?? ""
    var ollamaModelName: String = AIProviderKind.ollama.defaultModelName
    var lmStudioEndpointURLString: String = AIProviderKind.lmStudio.defaultEndpointURLString ?? ""
    var lmStudioModelName: String = AIProviderKind.lmStudio.defaultModelName

    func configuration(for provider: AIProviderKind) -> AIProviderConfiguration {
        switch provider {
        case .openAI:
            return AIProviderConfiguration(
                kind: .openAI,
                modelName: openAIModelName,
                endpointURLString: nil
            )
        case .anthropic:
            return AIProviderConfiguration(
                kind: .anthropic,
                modelName: anthropicModelName,
                endpointURLString: nil
            )
        case .ollama:
            return AIProviderConfiguration(
                kind: .ollama,
                modelName: ollamaModelName,
                endpointURLString: ollamaEndpointURLString
            )
        case .lmStudio:
            return AIProviderConfiguration(
                kind: .lmStudio,
                modelName: lmStudioModelName,
                endpointURLString: lmStudioEndpointURLString
            )
        }
    }

    func isEnabled(_ provider: AIProviderKind) -> Bool {
        switch provider {
        case .openAI:
            return openAIEnabled
        case .anthropic:
            return anthropicEnabled
        case .ollama:
            return ollamaEnabled
        case .lmStudio:
            return lmStudioEnabled
        }
    }

    mutating func setEnabled(_ value: Bool, for provider: AIProviderKind) {
        switch provider {
        case .openAI:
            openAIEnabled = value
        case .anthropic:
            anthropicEnabled = value
        case .ollama:
            ollamaEnabled = value
        case .lmStudio:
            lmStudioEnabled = value
        }
    }

    var enabledProviders: [AIProviderKind] {
        AIProviderKind.allCases.filter(isEnabled)
    }

    var orderedActiveProviders: [AIProviderKind] {
        let normalizedDraft = normalized()
        switch normalizedDraft.routingMode {
        case .single:
            return [normalizedDraft.selectedProvider]
        case .ensemble:
            return [normalizedDraft.selectedProvider] + AIProviderKind.allCases.filter {
                $0 != normalizedDraft.selectedProvider && normalizedDraft.isEnabled($0)
            }
        }
    }

    var activeConfigurations: [AIProviderConfiguration] {
        orderedActiveProviders.map(configuration(for:))
    }

    var selectedConfiguration: AIProviderConfiguration {
        configuration(for: selectedProvider)
    }

    /// Normalizes edge cases so the UI and planner always have a stable routing definition.
    func normalized() -> AIProviderSettingsDraft {
        var draft = self

        switch draft.routingMode {
        case .single:
            draft.setEnabled(true, for: draft.selectedProvider)
        case .ensemble:
            let enabledProviders = draft.enabledProviders
            if enabledProviders.isEmpty {
                draft.setEnabled(true, for: draft.selectedProvider)
            } else if !draft.isEnabled(draft.selectedProvider), let firstEnabled = enabledProviders.first {
                draft.selectedProvider = firstEnabled
            }
        }

        return draft
    }
}

/// Result of a planning call plus the routing state used to produce it.
struct AgentPlanningResult {
    let blueprint: AgentBlueprint
    let routingStatus: AIRoutingStatus
}
