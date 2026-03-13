import Foundation

/// Platforms modeled by the UI, even though the MVP only scaffolds macOS today.
enum AppPlatform: String, CaseIterable, Identifiable, Codable {
    case macOS
    case iOS
    case iPadOS
    case watchOS

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .macOS:
            return "macOS"
        case .iOS:
            return "iPhone"
        case .iPadOS:
            return "iPad"
        case .watchOS:
            return "Apple Watch"
        }
    }

    var xcodeDestination: String {
        switch self {
        case .macOS:
            return "platform=macOS,arch=arm64"
        case .iOS:
            return "platform=iOS Simulator,name=iPhone 16 Pro"
        case .iPadOS:
            return "platform=iOS Simulator,name=iPad Pro 13-inch (M4)"
        case .watchOS:
            return "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)"
        }
    }

    var isAvailableInCurrentMVP: Bool {
        self == .macOS
    }
}
