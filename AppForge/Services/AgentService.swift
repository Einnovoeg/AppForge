import Foundation

/// Minimal structured plan returned by the configured AI backend.
struct AgentBlueprint: Codable {
    var appName: String
    var summary: String
    var features: [String]
}

enum AgentServiceError: LocalizedError {
    case providerNotReady(String)
    case invalidResponse
    case unsupportedProvider
    case httpFailure(statusCode: Int, responseBody: String)

    var errorDescription: String? {
        switch self {
        case .providerNotReady(let detail):
            return detail
        case .invalidResponse:
            return "The selected model returned an invalid planning payload."
        case .unsupportedProvider:
            return "This provider is not supported in the current AppForge build."
        case .httpFailure(let statusCode, let responseBody):
            if responseBody.isEmpty {
                return "The selected provider returned HTTP \(statusCode)."
            }
            return "The selected provider returned HTTP \(statusCode): \(responseBody)"
        }
    }
}

/// Handles provider readiness checks, model discovery, and compact planning requests.
struct AgentService {
    func hasAPIKey(for provider: AIProviderKind) -> Bool {
        guard provider.keychainAccountName != nil else {
            return false
        }
        guard let value = storedAPIKey(for: provider) else {
            return false
        }
        return !value.isEmpty
    }

    func status(for configuration: AIProviderConfiguration) -> AIProviderStatus {
        let provider = configuration.kind

        if provider.supportsEndpointConfiguration {
            let endpoint = configuration.trimmedEndpointURLString ?? ""
            if endpoint.isEmpty {
                return AIProviderStatus(
                    configuration: configuration,
                    isReady: false,
                    detail: "Set the local server URL for \(provider.displayName)."
                )
            }
            guard normalizedRootURLString(endpoint) != nil else {
                return AIProviderStatus(
                    configuration: configuration,
                    isReady: false,
                    detail: "The server URL for \(provider.displayName) is invalid."
                )
            }
        }

        if configuration.trimmedModelName.isEmpty {
            return AIProviderStatus(
                configuration: configuration,
                isReady: false,
                detail: "Choose a model for \(provider.displayName) before planning."
            )
        }

        if provider.keychainAccountName != nil && !hasAPIKey(for: provider) {
            return AIProviderStatus(
                configuration: configuration,
                isReady: false,
                detail: "\(provider.displayName) requires an API key. Save one in Settings before planning."
            )
        }

        return AIProviderStatus(
            configuration: configuration,
            isReady: true,
            detail: provider.setupSummary
        )
    }

    func planInitialApp(
        prompt: String,
        platform: AppPlatform,
        capability: CapabilitySnapshot,
        configuration: AIProviderConfiguration
    ) async throws -> AgentPlanningResult {
        let providerStatus = status(for: configuration)
        guard providerStatus.isReady else {
            throw AgentServiceError.providerNotReady(providerStatus.detail)
        }

        let blueprint = try await requestBlueprint(
            configuration: configuration,
            systemPrompt: """
            You are the planning layer for AppForge. Return only valid JSON.
            Produce a compact blueprint for a native Apple platform app.
            Keep the appName concise, PascalCase, and filesystem safe.
            Limit features to 4 items maximum.
            """,
            userPrompt: """
            User request: \(prompt)
            Target platform: \(platform.displayName)
            Capability tier: \(capability.badge)

            Respond with JSON using this exact schema:
            {
              "appName": "WeatherTracker",
              "summary": "One sentence describing the app's first runnable version.",
              "features": ["Feature 1", "Feature 2", "Feature 3"]
            }
            """
        )

        return AgentPlanningResult(blueprint: blueprint, providerStatus: providerStatus)
    }

