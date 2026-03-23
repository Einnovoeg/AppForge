import AppKit
import Foundation

/// Owns the portable on-disk workspace used for generated projects and AppForge metadata.
struct WorkspaceManager {
    private let fileManager = FileManager.default
    private let workspaceSecurity = WorkspaceSecurity()

    var workspaceURL: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent("AppForge", isDirectory: true)
    }

    var projectsURL: URL {
        workspaceURL.appendingPathComponent("Projects", isDirectory: true)
    }

    var cacheURL: URL {
        workspaceURL.appendingPathComponent("Cache", isDirectory: true)
    }

    var logsURL: URL {
        workspaceURL.appendingPathComponent("Logs", isDirectory: true)
    }

    var configURL: URL {
        workspaceURL.appendingPathComponent("Config", isDirectory: true)
    }

    func bootstrapDirectories() throws {
        // Keep every generated artifact under one user-owned directory so cleanup is predictable.
        for url in [workspaceURL, projectsURL, cacheURL, logsURL, configURL] {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: workspaceSecurity.secureDirectoryAttributes
            )
            try workspaceSecurity.applySecureDirectoryPermissions(to: url)
        }
    }

    func makeProjectRoot(for name: String) -> URL {
        let stamp = Self.projectTimestampFormatter.string(from: .now)
        return projectsURL.appendingPathComponent("\(name)-\(stamp)", isDirectory: true)
    }

    func loadProjects() throws -> [GeneratedProject] {
        guard fileManager.fileExists(atPath: projectsURL.path) else {
            return []
        }

        let candidates = try fileManager.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return candidates.compactMap { url in
            guard let projectRootURL = try? workspaceSecurity.validatedProjectRootURL(url) else {
                return nil
            }

            let specURL = projectRootURL.appendingPathComponent("AppForgeSpec.json")
            guard fileManager.fileExists(atPath: specURL.path) else {
                return nil
            }
            guard let validatedSpecURL = try? workspaceSecurity.validatedProjectItemURL(
                specURL,
                withinProjectRoot: projectRootURL,
                requireRegularFile: true,
                maxBytes: 256_000
            ) else {
                return nil
            }
            guard let data = try? Data(contentsOf: validatedSpecURL),
                  let spec = try? decoder.decode(GeneratedProjectSpec.self, from: data) else {
                return nil
            }
            return GeneratedProject(rootURL: projectRootURL, spec: spec)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadFileTree(for project: GeneratedProject) -> [FileTreeNode] {
        guard let projectRootURL = try? workspaceSecurity.validatedProjectRootURL(project.rootURL) else {
            return []
        }

        return buildNodes(at: projectRootURL, projectRootURL: projectRootURL)
    }

    func fileContents(at url: URL, within project: GeneratedProject) throws -> String {
        let validatedURL = try workspaceSecurity.validatedProjectItemURL(
            url,
            withinProjectRoot: project.rootURL,
            requireRegularFile: true,
            maxBytes: 512_000
        )
        return try String(contentsOf: validatedURL, encoding: .utf8)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    private func buildNodes(at url: URL, projectRootURL: URL) -> [FileTreeNode] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { !ignoredNames.contains($0.lastPathComponent) }
            .compactMap { item -> URL? in
                try? workspaceSecurity.validatedProjectItemURL(
                    item,
                    withinProjectRoot: projectRootURL,
                    requireRegularFile: false
                )
            }
            .sorted { lhs, rhs in
                // Directories stay grouped above files so the browser feels like Finder/Xcode.
                let lhsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let rhsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if lhsDirectory == rhsDirectory {
                    return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
                }
                return lhsDirectory && !rhsDirectory
            }
            .map { item in
                let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return FileTreeNode(
                    url: item,
                    isDirectory: isDirectory,
                    children: isDirectory ? buildNodes(at: item, projectRootURL: projectRootURL) : nil
                )
            }
    }

    private static let projectTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private let ignoredNames: Set<String> = [
        ".DS_Store",
        ".build",
        "Build",
        ".swiftpm"
    ]
}
