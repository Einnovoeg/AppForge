import Foundation

/// Describes how much Apple build tooling is available on the current Mac.
enum CapabilityTier: String {
    case bundledSwiftOnly
    case macOSReady
    case fullXcode

    var badge: String {
        switch self {
        case .bundledSwiftOnly:
            return "Bundled Swift"
        case .macOSReady:
            return "macOS Ready"
        case .fullXcode:
            return "Full Xcode"
        }
    }

    var summary: String {
        switch self {
        case .bundledSwiftOnly:
            return "Use the bundled Swift toolchain for command-line or package-first work."
        case .macOSReady:
            return "Build local macOS apps and Swift packages on this machine."
        case .fullXcode:
            return "Xcode is available for local app builds and future simulator workflows."
        }
    }
}

/// Snapshot of the local developer environment as seen by AppForge at startup.
struct CapabilitySnapshot {
    let tier: CapabilityTier
    let developerDirectory: String?
    let swiftVersion: String?
    let xcodeVersion: String?

    var badge: String { tier.badge }
    var summary: String { tier.summary }
}
