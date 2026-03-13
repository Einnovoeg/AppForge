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

/// User-editable provider settings persisted in UserDefaults.
struct AIProviderSettingsDraft: Equatable {
    var selectedProvider: AIProviderKind = .openAI
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

    var selectedConfiguration: AIProviderConfiguration {
        configuration(for: selectedProvider)
    }
}

/// Result of a planning call plus the provider state used to produce it.
struct AgentPlanningResult {
    let blueprint: AgentBlueprint
    let providerStatus: AIProviderStatus
}
