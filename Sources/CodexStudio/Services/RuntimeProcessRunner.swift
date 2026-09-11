import Foundation

/// Executes runtime scripts with bounded waiting and bounded diagnostic output.
struct RuntimeProcessRunner {
    static func run(script: URL, arguments: [String], timeout: TimeInterval) -> ProcessOutput {
        let result = LocalCommandRunner.run(
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [script.path] + arguments,
            timeout: timeout
        )
        let detail: String
        if result.timedOut {
            detail = "The Codex theme runtime timed out before verification."
        } else if result.detail.isEmpty {
            detail = result.completed ? "" : "Could not start the Codex runtime."
        } else {
            detail = result.detail
        }
        return ProcessOutput(completed: result.completed, exitCode: result.exitCode, detail: detail)
    }
}

struct ProcessOutput: Sendable {
    let completed: Bool
    let exitCode: Int32
    let detail: String
}
