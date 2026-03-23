import Foundation

enum BuildRunnerError: LocalizedError {
    case missingDependency(tool: String, installHint: String)

    var errorDescription: String? {
        switch self {
        case .missingDependency(let tool, let installHint):
            return "\(tool) is required to build generated apps. \(installHint)"
        }
    }
}

/// Wraps the local XcodeGen and xcodebuild pipeline used for generated projects.
enum BuildRunner {
    static func build(project: GeneratedProject) async throws -> BuildRunResult {
        let workspaceSecurity = WorkspaceSecurity()
        let projectRootURL = try workspaceSecurity.validatedProjectRootURL(project.rootURL)
        let tools = try await resolveBuildTools()

        let generateResult = try await ProcessRunner.run(
            executable: tools.xcodegen,
            arguments: ["generate", "--spec", "project.yml"],
            currentDirectory: projectRootURL
        )

        guard generateResult.exitCode == 0 else {
            return BuildRunResult(
                success: false,
                phase: .failed,
                output: generateResult.output.isEmpty ? "xcodegen failed before the project could be built." : generateResult.output,
                appURL: nil
            )
        }

        let buildResult = try await ProcessRunner.run(
            executable: tools.xcodebuild,
            arguments: [
                "-project", "\(project.name).xcodeproj",
                "-scheme", project.name,
                "-configuration", "Debug",
                "-derivedDataPath", "Build/DerivedData",
                "-destination", project.platform.xcodeDestination,
                "build"
            ],
            currentDirectory: projectRootURL
        )

        let appURL = buildResult.exitCode == 0 ? builtAppURL(for: project, projectRootURL: projectRootURL) : nil
        let output = [generateResult.output, buildResult.output]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return BuildRunResult(
            success: buildResult.exitCode == 0,
            phase: buildResult.exitCode == 0 ? .succeeded : .failed,
            output: output,
            appURL: appURL
        )
    }

    static func launch(project: GeneratedProject) async throws -> BuildRunResult {
        let workspaceSecurity = WorkspaceSecurity()
        let projectRootURL = try workspaceSecurity.validatedProjectRootURL(project.rootURL)

        guard let appURL = builtAppURL(for: project, projectRootURL: projectRootURL) else {
            return BuildRunResult(
                success: false,
                phase: .failed,
                output: "Built app bundle was not found for \(project.name).",
                appURL: nil
            )
        }

        let result = try await ProcessRunner.run(
            executable: "/usr/bin/open",
            arguments: [appURL.path(percentEncoded: false)]
        )

        return BuildRunResult(
            success: result.exitCode == 0,
            phase: result.exitCode == 0 ? .launching : .failed,
            output: result.output.isEmpty ? "Launched \(project.name)." : result.output,
            appURL: appURL
        )
    }

    private static func builtAppURL(for project: GeneratedProject, projectRootURL: URL) -> URL? {
        let workspaceSecurity = WorkspaceSecurity()
        let fileManager = FileManager.default
        let debugProductsURL = projectRootURL.appendingPathComponent("Build/DerivedData/Build/Products/Debug", isDirectory: true)
        guard let products = try? fileManager.contentsOfDirectory(
            at: debugProductsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return products.first(where: { candidate in
            guard candidate.pathExtension == "app" else {
                return false
            }
            return workspaceSecurity.isDescendant(candidate, of: projectRootURL)
        })
    }

    private static func resolveBuildTools() async throws -> (xcodegen: String, xcodebuild: String) {
        async let xcodegen = resolveTool(
            named: "xcodegen",
            installHint: "Install XcodeGen and ensure it is on PATH. Homebrew example: `brew install xcodegen`."
        )
        async let xcodebuild = resolveTool(
            named: "xcodebuild",
            installHint: "Install Xcode and its command line tools, then make sure `xcodebuild` is available."
        )

        return try await (xcodegen, xcodebuild)
    }

    private static func resolveTool(named tool: String, installHint: String) async throws -> String {
        let result = try await ProcessRunner.run(executable: "/usr/bin/which", arguments: [tool])
        let resolvedPath = result.output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard result.exitCode == 0, !resolvedPath.isEmpty else {
            throw BuildRunnerError.missingDependency(tool: tool, installHint: installHint)
        }

        return resolvedPath
    }
}
