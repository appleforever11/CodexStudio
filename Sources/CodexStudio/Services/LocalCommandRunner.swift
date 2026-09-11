import Foundation
import Darwin

/// Runs local inspection commands without allowing a child process or pipe to
/// hold the Studio UI indefinitely. Output is intentionally bounded because
/// diagnostics are for capability discovery, not log archival.
struct LocalCommandRunner: Sendable {
    static let defaultPath = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"

    static func run(
        executable: URL,
        arguments: [String],
        timeout: TimeInterval,
        environment additions: [String: String] = [:]
    ) -> LocalCommandResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let stdoutCollector = ProcessDataCollector()
        let stderrCollector = ProcessDataCollector()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = defaultPath
        environment.merge(additions) { _, new in new }
        process.environment = environment

        do {
            try process.run()
        } catch {
            return LocalCommandResult(
                completed: false,
                timedOut: false,
                exitCode: -1,
                stdout: "",
                stderr: "Could not start local inspection: \(error.localizedDescription)"
            )
        }

        let stdoutFD = standardOutput.fileHandleForReading.fileDescriptor
        let stderrFD = standardError.fileHandleForReading.fileDescriptor
        _ = fcntl(stdoutFD, F_SETFL, fcntl(stdoutFD, F_GETFL) | O_NONBLOCK)
        _ = fcntl(stderrFD, F_SETFL, fcntl(stderrFD, F_GETFL) | O_NONBLOCK)
        func collectOutput() {
            drain(stdoutFD, into: stdoutCollector)
            drain(stderrFD, into: stderrCollector)
        }

        let deadline = Date().addingTimeInterval(max(0.05, timeout))
        while process.isRunning && Date() < deadline {
            collectOutput()
            Thread.sleep(forTimeInterval: 0.05)
        }

        var timedOut = false
        if process.isRunning {
            timedOut = true
            process.terminate()
            let graceDeadline = Date().addingTimeInterval(1)
            while process.isRunning && Date() < graceDeadline {
                collectOutput()
                Thread.sleep(forTimeInterval: 0.02)
            }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }

        collectOutput()
        try? standardOutput.fileHandleForReading.close()
        try? standardError.fileHandleForReading.close()
        let stdout = String(data: stdoutCollector.data, encoding: .utf8) ?? ""
        let stderr = String(data: stderrCollector.data, encoding: .utf8) ?? ""
        return LocalCommandResult(
            completed: !timedOut,
            timedOut: timedOut,
            exitCode: timedOut ? -1 : process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }

    private static func drain(_ descriptor: Int32, into collector: ProcessDataCollector) {
        var buffer = [UInt8](repeating: 0, count: 8192)
        // Bound every pass even when a descendant inherits the pipe.
        for _ in 0..<64 {
            let count = read(descriptor, &buffer, buffer.count)
            guard count > 0 else { return }
            collector.append(Data(buffer.prefix(count)))
        }
    }
}

private final class ProcessDataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        if storage.count > 65536 { storage.removeFirst(storage.count - 65536) }
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

struct LocalCommandResult: Sendable {
    let completed: Bool
    let timedOut: Bool
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var detail: String {
        let preferred = stderr.isEmpty ? stdout : stderr
        return preferred
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .last
            .map(String.init) ?? ""
    }
}
