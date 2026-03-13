import Foundation

/// Persisted metadata for an AppForge-generated project.
struct GeneratedProjectSpec: Codable {
    var name: String
    var platform: AppPlatform
    var bundleIdentifier: String
    var prompt: String
    var summary: String
    var features: [String]
    var createdAt: Date
    var updatedAt: Date
    var refinementHistory: [String]
}

/// Lightweight projection of a generated project plus its on-disk location.
struct GeneratedProject: Identifiable {
    let rootURL: URL
    let spec: GeneratedProjectSpec

    var id: String { rootURL.path(percentEncoded: false) }
    var name: String { spec.name }
    var platform: AppPlatform { spec.platform }
    var summary: String { spec.summary }
    var features: [String] { spec.features }
    var prompt: String { spec.prompt }
    var createdAt: Date { spec.createdAt }
    var updatedAt: Date { spec.updatedAt }
    var bundleIdentifier: String { spec.bundleIdentifier }

    var projectFileURL: URL {
        rootURL.appendingPathComponent("project.yml")
    }

    var xcodeProjectURL: URL {
        rootURL.appendingPathComponent("\(name).xcodeproj")
    }

    var derivedDataURL: URL {
        rootURL.appendingPathComponent("Build/DerivedData")
    }

    var specURL: URL {
        rootURL.appendingPathComponent("AppForgeSpec.json")
    }
}
