import Foundation
import SwiftUI

@MainActor
/// Coordinates the AppForge shell, generation workflow, and persistent UI state.
final class AppViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var projects: [GeneratedProject] = []
    @Published var selectedProject: GeneratedProject?
    @Published var fileTree: [FileTreeNode] = []
    @Published var selectedFileURL: URL?
    @Published var selectedFileContents = ""
    @Published var capability = CapabilitySnapshot(tier: .bundledSwiftOnly, developerDirectory: nil, swiftVersion: nil, xcodeVersion: nil)
    @Published var buildLog = ""
    @Published var composeText = ""
    @Published var selectedPlatform: AppPlatform = .macOS
    @Published var buildPhase: BuildPhase = .idle
    @Published var isBusy = false
    @Published var isShowingSettings = false
    @Published var errorMessage: String?
    @Published var colorPalette: AppColorPalette = .harbor
    @Published var providerSettings = AIProviderSettingsDraft()
    @Published var aiProviderStatus = AIProviderStatus(
        configuration: AIProviderConfiguration(kind: .openAI, modelName: AIProviderKind.openAI.defaultModelName, endpointURLString: nil),
        isReady: false,
        detail: "Configure a provider before planning."
    )

    private let workspaceManager = WorkspaceManager()
    private let capabilityDetector = CapabilityDetector()
    private let scaffolder = ProjectScaffolder()
    private let agentService = AgentService()
    private let builtInRecipeService = BuiltInRecipeService()
    private let aiSettingsStore = AISettingsStore()
    private let appearanceSettingsStore = AppearanceSettingsStore()
    private var hasBootstrapped = false

    var composerModeTitle: String {
        if let project = selectedProject {
            return "Refining \(project.name)"
        }
        return "New App"
    }

    var composerModeSummary: String {
        if selectedProject != nil {
            return "The next prompt will modify the selected project."
        }
        return "The next prompt will create a new project."
    }

    var scaffoldModeSummary: String {
        "Scaffold-first MVP. Built-in recipes such as Sudoku now generate working app logic, while most other prompts still produce a runnable shell unless a richer generator is added."
    }

    var xcodeCodingStatusSummary: String {
        "Xcode coding intelligence is not integrated in this build."
    }

    var selectedProjectName: String {
        selectedProject?.name ?? "No project selected"
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        do {
            try workspaceManager.bootstrapDirectories()
            colorPalette = appearanceSettingsStore.loadColorPalette()
            capability = await capabilityDetector.detect()
            providerSettings = aiSettingsStore.loadDraft()
            aiProviderStatus = agentService.status(for: providerSettings.selectedConfiguration)
            projects = try workspaceManager.loadProjects()

            if messages.isEmpty {
                appendAssistant("""
                AppForge is ready. Configure a real AI provider or a local model, then describe the macOS app you want to build.

                Current capability: \(capability.badge)
                Planning provider: \(aiProviderStatus.badge) (\(aiProviderStatus.networkLabel.lowercased()))
                \(scaffoldModeSummary)
                \(xcodeCodingStatusSummary)
                """)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendCurrentPrompt() async {
        let prompt = composeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isBusy else { return }

        appendUser(prompt)
        composeText = ""
        isBusy = true

        defer { isBusy = false }

        do {
            if let project = selectedProject {
                try await refine(project: project, prompt: prompt)
            } else {
                try await createProject(from: prompt)
            }
        } catch {
            buildPhase = .failed
            errorMessage = error.localizedDescription
            appendAssistant("The last action failed: \(error.localizedDescription)")
        }
    }

    func createNewProjectSession() {
        selectedProject = nil
        fileTree = []
        selectedFileURL = nil
        selectedFileContents = ""
        buildLog = ""
        buildPhase = .idle
        appendAssistant("Ready for a new build. Describe the app you want next.")
    }

    func load(project: GeneratedProject) {
        selectedProject = project
        fileTree = workspaceManager.loadFileTree(for: project)
        if let preferredFileURL = preferredPreviewURL(in: project) {
            selectFile(preferredFileURL)
        } else {
            selectedFileURL = nil
            selectedFileContents = ""
        }
    }

    func selectFile(_ url: URL) {
        selectedFileURL = url
        selectedFileContents = (try? workspaceManager.fileContents(at: url)) ?? ""
    }

    func rebuildSelectedProject() async {
        guard let project = selectedProject, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await runBuild(for: project, shouldLaunch: false)
    }

    func launchSelectedProject() async {
        guard let project = selectedProject, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let launchResult = try await BuildRunner.launch(project: project)
            buildLog += outputSection(title: "Launch", body: launchResult.output)
            buildPhase = launchResult.success ? .launching : .failed
            appendAssistant(launchResult.success ? "Launched \(project.name)." : "Launch failed. Review the build log.")
        } catch {
            buildPhase = .failed
            errorMessage = error.localizedDescription
        }
    }

    func revealSelectedProject() {
        guard let project = selectedProject else { return }
        workspaceManager.reveal(project.rootURL)
    }

    func revealWorkspace() {
        workspaceManager.reveal(workspaceManager.workspaceURL)
    }

    func providerStatus(for draft: AIProviderSettingsDraft) -> AIProviderStatus {
        agentService.status(for: draft.selectedConfiguration)
    }

    func apiKeyHint(for provider: AIProviderKind) -> String {
        guard provider.keychainAccountName != nil else {
            return "No API key required"
        }
        return agentService.hasAPIKey(for: provider) ? "Stored in Keychain" : "No key saved"
    }

    func saveAPIKey(_ value: String, for provider: AIProviderKind) {
        do {
            guard let accountName = provider.keychainAccountName else {
                return
            }

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let keychainStore = KeychainStore(account: accountName)
            guard !trimmed.isEmpty else {
                try keychainStore.delete()
                aiProviderStatus = agentService.status(for: providerSettings.selectedConfiguration)
                appendAssistant("\(provider.displayName) API key removed. \(aiProviderStatus.detail)")
                return
            }
            try keychainStore.save(trimmed)
            aiProviderStatus = agentService.status(for: providerSettings.selectedConfiguration)
            appendAssistant("\(provider.displayName) API key saved to the macOS Keychain. \(aiProviderStatus.detail)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveProviderSettings(_ draft: AIProviderSettingsDraft) {
        providerSettings = draft
        aiSettingsStore.saveDraft(draft)
        aiProviderStatus = agentService.status(for: draft.selectedConfiguration)
        appendAssistant("Planning provider set to \(aiProviderStatus.badge). \(aiProviderStatus.detail)")
    }

    func saveColorPalette(_ palette: AppColorPalette) {
        colorPalette = palette
        appearanceSettingsStore.saveColorPalette(palette)
    }

    func discoverModels(for configuration: AIProviderConfiguration) async throws -> [String] {
        try await agentService.discoverModels(for: configuration)
    }

    private func createProject(from prompt: String) async throws {
        guard selectedPlatform.isAvailableInCurrentMVP else {
            appendAssistant("\(selectedPlatform.displayName) generation is planned, but this MVP currently scaffolds macOS apps only.")
            return
        }

        if let builtInBlueprint = builtInRecipeService.initialBlueprint(for: prompt, platform: selectedPlatform) {
            buildPhase = .planning
            appendAssistant("Using AppForge's built-in \(builtInBlueprint.appName) generator.")

            let project = try scaffolder.createProject(
                from: builtInBlueprint,
                prompt: prompt,
                platform: selectedPlatform,
                workspaceManager: workspaceManager
            )

            try reloadProjects(selecting: project.rootURL)
            await runBuild(for: project, shouldLaunch: false)
            return
        }

        aiProviderStatus = agentService.status(for: providerSettings.selectedConfiguration)
        guard aiProviderStatus.isReady else {
            appendAssistant(aiProviderStatus.detail)
            return
        }

        buildPhase = .planning
        appendAssistant("Planning a first runnable \(selectedPlatform.displayName) build…")

        let planningResult = try await agentService.planInitialApp(
            prompt: prompt,
            platform: selectedPlatform,
            capability: capability,
            configuration: providerSettings.selectedConfiguration
        )
        aiProviderStatus = planningResult.providerStatus

        appendAssistant("""
        Planning provider: \(planningResult.providerStatus.badge) (\(planningResult.providerStatus.networkLabel.lowercased())).
        \(planningResult.providerStatus.detail)
        \(scaffoldModeSummary)
        """)

        buildPhase = .scaffolding
        appendAssistant("""
        Scaffolding \(planningResult.blueprint.appName) with:
        \(planningResult.blueprint.features.map { "• \($0)" }.joined(separator: "\n"))
        """)

        let project = try scaffolder.createProject(
            from: planningResult.blueprint,
            prompt: prompt,
            platform: selectedPlatform,
            workspaceManager: workspaceManager
        )

        try reloadProjects(selecting: project.rootURL)
        await runBuild(for: project, shouldLaunch: false)
    }

    private func refine(project: GeneratedProject, prompt: String) async throws {
        if let builtInBlueprint = builtInRecipeService.refinementBlueprint(for: prompt, project: project) {
            buildPhase = .planning
            appendAssistant("Refreshing the built-in \(project.name) generator.")

            let updatedProject = try scaffolder.refineProject(project, with: builtInBlueprint, prompt: prompt)

            try reloadProjects(selecting: updatedProject.rootURL)
            await runBuild(for: updatedProject, shouldLaunch: false)
            return
        }

        aiProviderStatus = agentService.status(for: providerSettings.selectedConfiguration)
        guard aiProviderStatus.isReady else {
            appendAssistant(aiProviderStatus.detail)
            return
        }

        buildPhase = .planning
        appendAssistant("Refining \(project.name)…")

        let planningResult = try await agentService.planRefinement(
            prompt: prompt,
            project: project,
            configuration: providerSettings.selectedConfiguration
        )
        aiProviderStatus = planningResult.providerStatus

        appendAssistant("""
        Planning provider: \(planningResult.providerStatus.badge) (\(planningResult.providerStatus.networkLabel.lowercased())).
        \(planningResult.providerStatus.detail)
        \(scaffoldModeSummary)
        """)

        let updatedProject = try scaffolder.refineProject(project, with: planningResult.blueprint, prompt: prompt)

        try reloadProjects(selecting: updatedProject.rootURL)
        await runBuild(for: updatedProject, shouldLaunch: false)
    }

    private func runBuild(for project: GeneratedProject, shouldLaunch: Bool) async {
        do {
            buildPhase = .building
            let buildResult = try await BuildRunner.build(project: project)
            buildLog += outputSection(title: "Build \(project.name)", body: buildResult.output)
            buildPhase = buildResult.phase

            if buildResult.success {
                appendAssistant("Build succeeded for \(project.name).")
                if shouldLaunch {
                    buildPhase = .launching
                    let launchResult = try await BuildRunner.launch(project: project)
                    buildLog += outputSection(title: "Launch \(project.name)", body: launchResult.output)
                    buildPhase = launchResult.success ? .launching : .failed
                    if launchResult.success {
                        appendAssistant("Launched \(project.name). Tell me what you want refined next.")
                    } else {
                        appendAssistant("The app built, but launch failed. Review the build log.")
                    }
                } else {
                    appendAssistant("Auto-launch is disabled while the build loop is being stabilized. Use Launch when you're ready to open \(project.name).")
                }
            } else {
                appendAssistant("Build failed for \(project.name). Review the compiler output in the build log.")
            }
        } catch {
            buildPhase = .failed
            errorMessage = error.localizedDescription
            appendAssistant("Build pipeline failed: \(error.localizedDescription)")
        }
    }

    private func reloadProjects(selecting projectRootURL: URL) throws {
        projects = try workspaceManager.loadProjects()
        if let refreshed = projects.first(where: { $0.rootURL == projectRootURL }) {
            load(project: refreshed)
        }
    }

    private func preferredPreviewURL(in project: GeneratedProject) -> URL? {
        let candidateURLs = [
            project.rootURL
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent(project.name, isDirectory: true)
                .appendingPathComponent("ContentView.swift"),
            project.rootURL.appendingPathComponent("README.md"),
            project.rootURL.appendingPathComponent("project.yml"),
            project.rootURL.appendingPathComponent("AppForgeSpec.json")
        ]

        return candidateURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    private func appendAssistant(_ text: String) {
        messages.append(ChatMessage(role: .assistant, text: text))
    }

    private func appendUser(_ text: String) {
        messages.append(ChatMessage(role: .user, text: text))
    }

    private func outputSection(title: String, body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let renderedBody = trimmed.isEmpty ? "(no output)" : trimmed
        return """

        ===== \(title) =====
        \(renderedBody)
        """
    }
}
