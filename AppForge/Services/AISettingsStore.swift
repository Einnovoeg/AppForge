import Foundation

/// Persists model routing choices without storing API secrets in plain text.
struct AISettingsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let selectedProvider = "AppForge.selectedAIProvider"
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

        if let rawValue = defaults.string(forKey: Key.selectedProvider),
           let provider = AIProviderKind(rawValue: rawValue) {
            draft.selectedProvider = provider
        }

        draft.openAIModelName = defaults.string(forKey: Key.openAIModelName) ?? draft.openAIModelName
        draft.anthropicModelName = defaults.string(forKey: Key.anthropicModelName) ?? draft.anthropicModelName
        draft.ollamaEndpointURLString = defaults.string(forKey: Key.ollamaEndpointURLString) ?? draft.ollamaEndpointURLString
        draft.ollamaModelName = defaults.string(forKey: Key.ollamaModelName) ?? draft.ollamaModelName
        draft.lmStudioEndpointURLString = defaults.string(forKey: Key.lmStudioEndpointURLString) ?? draft.lmStudioEndpointURLString
        draft.lmStudioModelName = defaults.string(forKey: Key.lmStudioModelName) ?? draft.lmStudioModelName

        return draft
    }

    func saveDraft(_ draft: AIProviderSettingsDraft) {
        defaults.set(draft.selectedProvider.rawValue, forKey: Key.selectedProvider)
        defaults.set(draft.openAIModelName, forKey: Key.openAIModelName)
        defaults.set(draft.anthropicModelName, forKey: Key.anthropicModelName)
        defaults.set(draft.ollamaEndpointURLString, forKey: Key.ollamaEndpointURLString)
        defaults.set(draft.ollamaModelName, forKey: Key.ollamaModelName)
        defaults.set(draft.lmStudioEndpointURLString, forKey: Key.lmStudioEndpointURLString)
        defaults.set(draft.lmStudioModelName, forKey: Key.lmStudioModelName)
    }
}
