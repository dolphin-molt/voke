import Foundation

@MainActor
final class LaunchAtLoginService {
    private let label = "com.dolphin.ai-command-controller.login"

    private var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: agentURL.path)
    }

    var statusText: String {
        isEnabled ? "已启用，登录 Mac 后自动启动" : "未启用"
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try installAgent()
        } else {
            removeAgent()
        }
    }

    private func installAgent() throws {
        let appPath = Bundle.main.bundleURL.path
        guard appPath.hasSuffix(".app") else {
            throw LaunchAtLoginError.appBundleUnavailable
        }

        let properties: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-a", appPath],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: properties,
            format: .xml,
            options: 0
        )

        try FileManager.default.createDirectory(
            at: agentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: agentURL, options: .atomic)

        _ = runLaunchctl(["bootout", domainTarget, agentURL.path])
        let result = runLaunchctl(["bootstrap", domainTarget, agentURL.path])
        guard result.status == 0 else {
            try? FileManager.default.removeItem(at: agentURL)
            throw LaunchAtLoginError.launchctl(result.message)
        }
    }

    private func removeAgent() {
        _ = runLaunchctl(["bootout", domainTarget, agentURL.path])
        try? FileManager.default.removeItem(at: agentURL)
    }

    private var domainTarget: String {
        "gui/\(getuid())"
    }

    private func runLaunchctl(_ arguments: [String]) -> (status: Int32, message: String) {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case appBundleUnavailable
    case launchctl(String)

    var errorDescription: String? {
        switch self {
        case .appBundleUnavailable:
            "无法找到当前 Voke 应用程序包"
        case let .launchctl(message):
            message.isEmpty ? "系统未能注册登录启动项" : message
        }
    }
}
