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
    case invalidModelName
    case responseTooLarge(maxBytes: Int)

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
        case .invalidModelName:
            return "The selected model name contains unsupported characters."
        case .responseTooLarge(let maxBytes):
            return "The provider returned too much data. Limit: \(maxBytes) bytes."
        }
    }
}

/// Handles provider readiness checks, model discovery, and compact planning requests.
struct AgentService {
    private static let maxResponseBytes = 1_048_576

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
            guard normalizedLocalRootURL(endpoint) != nil else {
                return AIProviderStatus(
                    configuration: configuration,
                    isReady: false,
                    detail: "The server URL for \(provider.displayName) must be an http(s) loopback address such as http://127.0.0.1:11434."
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

        guard isValidModelName(configuration.trimmedModelName) else {
            return AIProviderStatus(
                configuration: configuration,
                isReady: false,
                detail: "The model name contains unsupported characters. Use letters, numbers, '.', '-', '_', ':', or '/'."
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

    func routingStatus(for draft: AIProviderSettingsDraft) -> AIRoutingStatus {
        let normalizedDraft = draft.normalized()
        let activeConfigurations = normalizedDraft.activeConfigurations

        guard !activeConfigurations.isEmpty else {
            return AIRoutingStatus(
                mode: normalizedDraft.routingMode,
                selectedProvider: normalizedDraft.selectedProvider,
                providerStatuses: [],
                detail: "Enable at least one provider before planning."
            )
        }

        let providerStatuses = activeConfigurations.map(status(for:))
        let blockingStatuses = providerStatuses.filter { !$0.isReady }

        if blockingStatuses.isEmpty {
            let detail: String
            switch normalizedDraft.routingMode {
            case .single:
                detail = providerStatuses[0].detail
            case .ensemble:
                let contributorSummary = providerStatuses.map(\.badge).joined(separator: " | ")
                detail = "Ensemble ready. Lead provider: \(normalizedDraft.selectedProvider.displayName). Contributors: \(contributorSummary)"
            }

            return AIRoutingStatus(
                mode: normalizedDraft.routingMode,
                selectedProvider: normalizedDraft.selectedProvider,
                providerStatuses: providerStatuses,
                detail: detail
            )
        }

        let blockingDetail = blockingStatuses
            .map { "\($0.providerLabel): \($0.detail)" }
            .joined(separator: " ")

        return AIRoutingStatus(
            mode: normalizedDraft.routingMode,
            selectedProvider: normalizedDraft.selectedProvider,
            providerStatuses: providerStatuses,
            detail: blockingDetail
        )
    }

    func planInitialApp(
        prompt: String,
        platform: AppPlatform,
        capability: CapabilitySnapshot,
        settings: AIProviderSettingsDraft
    ) async throws -> AgentPlanningResult {
        let routingStatus = routingStatus(for: settings)
        guard routingStatus.isReady else {
            throw AgentServiceError.providerNotReady(routingStatus.detail)
        }

        let blueprints = try await requestBlueprints(
            configurations: routingStatus.providerStatuses.map(\.configuration),
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

        let blueprint = mergeBlueprints(
            blueprints,
            leadProvider: routingStatus.selectedProvider
        )

        return AgentPlanningResult(blueprint: blueprint, routingStatus: routingStatus)
    }

    func planRefinement(
        prompt: String,
        project: GeneratedProject,
        settings: AIProviderSettingsDraft
    ) async throws -> AgentPlanningResult {
        let routingStatus = routingStatus(for: settings)
        guard routingStatus.isReady else {
            throw AgentServiceError.providerNotReady(routingStatus.detail)
        }

        let blueprints = try await requestBlueprints(
            configurations: routingStatus.providerStatuses.map(\.configuration),
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

        let blueprint = mergeBlueprints(
            blueprints,
            leadProvider: routingStatus.selectedProvider,
            fixedAppName: project.name
        )

        return AgentPlanningResult(blueprint: blueprint, routingStatus: routingStatus)
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
                  let url = makeURL(root: endpoint, path: "/api/tags", requireLoopback: true) else {
                throw AgentServiceError.providerNotReady("Enter a valid Ollama server URL before fetching models.")
            }

            let result = try await performJSONRequest(url: url, method: "GET", headers: [:], body: nil)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: result)
            return response.models
                .map(\.name)
                .sorted()
        case .lmStudio:
            guard let endpoint = configuration.trimmedEndpointURLString,
                  let url = makeURL(root: endpoint, path: "/v1/models", requireLoopback: true) else {
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
            guard isValidModelName(configuration.trimmedModelName) else {
                throw AgentServiceError.invalidModelName
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
            guard isValidModelName(configuration.trimmedModelName) else {
                throw AgentServiceError.invalidModelName
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
            guard normalizedLocalRootURL(endpoint) != nil else {
                throw AgentServiceError.providerNotReady("Local model servers must use an http(s) loopback address.")
            }
            guard isValidModelName(configuration.trimmedModelName) else {
                throw AgentServiceError.invalidModelName
            }

            return try await requestOpenAICompatibleBlueprint(
                rootURLString: endpoint,
                apiKey: configuration.kind == .ollama ? "ollama" : nil,
                modelName: configuration.trimmedModelName,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                requireLoopback: true
            )
        }
    }

    private func requestBlueprints(
        configurations: [AIProviderConfiguration],
        systemPrompt: String,
        userPrompt: String
    ) async throws -> [(AIProviderConfiguration, AgentBlueprint)] {
        try await withThrowingTaskGroup(of: (Int, AIProviderConfiguration, AgentBlueprint).self) { group in
            for (index, configuration) in configurations.enumerated() {
                group.addTask {
                    let blueprint = try await requestBlueprint(
                        configuration: configuration,
                        systemPrompt: systemPrompt,
                        userPrompt: userPrompt
                    )
                    return (index, configuration, blueprint)
                }
            }

            var collected: [(Int, AIProviderConfiguration, AgentBlueprint)] = []
            for try await result in group {
                collected.append(result)
            }

            return collected
                .sorted { $0.0 < $1.0 }
                .map { ($0.1, $0.2) }
        }
    }

    /// Merges several provider blueprints into one deterministic scaffold plan.
    /// The lead provider remains authoritative for tie-breaking, while features are unioned
    /// across all contributors so local and cloud models can each add useful shape to the plan.
    private func mergeBlueprints(
        _ blueprints: [(AIProviderConfiguration, AgentBlueprint)],
        leadProvider: AIProviderKind,
        fixedAppName: String? = nil
    ) -> AgentBlueprint {
        guard let leadBlueprint = blueprints.first(where: { $0.0.kind == leadProvider })?.1 ?? blueprints.first?.1 else {
            return AgentBlueprint(appName: fixedAppName ?? "GeneratedApp", summary: "Generated application scaffold.", features: ["Starter project shell"])
        }

        let appName = fixedAppName ?? mostCommonAppName(in: blueprints.map(\.1)) ?? leadBlueprint.appName
        let summary = mergeSummaries(from: blueprints.map(\.1), leadBlueprint: leadBlueprint)
        let features = mergeFeatures(from: blueprints.map(\.1), leadBlueprint: leadBlueprint)

        return AgentBlueprint(
            appName: appName,
            summary: summary,
            features: features
        )
    }

    private func mostCommonAppName(in blueprints: [AgentBlueprint]) -> String? {
        let counts = Dictionary(grouping: blueprints.map(\.appName), by: { $0 })
            .mapValues(\.count)

        return counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .first?
            .key
    }

    private func mergeSummaries(from blueprints: [AgentBlueprint], leadBlueprint: AgentBlueprint) -> String {
        let distinctSummaries = Array(NSOrderedSet(array: blueprints.map(\.summary))) as? [String] ?? []
        guard distinctSummaries.count > 1 else {
            return leadBlueprint.summary
        }

        let secondaryHighlights = blueprints
            .dropFirst()
            .flatMap(\.features)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstHighlight = secondaryHighlights.first else {
            return leadBlueprint.summary
        }

        let appendedSummary = "\(leadBlueprint.summary) Expanded with \(firstHighlight.lowercased())."
        return String(appendedSummary.prefix(280))
    }

    private func mergeFeatures(from blueprints: [AgentBlueprint], leadBlueprint: AgentBlueprint) -> [String] {
        var seen = Set<String>()
        var mergedFeatures: [String] = []

        for feature in leadBlueprint.features + blueprints.flatMap(\.features) {
            let trimmed = feature.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            let dedupeKey = trimmed.lowercased()
            guard seen.insert(dedupeKey).inserted else {
                continue
            }

            mergedFeatures.append(String(trimmed.prefix(120)))
            if mergedFeatures.count == 5 {
                break
            }
        }

        return mergedFeatures
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
        userPrompt: String,
        requireLoopback: Bool = false
    ) async throws -> AgentBlueprint {
        guard let url = makeURL(root: rootURLString, path: "/v1/chat/completions", requireLoopback: requireLoopback) else {
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
            .map { String($0.prefix(120)) }

        let appName = Self.sanitizeProjectName(decoded.appName)
        let summary = String(decoded.summary.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280))

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
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await Self.urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentServiceError.invalidResponse
        }

        guard data.count <= Self.maxResponseBytes else {
            throw AgentServiceError.responseTooLarge(maxBytes: Self.maxResponseBytes)
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

    private func makeURL(root: String, path: String, requireLoopback: Bool) -> URL? {
        let rootURL = requireLoopback ? normalizedLocalRootURL(root) : normalizedRootURL(root)
        guard let rootURL else {
            return nil
        }

        var components = URLComponents(url: rootURL, resolvingAgainstBaseURL: false)
        components?.path = path
        return components?.url
    }

    private func normalizedRootURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        guard var components = URLComponents(string: trimmed) else {
            return nil
        }

        guard let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.user == nil,
              components.password == nil,
              components.host != nil else {
            return nil
        }

        if !(components.path.isEmpty || components.path == "/" || components.path == "/v1") {
            return nil
        }

        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private func normalizedLocalRootURL(_ value: String) -> URL? {
        guard let rootURL = normalizedRootURL(value),
              let host = rootURL.host?.lowercased() else {
            return nil
        }

        let allowedHosts: Set<String> = [
            "localhost",
            "127.0.0.1",
            "::1"
        ]

        guard allowedHosts.contains(host) else {
            return nil
        }

        return rootURL
    }

    private func isValidModelName(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 128 else {
            return false
        }

        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._:/")
        return trimmed.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
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

        let bounded = String(filtered.prefix(40))

        if let first = bounded.first, first.isNumber {
            return "App\(bounded)"
        }

        return bounded
    }

    private static let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()
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
