import AppKit
import Foundation

/// Owns the portable on-disk workspace used for generated projects and AppForge metadata.
struct WorkspaceManager {
    private let fileManager = FileManager.default

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
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
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

        return try candidates.compactMap { url in
            let specURL = url.appendingPathComponent("AppForgeSpec.json")
            guard fileManager.fileExists(atPath: specURL.path) else {
                return nil
            }
            let data = try Data(contentsOf: specURL)
            let spec = try decoder.decode(GeneratedProjectSpec.self, from: data)
            return GeneratedProject(rootURL: url, spec: spec)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadFileTree(for project: GeneratedProject) -> [FileTreeNode] {
        let sourceRoot = project.rootURL
        return buildNodes(at: sourceRoot)
    }

    func fileContents(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    private func buildNodes(at url: URL) -> [FileTreeNode] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { !ignoredNames.contains($0.lastPathComponent) }
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
                    children: isDirectory ? buildNodes(at: item) : nil
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
