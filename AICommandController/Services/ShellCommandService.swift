import Foundation

struct ShellCommandResult {
    let exitCode: Int32
    let output: String
}

final class ShellCommandService {
    func run(_ command: String) async -> ShellCommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    var output = String(data: data, encoding: .utf8) ?? ""
                    output = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if output.count > 600 {
                        output = String(output.prefix(600)) + "…"
                    }
                    continuation.resume(returning: ShellCommandResult(exitCode: process.terminationStatus, output: output))
                } catch {
                    continuation.resume(returning: ShellCommandResult(exitCode: -1, output: error.localizedDescription))
                }
            }
        }
    }
}
