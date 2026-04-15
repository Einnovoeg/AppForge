import Foundation

/// Result of a subprocess invocation captured through one merged stdout/stderr stream.
struct ProcessExecutionResult {
    let exitCode: Int32
    let output: String
}

enum ProcessRunnerError: LocalizedError {
    case invalidExecutable(String)

    var errorDescription: String? {
        switch self {
        case .invalidExecutable(let path):
            return "Executable not found: \(path)"
        }
    }
}

/// Lightweight async process wrapper used by tooling detection and local build steps.
enum ProcessRunner {
    /// Executes a system command asynchronously and captures its output.
    /// Uses `Process` directly to avoid shell injection vulnerabilities.
    static func run(
        executable: String,
        arguments: [String] = [],
        currentDirectory: URL? = nil,
        environment: [String: String] = [:]
    ) async throws -> ProcessExecutionResult {
        let executableURL = URL(fileURLWithPath: executable)
        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            throw ProcessRunnerError.invalidExecutable(executable)
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                let outputCollector = OutputCollector()

                process.executableURL = executableURL
                process.arguments = arguments
                process.currentDirectoryURL = currentDirectory
                process.environment = safeBaseEnvironment().merging(environment) { _, new in new }
                process.standardOutput = pipe
                process.standardError = pipe

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    guard !chunk.isEmpty else { return }
                    outputCollector.append(chunk)
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    pipe.fileHandleForReading.readabilityHandler = nil

                    // Drain any remaining buffered bytes after the process exits.
                    let trailingData = pipe.fileHandleForReading.readDataToEndOfFile()
                    if !trailingData.isEmpty {
                        outputCollector.append(trailingData)
                    }

                    let output = outputCollector.output
                    continuation.resume(
                        returning: ProcessExecutionResult(
                            exitCode: process.terminationStatus,
                            output: output
                        )
                    )
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Filters the current process environment to a minimal set of safe, necessary variables.
    /// This prevents leaking sensitive environment variables or conflicting configurations into subprocesses.
    private static func safeBaseEnvironment() -> [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        let allowedKeys: Set<String> = [
            "HOME",
            "LOGNAME",
            "PATH",
            "SHELL",
            "TMPDIR",
            "USER",
            "LANG",
            "LC_ALL",
            "LC_CTYPE",
            "DEVELOPER_DIR",
            "TERM",
            "TERM_PROGRAM",
            "__CF_USER_TEXT_ENCODING"
        ]

        return inherited.reduce(into: [:]) { result, pair in
            guard allowedKeys.contains(pair.key) else { return }
            result[pair.key] = pair.value
        }
    }
}

/// Simple locked buffer for pipe output collected from background readability callbacks.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var output: String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(decoding: snapshot, as: UTF8.self)
    }
}
