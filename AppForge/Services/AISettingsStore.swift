import Foundation

/// Persists model routing choices without storing API secrets in plain text.
struct AISettingsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let routingMode = "AppForge.aiRoutingMode"
        static let selectedProvider = "AppForge.selectedAIProvider"
        static let openAIEnabled = "AppForge.openAIEnabled"
        static let anthropicEnabled = "AppForge.anthropicEnabled"
        static let ollamaEnabled = "AppForge.ollamaEnabled"
        static let lmStudioEnabled = "AppForge.lmStudioEnabled"
        static let openAIModelName = "AppForge.openAIModelName"
        static let anthropicModelName = "AppForge.anthropicModelName"
        static let ollamaEndpointURLString = "AppForge.ollamaEndpointURLString"
        static let ollamaModelName = "AppForge.ollamaModelName"
        static let lmStudioEndpointURLString = "AppForge.lmStudioEndpointURLString"
        static let lmStudioModelName = "AppForge.lmStudioModelName"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadDraft() -> AIProviderSettingsDraft {
        var draft = AIProviderSettingsDraft()

        if let rawValue = defaults.string(forKey: Key.routingMode),
           let routingMode = AIRoutingMode(rawValue: rawValue) {
            draft.routingMode = routingMode
        }

        if let rawValue = defaults.string(forKey: Key.selectedProvider),
           let provider = AIProviderKind(rawValue: rawValue) {
            draft.selectedProvider = provider
        }

        if defaults.object(forKey: Key.openAIEnabled) != nil {
            draft.openAIEnabled = defaults.bool(forKey: Key.openAIEnabled)
        }
        if defaults.object(forKey: Key.anthropicEnabled) != nil {
            draft.anthropicEnabled = defaults.bool(forKey: Key.anthropicEnabled)
        }
        if defaults.object(forKey: Key.ollamaEnabled) != nil {
            draft.ollamaEnabled = defaults.bool(forKey: Key.ollamaEnabled)
        }
        if defaults.object(forKey: Key.lmStudioEnabled) != nil {
            draft.lmStudioEnabled = defaults.bool(forKey: Key.lmStudioEnabled)
        }

        draft.openAIModelName = defaults.string(forKey: Key.openAIModelName) ?? draft.openAIModelName
        draft.anthropicModelName = defaults.string(forKey: Key.anthropicModelName) ?? draft.anthropicModelName
        draft.ollamaEndpointURLString = defaults.string(forKey: Key.ollamaEndpointURLString) ?? draft.ollamaEndpointURLString
        draft.ollamaModelName = defaults.string(forKey: Key.ollamaModelName) ?? draft.ollamaModelName
        draft.lmStudioEndpointURLString = defaults.string(forKey: Key.lmStudioEndpointURLString) ?? draft.lmStudioEndpointURLString
        draft.lmStudioModelName = defaults.string(forKey: Key.lmStudioModelName) ?? draft.lmStudioModelName

        return draft.normalized()
    }

    func saveDraft(_ draft: AIProviderSettingsDraft) {
        let normalizedDraft = draft.normalized()

        defaults.set(normalizedDraft.routingMode.rawValue, forKey: Key.routingMode)
        defaults.set(normalizedDraft.selectedProvider.rawValue, forKey: Key.selectedProvider)
        defaults.set(normalizedDraft.openAIEnabled, forKey: Key.openAIEnabled)
        defaults.set(normalizedDraft.anthropicEnabled, forKey: Key.anthropicEnabled)
        defaults.set(normalizedDraft.ollamaEnabled, forKey: Key.ollamaEnabled)
        defaults.set(normalizedDraft.lmStudioEnabled, forKey: Key.lmStudioEnabled)
        defaults.set(normalizedDraft.openAIModelName, forKey: Key.openAIModelName)
        defaults.set(normalizedDraft.anthropicModelName, forKey: Key.anthropicModelName)
        defaults.set(normalizedDraft.ollamaEndpointURLString, forKey: Key.ollamaEndpointURLString)
        defaults.set(normalizedDraft.ollamaModelName, forKey: Key.ollamaModelName)
        defaults.set(normalizedDraft.lmStudioEndpointURLString, forKey: Key.lmStudioEndpointURLString)
        defaults.set(normalizedDraft.lmStudioModelName, forKey: Key.lmStudioModelName)
    }
}
