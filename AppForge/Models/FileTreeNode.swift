import Foundation

/// Recursive representation of a generated project's file tree.
struct FileTreeNode: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let children: [FileTreeNode]?

    var id: String { url.path(percentEncoded: false) }
    var name: String { url.lastPathComponent }
}