    func planRefinement(
        prompt: String,
        project: GeneratedProject,
        configuration: AIProviderConfiguration
    ) async throws -> AgentPlanningResult {
        let providerStatus = status(for: configuration)
        guard providerStatus.isReady else {
            throw AgentServiceError.providerNotReady(providerStatus.detail)
        }

        let blueprint = try await requestBlueprint(
            configuration: configuration,
            systemPrompt: """
            You are refining an existing native macOS SwiftUI app. Return only valid JSON.
            Keep the existing appName unchanged.
            Limit features to 5 items maximum.
            """,
            userPrompt: """
            Existing app name: \(project.name)
            Existing summary: \(project.summary)
            Existing features: \(project.features.joined(separator: ", "))
            Refinement request: \(prompt)

            Respond with JSON using this exact schema:
            {
              "appName": "\(project.name)",
              "summary": "Updated one sentence summary for the refined app.",
              "features": ["Feature 1", "Feature 2", "Feature 3"]
            }
            """
        )

        return AgentPlanningResult(blueprint: blueprint, providerStatus: providerStatus)
    }

    func discoverModels(for configuration: AIProviderConfiguration) async throws -> [String] {
        switch configuration.kind {
        case .openAI:
            guard let apiKey = storedAPIKey(for: .openAI), !apiKey.isEmpty else {
                throw AgentServiceError.providerNotReady("Save an OpenAI API key before fetching models.")
            }

            let result = try await performJSONRequest(
                url: URL(string: "https://api.openai.com/v1/models")!,
                method: "GET",
                headers: [
                    "Authorization": "Bearer \(apiKey)"
                ],
                body: nil
            )

            let response = try JSONDecoder().decode(OpenAIModelsResponse.self, from: result)
            return response.data
                .map(\.id)
                .sorted()
        case .anthropic:
            return configuration.kind.suggestedModels
        case .ollama:
            guard let endpoint = configuration.trimmedEndpointURLString,
                  let url = makeURL(root: endpoint, path: "/api/tags") else {
                throw AgentServiceError.providerNotReady("Enter a valid Ollama server URL before fetching models.")
            }

            let result = try await performJSONRequest(url: url, method: "GET", headers: [:], body: nil)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: result)
            return response.models
                .map(\.name)
                .sorted()
        case .lmStudio:
            guard let endpoint = configuration.trimmedEndpointURLString,
                  let url = makeURL(root: endpoint, path: "/v1/models") else {
                throw AgentServiceError.providerNotReady("Enter a valid LM Studio server URL before fetching models.")
            }

            let result = try await performJSONRequest(url: url, method: "GET", headers: [:], body: nil)
            let response = try JSONDecoder().decode(OpenAIModelsResponse.self, from: result)
            return response.data
                .map(\.id)
                .sorted()
        }
    }

    private func requestBlueprint(
        configuration: AIProviderConfiguration,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> AgentBlueprint {
        switch configuration.kind {
        case .openAI:
            guard let apiKey = storedAPIKey(for: .openAI), !apiKey.isEmpty else {
                throw AgentServiceError.providerNotReady("OpenAI requires an API key.")
            }

            return try await requestOpenAICompatibleBlueprint(
                rootURLString: "https://api.openai.com",
                apiKey: apiKey,
                modelName: configuration.trimmedModelName,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
        case .anthropic:
            guard let apiKey = storedAPIKey(for: .anthropic), !apiKey.isEmpty else {
                throw AgentServiceError.providerNotReady("Anthropic requires an API key.")
            }

            return try await requestAnthropicBlueprint(
                apiKey: apiKey,
                modelName: configuration.trimmedModelName,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
        case .ollama, .lmStudio:
            guard let endpoint = configuration.trimmedEndpointURLString else {
                throw AgentServiceError.providerNotReady("A local server URL is required.")
            }

            return try await requestOpenAICompatibleBlueprint(
                rootURLString: endpoint,
                apiKey: configuration.kind == .ollama ? "ollama" : nil,
                modelName: configuration.trimmedModelName,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
        }
    }

    private func requestAnthropicBlueprint(
        apiKey: String,
        modelName: String,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> AgentBlueprint {
        let requestBody = AnthropicRequest(
            model: modelName,
            maxTokens: 900,
            system: systemPrompt,
            messages: [
                AnthropicRequest.Message(role: "user", content: userPrompt)
            ]
        )

        let data = try JSONEncoder().encode(requestBody)
        let responseData = try await performJSONRequest(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            method: "POST",
            headers: [
                "Content-Type": "application/json",
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01"
            ],
            body: data
        )

        let payload = try JSONDecoder().decode(AnthropicResponse.self, from: responseData)
        let text = payload.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")

        return try decodeBlueprint(from: text)
    }

    private func requestOpenAICompatibleBlueprint(
        rootURLString: String,
        apiKey: String?,
        modelName: String,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> AgentBlueprint {
        guard let url = makeURL(root: rootURLString, path: "/v1/chat/completions") else {
            throw AgentServiceError.providerNotReady("The configured server URL is invalid.")
        }

        let requestBody = OpenAIChatCompletionsRequest(
            model: modelName,
            messages: [
                OpenAIChatCompletionsRequest.Message(role: "system", content: systemPrompt),
                OpenAIChatCompletionsRequest.Message(role: "user", content: userPrompt)
            ],
            temperature: 0.2
        )

        var headers: [String: String] = [
            "Content-Type": "application/json"
        ]
        if let apiKey, !apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(apiKey)"
        }

        let data = try JSONEncoder().encode(requestBody)
        let responseData = try await performJSONRequest(
            url: url,
            method: "POST",
            headers: headers,
            body: data
        )

        let payload = try JSONDecoder().decode(OpenAIChatCompletionsResponse.self, from: responseData)
        guard let text = payload.choices.first?.message.content else {
            throw AgentServiceError.invalidResponse
        }

        return try decodeBlueprint(from: text)
    }

    private func decodeBlueprint(from text: String) throws -> AgentBlueprint {
        let cleaned = Self.extractJSON(from: text)
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw AgentServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(AgentBlueprint.self, from: jsonData)
        let features = decoded.features
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let appName = Self.sanitizeProjectName(decoded.appName)
        let summary = decoded.summary.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !appName.isEmpty, !summary.isEmpty, !features.isEmpty else {
            throw AgentServiceError.invalidResponse
        }

        return AgentBlueprint(
            appName: appName,
            summary: summary,
            features: Array(features.prefix(5))
        )
    }

    private func performJSONRequest(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyPreview = String(decoding: data.prefix(400), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AgentServiceError.httpFailure(statusCode: httpResponse.statusCode, responseBody: bodyPreview)
        }
        return data
    }

    private func storedAPIKey(for provider: AIProviderKind) -> String? {
        guard let accountName = provider.keychainAccountName else {
            return nil
        }

        do {
            return try KeychainStore(account: accountName).load()
        } catch {
            return nil
        }
    }

    private func makeURL(root: String, path: String) -> URL? {
        guard let normalizedRoot = normalizedRootURLString(root) else {
            return nil
        }
        return URL(string: normalizedRoot + path)
    }

    private func normalizedRootURLString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        var normalized = trimmed
        if normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        if normalized.hasSuffix("/v1") {
            normalized.removeLast(3)
        }

        guard URL(string: normalized) != nil else {
            return nil
        }
        return normalized
    }

    private static func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            // Providers often wrap JSON in fenced blocks even when explicitly told not to.
            return trimmed
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private static func sanitizeProjectName(_ value: String) -> String {
        let filtered = value.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()

        if filtered.isEmpty {
            return "GeneratedApp"
        }

        if let first = filtered.first, first.isNumber {
            return "App\(filtered)"
        }

        return filtered
    }
}

private struct AnthropicRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

private struct AnthropicResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    let content: [ContentBlock]
}

private struct OpenAIChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct OpenAIChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String?
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct OpenAIModelsResponse: Decodable {
    struct ModelSummary: Decodable {
        let id: String
    }

    let data: [ModelSummary]
}

private struct OllamaTagsResponse: Decodable {
    struct ModelSummary: Decodable {
        let name: String
    }

    let models: [ModelSummary]
}
