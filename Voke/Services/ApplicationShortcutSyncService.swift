import Combine
import Foundation

struct CodexKeybindingEntry: Codable, Equatable {
    let command: String
    let key: String?
}

enum ApplicationShortcutSource: Equatable {
    case codexConfiguration
    case codexDefault
    case disabled
    case unavailable
}

struct ApplicationShortcutResolution: Equatable {
    let shortcut: KeyboardShortcut?
    let accelerator: String?
    let source: ApplicationShortcutSource
}

enum CodexKeybindingResolver {
    static func resolve(
        preset: ApplicationActionPreset,
        entries: [CodexKeybindingEntry]
    ) -> ApplicationShortcutResolution {
        let configured = entries.filter { $0.command == preset.commandID }
        if !configured.isEmpty {
            if configured.contains(where: { $0.key == nil }) {
                return ApplicationShortcutResolution(shortcut: nil, accelerator: nil, source: .disabled)
            }
            for accelerator in configured.compactMap(\.key) {
                if let shortcut = CodexAcceleratorParser.parse(accelerator) {
                    return ApplicationShortcutResolution(
                        shortcut: shortcut,
                        accelerator: accelerator,
                        source: .codexConfiguration
                    )
                }
            }
            return ApplicationShortcutResolution(shortcut: nil, accelerator: configured.compactMap(\.key).first, source: .unavailable)
        }

        for accelerator in preset.fallbackAccelerators {
            if let shortcut = CodexAcceleratorParser.parse(accelerator) {
                return ApplicationShortcutResolution(shortcut: shortcut, accelerator: accelerator, source: .codexDefault)
            }
        }
        return ApplicationShortcutResolution(shortcut: nil, accelerator: nil, source: .unavailable)
    }
}

enum CodexKeybindingLocator {
    static func candidateURLs(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        applicationSupportDirectory: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ) -> [URL] {
        var directories: [URL] = []
        if let configured = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty {
            directories.append(URL(fileURLWithPath: configured, isDirectory: true))
        }
        directories.append(homeDirectory.appendingPathComponent(".codex", isDirectory: true))

        if let applicationSupport = applicationSupportDirectory {
            directories.append(applicationSupport.appendingPathComponent("OpenAI/Codex", isDirectory: true))
            directories.append(applicationSupport.appendingPathComponent("Codex", isDirectory: true))
        }

        var seen: Set<String> = []
        return directories.compactMap { directory in
            let url = directory.appendingPathComponent("keybindings.json", isDirectory: false).standardizedFileURL
            return seen.insert(url.path).inserted ? url : nil
        }
    }
}

@MainActor
final class ApplicationShortcutSyncService: ObservableObject {
    @Published private(set) var entries: [CodexKeybindingEntry] = []
    @Published private(set) var keymapURL: URL
    @Published private(set) var lastReloadAt: Date?
    @Published private(set) var loadError: String?

    private let candidateURLs: [URL]
    private var watcher: DispatchSourceFileSystemObject?
    private var watchedDirectory: URL?
    private var debounceWorkItem: DispatchWorkItem?

    init(candidateURLs: [URL] = CodexKeybindingLocator.candidateURLs()) {
        let candidates = candidateURLs.isEmpty ? CodexKeybindingLocator.candidateURLs() : candidateURLs
        self.candidateURLs = candidates
        keymapURL = candidates.first!
    }

    var statusText: String {
        if let loadError { return "Codex 快捷键配置无效：\(loadError)" }
        if FileManager.default.fileExists(atPath: keymapURL.path) {
            return "已自动同步 Codex 快捷键"
        }
        return "使用 Codex 默认快捷键；你在 Codex 修改后会自动同步"
    }

    func start() {
        refresh()
        installWatcher()
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        watcher?.cancel()
        watcher = nil
        watchedDirectory = nil
    }

    func refresh() {
        let fileManager = FileManager.default
        keymapURL = candidateURLs.first(where: { fileManager.fileExists(atPath: $0.path) }) ?? candidateURLs[0]

        guard fileManager.fileExists(atPath: keymapURL.path) else {
            entries = []
            loadError = nil
            lastReloadAt = Date()
            ensureWatcherMatchesCurrentPath()
            return
        }

        do {
            let data = try Data(contentsOf: keymapURL)
            entries = try JSONDecoder().decode([CodexKeybindingEntry].self, from: data)
            loadError = nil
            lastReloadAt = Date()
        } catch {
            loadError = error.localizedDescription
        }
        ensureWatcherMatchesCurrentPath()
    }

    func resolution(for preset: ApplicationActionPreset) -> ApplicationShortcutResolution {
        CodexKeybindingResolver.resolve(preset: preset, entries: entries)
    }

    private func installWatcher() {
        let fileManager = FileManager.default
        let directory = keymapURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard watchedDirectory != directory else { return }

        watcher?.cancel()
        watcher = nil
        watchedDirectory = nil

        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .extend, .attrib, .link, .revoke],
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.scheduleRefresh() }
        source.setCancelHandler { close(descriptor) }
        watchedDirectory = directory
        watcher = source
        source.resume()
    }

    private func ensureWatcherMatchesCurrentPath() {
        if watchedDirectory != keymapURL.deletingLastPathComponent() {
            installWatcher()
        }
    }

    private func scheduleRefresh() {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.refresh() }
        debounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: item)
    }
}
