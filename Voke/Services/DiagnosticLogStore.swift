import Foundation

final class DiagnosticLogStore {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let activeLogURL: URL
    private let maxBytes: UInt64
    private let retainedFileCount: Int
    private let formatter: ISO8601DateFormatter

    init(
        directoryURL: URL? = nil,
        maxBytes: UInt64 = 2 * 1_024 * 1_024,
        retainedFileCount: Int = 3,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL
            ?? fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Logs/Voke", isDirectory: true)
        activeLogURL = self.directoryURL.appendingPathComponent("voke.log")
        self.maxBytes = maxBytes
        self.retainedFileCount = max(1, retainedFileCount)
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    var logDirectoryPath: String { directoryURL.path }

    func record(_ message: String, at date: Date = Date()) {
        do {
            try prepareDirectory()
            try rotateIfNeeded()
            let line = "\(formatter.string(from: date))  \(Self.redact(message))\n"
            let data = Data(line.utf8)
            if fileManager.fileExists(atPath: activeLogURL.path) {
                let handle = try FileHandle(forWritingTo: activeLogURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: activeLogURL, options: .atomic)
            }
        } catch {
            NSLog("Voke persistent log write failed: %@", error.localizedDescription)
        }
    }

    func exportText(diagnosticReport: String) -> String {
        var sections = [diagnosticReport]
        for url in availableLogURLs() {
            guard let contents = try? String(contentsOf: url, encoding: .utf8), !contents.isEmpty else { continue }
            sections.append("--- Persistent log: \(url.lastPathComponent) ---\n\(contents)")
        }
        for url in recentCrashReportURLs() {
            guard let contents = try? String(contentsOf: url, encoding: .utf8), !contents.isEmpty else { continue }
            sections.append("--- Crash report: \(url.lastPathComponent) ---\n\(contents)")
        }
        return sections.joined(separator: "\n\n")
    }

    static func redact(_ message: String) -> String {
        if message.contains("→ $") {
            return "terminal command invoked [redacted]"
        }
        if message.hasPrefix("命令退出") {
            return "terminal command completed [output redacted]"
        }
        return message
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func rotateIfNeeded() throws {
        guard
            let attributes = try? fileManager.attributesOfItem(atPath: activeLogURL.path),
            let size = attributes[.size] as? NSNumber,
            size.uint64Value >= maxBytes
        else { return }

        if retainedFileCount > 1 {
            for index in stride(from: retainedFileCount - 1, through: 1, by: -1) {
                let source = rotatedLogURL(index: index)
                let destination = rotatedLogURL(index: index + 1)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                if fileManager.fileExists(atPath: source.path) {
                    try fileManager.moveItem(at: source, to: destination)
                }
            }
        }
        let firstArchive = rotatedLogURL(index: 1)
        if fileManager.fileExists(atPath: firstArchive.path) {
            try fileManager.removeItem(at: firstArchive)
        }
        try fileManager.moveItem(at: activeLogURL, to: firstArchive)
    }

    private func rotatedLogURL(index: Int) -> URL {
        directoryURL.appendingPathComponent("voke.log.\(index)")
    }

    private func availableLogURLs() -> [URL] {
        ([activeLogURL] + (1...retainedFileCount).map(rotatedLogURL(index:)))
            .filter { fileManager.fileExists(atPath: $0.path) }
    }

    private func recentCrashReportURLs() -> [URL] {
        let directory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/DiagnosticReports", isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return files
            .filter { $0.lastPathComponent.hasPrefix("Voke_") && ["ips", "crash"].contains($0.pathExtension) }
            .sorted {
                let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhs > rhs
            }
            .prefix(3)
            .map { $0 }
    }
}
