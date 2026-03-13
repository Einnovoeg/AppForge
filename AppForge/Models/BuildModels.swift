import Foundation

/// Tracks the user-visible phase of the generation/build loop.
enum BuildPhase: String {
    case idle
    case planning
    case scaffolding
    case building
    case launching
    case succeeded
    case failed

    var label: String {
        switch self {
        case .idle:
            return "Idle"
        case .planning:
            return "Planning"
        case .scaffolding:
            return "Scaffolding"
        case .building:
            return "Building"
        case .launching:
            return "Launching"
        case .succeeded:
            return "Build Succeeded"
        case .failed:
            return "Build Failed"
        }
    }
}

/// Wraps the output from a build or launch step so the UI can render one consistent log stream.
struct BuildRunResult {
    let success: Bool
    let phase: BuildPhase
    let output: String
    let appURL: URL?
}
