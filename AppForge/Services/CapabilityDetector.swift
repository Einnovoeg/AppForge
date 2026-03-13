import Foundation

/// Detects the local Apple tooling tier without doing heavyweight work during app launch.
struct CapabilityDetector {
    func detect() async -> CapabilitySnapshot {
        async let xcodeSelect = ProcessRunner.run(executable: "/usr/bin/xcode-select", arguments: ["-p"])
        async let swiftVersion = ProcessRunner.run(executable: "/usr/bin/swift", arguments: ["--version"])

        let developerDirectory = try? await xcodeSelect
        let swift = try? await swiftVersion
        let resolvedDeveloperDirectory = developerDirectory?.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let xcodeAppURL = xcodeAppURL(from: resolvedDeveloperDirectory)

        let tier: CapabilityTier
        if xcodeAppURL != nil {
            tier = .fullXcode
        } else if swift?.exitCode == 0 {
            tier = .macOSReady
        } else {
            tier = .bundledSwiftOnly
        }

        return CapabilitySnapshot(
            tier: tier,
            developerDirectory: resolvedDeveloperDirectory,
            swiftVersion: swift?.output.trimmingCharacters(in: .whitespacesAndNewlines),
            xcodeVersion: xcodeAppURL.flatMap(Self.readXcodeVersion(at:))
        )
    }

    private func xcodeAppURL(from developerDirectory: String?) -> URL? {
        guard let developerDirectory, !developerDirectory.isEmpty else {
            return nil
        }

        let developerURL = URL(fileURLWithPath: developerDirectory)
        guard developerURL.lastPathComponent == "Developer" else {
            return nil
        }

        let contentsURL = developerURL.deletingLastPathComponent()
        let appURL = contentsURL.deletingLastPathComponent()

        guard contentsURL.lastPathComponent == "Contents",
              appURL.pathExtension == "app" else {
            return nil
        }

        return appURL
    }

    private static func readXcodeVersion(at appURL: URL) -> String? {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOf: infoURL) as? [String: Any] else {
            return nil
        }

        let shortVersion = info["CFBundleShortVersionString"] as? String
        let buildVersion = info["ProductBuildVersion"] as? String

        let components = [shortVersion, buildVersion]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }

        guard !components.isEmpty else {
            return nil
        }

        return components.joined(separator: " ")
    }
}
