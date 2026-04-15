import Foundation

/// Centralized validation for files and folders inside AppForge's managed workspace.
/// This ensures that AppForge only interacts with files within its own designated directories,
/// preventing arbitrary file system access and mitigating potential directory traversal attacks.
enum WorkspaceSecurityError: LocalizedError {
    case unmanagedProjectRoot
    case inaccessibleProjectItem
    case projectItemTooLarge(maxBytes: Int)

    var errorDescription: String? {
        switch self {
        case .unmanagedProjectRoot:
            return "The selected project is outside AppForge's managed workspace."
        case .inaccessibleProjectItem:
            return "The selected file or directory is not a safe project item."
        case .projectItemTooLarge(let maxBytes):
            return "The selected file is too large to preview safely. Limit: \(maxBytes) bytes."
        }
    }
}

struct WorkspaceSecurity {
    private let fileManager = FileManager.default

    var workspaceURL: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent("AppForge", isDirectory: true)
    }

    var projectsURL: URL {
        workspaceURL.appendingPathComponent("Projects", isDirectory: true)
    }

    var secureDirectoryAttributes: [FileAttributeKey: Any] {
        [.posixPermissions: 0o700]
    }

    func applySecureDirectoryPermissions(to url: URL) throws {
        try fileManager.setAttributes(secureDirectoryAttributes, ofItemAtPath: url.path)
    }

    /// Verifies that a given URL is a valid project root directory within the AppForge workspace.
    func validatedProjectRootURL(_ projectRootURL: URL) throws -> URL {
        let normalizedProjectsURL = normalizedFileURL(projectsURL)
        let normalizedProjectRootURL = normalizedFileURL(projectRootURL)

        guard isDescendant(normalizedProjectRootURL, of: normalizedProjectsURL) else {
            throw WorkspaceSecurityError.unmanagedProjectRoot
        }

        let values = try normalizedProjectRootURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw WorkspaceSecurityError.unmanagedProjectRoot
        }

        return normalizedProjectRootURL
    }

    /// Validates that a file or directory exists within a project root and meets safety criteria.
    /// Checks for symbolic links (disallowed), file size limits, and basic item type (file vs directory).
    func validatedProjectItemURL(
        _ itemURL: URL,
        withinProjectRoot projectRootURL: URL,
        requireRegularFile: Bool,
        maxBytes: Int? = nil
    ) throws -> URL {
        let normalizedProjectRootURL = try validatedProjectRootURL(projectRootURL)
        let normalizedItemURL = normalizedFileURL(itemURL)

        guard isDescendant(normalizedItemURL, of: normalizedProjectRootURL) else {
            throw WorkspaceSecurityError.inaccessibleProjectItem
        }

        let values = try normalizedItemURL.resourceValues(
            forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        )
        guard values.isSymbolicLink != true else {
            throw WorkspaceSecurityError.inaccessibleProjectItem
        }

        if requireRegularFile {
            guard values.isRegularFile == true else {
                throw WorkspaceSecurityError.inaccessibleProjectItem
            }
        } else if values.isRegularFile != true, values.isDirectory != true {
            throw WorkspaceSecurityError.inaccessibleProjectItem
        }

        if let maxBytes, let fileSize = values.fileSize, fileSize > maxBytes {
            throw WorkspaceSecurityError.projectItemTooLarge(maxBytes: maxBytes)
        }

        return normalizedItemURL
    }

    func normalizedFileURL(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    func isDescendant(_ url: URL, of rootURL: URL) -> Bool {
        let normalizedURLPath = normalizedFileURL(url).path
        let normalizedRootPath = normalizedFileURL(rootURL).path
        return normalizedURLPath == normalizedRootPath || normalizedURLPath.hasPrefix(normalizedRootPath + "/")
    }
}
