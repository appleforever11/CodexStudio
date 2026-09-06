import Foundation
import Darwin

/// Executes runtime scripts with bounded waiting and bounded diagnostic output.
struct RuntimeProcessRunner {
    static func run(script: URL, arguments: [String], timeout: TimeInterval) -> ProcessOutput {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let stdoutCollector = ProcessDataCollector()
        let stderrCollector = ProcessDataCollector()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path] + arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        process.environment = environment

        do {
            try process.run()
        } catch {
            return ProcessOutput(completed: false, exitCode: -1, detail: "Could not start the Codex runtime: \(error.localizedDescription)")
        }

        let stdoutFD = standardOutput.fileHandleForReading.fileDescriptor
        let stderrFD = standardError.fileHandleForReading.fileDescriptor
        _ = fcntl(stdoutFD, F_SETFL, fcntl(stdoutFD, F_GETFL) | O_NONBLOCK)
        _ = fcntl(stderrFD, F_SETFL, fcntl(stderrFD, F_GETFL) | O_NONBLOCK)
        func collectOutput() {
            drain(stdoutFD, into: stdoutCollector)
            drain(stderrFD, into: stderrCollector)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            collectOutput()
            Thread.sleep(forTimeInterval: 0.05)
        }
        var didTimeOut = false
        if process.isRunning {
            didTimeOut = true
            process.terminate()
            let grace = Date().addingTimeInterval(1)
            while process.isRunning && Date() < grace {
                collectOutput()
                Thread.sleep(forTimeInterval: 0.02)
            }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }

        collectOutput()
        // Do not wait for EOF: a launched helper can inherit these pipes.
        try? standardOutput.fileHandleForReading.close()
        try? standardError.fileHandleForReading.close()
        if didTimeOut {
            return ProcessOutput(completed: false, exitCode: -1, detail: "The Codex theme runtime timed out before verification.")
        }

        let stdout = String(data: stdoutCollector.data, encoding: .utf8) ?? ""
        let stderr = String(data: stderrCollector.data, encoding: .utf8) ?? ""
        let detail = (stderr.isEmpty ? stdout : stderr)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .last
            .map(String.init) ?? ""
        return ProcessOutput(completed: true, exitCode: process.terminationStatus, detail: detail)
    }

    private static func drain(_ descriptor: Int32, into collector: ProcessDataCollector) {
        var buffer = [UInt8](repeating: 0, count: 8192)
        // Bound each pass even if a descendant keeps writing after its parent exits.
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

struct ProcessOutput: Sendable {
    let completed: Bool
    let exitCode: Int32
    let detail: String
}
