import XCTest
@testable import Voke

@MainActor
final class MappingStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "MappingStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testNewStoreDefaultsSticksToScrollAndMouse() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))

        XCTAssertEqual(store.mapping(for: .leftStickUp).actionKind, .scroll)
        XCTAssertEqual(store.mapping(for: .leftStickUp).scrollDirection, .up)
        XCTAssertEqual(store.mapping(for: .leftStickDown).scrollDirection, .down)
        XCTAssertEqual(store.mapping(for: .leftStickLeft).scrollDirection, .left)
        XCTAssertEqual(store.mapping(for: .leftStickRight).scrollDirection, .right)
        XCTAssertEqual(store.mapping(for: .rightStickLeft).actionKind, .mouseMove)
        XCTAssertEqual(store.mapping(for: .rightStickRight).actionKind, .mouseMove)
        XCTAssertEqual(store.mapping(for: .rightStickUp).actionKind, .mouseMove)
        XCTAssertEqual(store.mapping(for: .rightStickDown).actionKind, .mouseMove)
        XCTAssertEqual(store.mapping(for: .rightStick).actionKind, .mouseClick)
        XCTAssertEqual(store.mapping(for: .capture).actionKind, .screenshot)
    }

    func testExportImportRoundTripPreservesMappings() throws {
        let source = MappingStore(defaults: defaults)
        source.registerDevice(gamepad(id: "gamepad.one"))
        source.update(.rightTrigger) { mapping in
            mapping.actionKind = .shortcut
            mapping.shortcut = .rightControl
            mapping.triggerBehavior = .hold
        }
        let data = try source.exportData(exportedAt: Date(timeIntervalSince1970: 0))

        let secondSuite = "MappingStoreTests.\(UUID().uuidString)"
        let secondDefaults = try XCTUnwrap(UserDefaults(suiteName: secondSuite))
        defer { secondDefaults.removePersistentDomain(forName: secondSuite) }
        let destination = MappingStore(defaults: secondDefaults)
        try destination.importData(data)

        XCTAssertEqual(destination.mapping(for: .rightTrigger), source.mapping(for: .rightTrigger))
        XCTAssertEqual(destination.mappings.count, ControllerControl.allCases.count)
    }

    func testOldUnmodifiedRightStickDefaultsMigrateToMouseControl() {
        let original = MappingStore(defaults: defaults)
        let device = gamepad(id: "gamepad.one")
        original.registerDevice(device)
        original.update(.rightStickUp) { $0.actionKind = .none }
        original.update(.rightStickDown) { $0.actionKind = .none }
        original.update(.rightStickLeft) {
            $0.actionKind = .appSwitch
            $0.appSwitchDirection = .previous
        }
        original.update(.rightStickRight) {
            $0.actionKind = .appSwitch
            $0.appSwitchDirection = .next
        }
        original.update(.rightStick) { $0.actionKind = .none }
        defaults.set(true, forKey: "mouseControlsMigration.v1")

        let reloaded = MappingStore(defaults: defaults)
        reloaded.registerDevice(device)

        XCTAssertEqual(reloaded.mapping(for: .rightStickUp).actionKind, .mouseMove)
        XCTAssertEqual(reloaded.mapping(for: .rightStickDown).actionKind, .mouseMove)
        XCTAssertEqual(reloaded.mapping(for: .rightStickLeft).actionKind, .mouseMove)
        XCTAssertEqual(reloaded.mapping(for: .rightStickRight).actionKind, .mouseMove)
        XCTAssertEqual(reloaded.mapping(for: .rightStick).actionKind, .mouseClick)
    }

    func testCustomizedRightStickIsNotOverwrittenByMigration() {
        let original = MappingStore(defaults: defaults)
        let device = gamepad(id: "gamepad.one")
        original.registerDevice(device)
        original.update(.rightStick) {
            $0.actionKind = .screenshot
        }
        defaults.set(true, forKey: "mouseControlsMigration.v1")

        let reloaded = MappingStore(defaults: defaults)
        reloaded.registerDevice(device)

        XCTAssertEqual(reloaded.mapping(for: .rightStick).actionKind, .screenshot)
    }

    func testOneTimeMouseUpgradeAppliesThenStopsOverwriting() {
        let original = MappingStore(defaults: defaults)
        let device = gamepad(id: "gamepad.one")
        original.registerDevice(device)
        original.update(.rightStick) { $0.actionKind = .screenshot }

        let upgraded = MappingStore(defaults: defaults)
        XCTAssertEqual(upgraded.mapping(for: .rightStick).actionKind, .mouseClick)
        XCTAssertEqual(upgraded.mapping(for: .rightStickUp).actionKind, .mouseMove)

        upgraded.update(.rightStick) { $0.actionKind = .screenshot }
        let reloaded = MappingStore(defaults: defaults)
        XCTAssertEqual(reloaded.mapping(for: .rightStick).actionKind, .screenshot)
    }

    func testImportRejectsUnsupportedVersionWithoutChangingMappings() throws {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        let original = store.mappings
        let backup = MappingBackup(formatVersion: 99, exportedAt: Date(), mappings: [])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        XCTAssertThrowsError(try store.importData(encoder.encode(backup)))
        XCTAssertEqual(store.mappings, original)
    }

    func testInputSourceActionSurvivesBackupRoundTrip() throws {
        let source = MappingStore(defaults: defaults)
        source.registerDevice(gamepad(id: "gamepad.one"))
        source.update(.home) { mapping in
            mapping.actionKind = .inputSource
        }

        let secondSuite = "MappingStoreTests.\(UUID().uuidString)"
        let secondDefaults = try XCTUnwrap(UserDefaults(suiteName: secondSuite))
        defer { secondDefaults.removePersistentDomain(forName: secondSuite) }
        let destination = MappingStore(defaults: secondDefaults)
        try destination.importData(source.exportData())

        XCTAssertEqual(destination.mapping(for: .home).actionKind, .inputSource)
        XCTAssertEqual(destination.mapping(for: .home).summary, "中 / EN")
    }

    func testDevicesKeepIndependentMappings() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        store.registerDevice(gamepad(id: "gamepad.two"))

        store.selectDevice("gamepad.one")
        store.update(.a) { mapping in
            mapping.actionKind = .shortcut
            mapping.shortcut = KeyboardShortcut(keyCode: 0, modifierFlags: 0, modifierOnly: false)
        }

        XCTAssertEqual(store.mapping(for: .a, deviceID: "gamepad.one").shortcut?.keyCode, 0)
        XCTAssertEqual(store.mapping(for: .a, deviceID: "gamepad.two").actionKind, .none)
    }

    func testProfileCopiesCurrentMappingsAndCanSwitchBack() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        let originalProfile = try! XCTUnwrap(store.activeProfileID)
        store.update(.a) { $0.actionKind = .screenshot }

        store.addProfile()
        XCTAssertEqual(store.mapping(for: .a).actionKind, .screenshot)
        store.update(.a) { $0.actionKind = .none }
        store.setActiveProfile(originalProfile)

        XCTAssertEqual(store.mapping(for: .a).actionKind, .screenshot)
    }

    func testApplicationContextAutomaticallyResolvesDedicatedProfile() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        store.update(.a) { $0.actionKind = .screenshot }

        store.updateApplicationContext(bundleIdentifier: "com.openai.codex", displayName: "ChatGPT")
        store.addProfile()
        store.update(.a) { $0.actionKind = .none }

        XCTAssertTrue(store.currentApplicationUsesDedicatedProfile)
        XCTAssertEqual(store.mapping(for: .a).actionKind, .none)

        store.updateApplicationContext(bundleIdentifier: "com.apple.Safari", displayName: "Safari")
        XCTAssertFalse(store.currentApplicationUsesDedicatedProfile)
        XCTAssertEqual(store.mapping(for: .a).actionKind, .screenshot)

        store.updateApplicationContext(bundleIdentifier: "com.openai.codex", displayName: "ChatGPT")
        XCTAssertEqual(store.mapping(for: .a).actionKind, .none)
    }

    func testDedicatedProfileCannotBecomeFallbackOrBindToAnotherApplication() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        let fallbackProfile = try! XCTUnwrap(store.fallbackProfileID)
        store.update(.a) { mapping in
            mapping.actionKind = .shortcut
            mapping.shortcut = KeyboardShortcut(keyCode: 0, modifierFlags: 0, modifierOnly: false)
        }

        store.updateApplicationContext(bundleIdentifier: "com.openai.codex", displayName: "ChatGPT")
        store.addProfile()
        let chatGPTProfile = try! XCTUnwrap(store.activeProfileID)
        store.update(.a) { mapping in
            mapping.actionKind = .shortcut
            mapping.shortcut = KeyboardShortcut(keyCode: 83, modifierFlags: 0, modifierOnly: false)
        }

        store.updateApplicationContext(bundleIdentifier: "com.tencent.xinWeChat", displayName: "微信")
        XCTAssertEqual(store.activeProfileID, fallbackProfile)
        XCTAssertEqual(store.mapping(for: .a).shortcut?.keyCode, 0)

        store.setActiveProfile(chatGPTProfile)
        store.useProfileForCurrentApplication(chatGPTProfile)

        XCTAssertEqual(store.fallbackProfileID, fallbackProfile)
        XCTAssertEqual(store.activeProfileID, fallbackProfile)
        XCTAssertEqual(store.mapping(for: .a).shortcut?.keyCode, 0)

        store.updateApplicationContext(bundleIdentifier: "com.openai.codex", displayName: "ChatGPT")
        XCTAssertEqual(store.activeProfileID, chatGPTProfile)
        XCTAssertEqual(store.mapping(for: .a).shortcut?.keyCode, 83)
    }

    func testChatGPTApplicationActionsExposeWorkingDefaultShortcuts() throws {
        let actions = ApplicationActionRegistry.actions(for: "com.openai.codex")
        let newTask = try XCTUnwrap(actions.first(where: { $0.id == "chatgpt.newTask" }))
        let modelPicker = try XCTUnwrap(actions.first(where: { $0.id == "chatgpt.openModelPicker" }))
        let dictation = try XCTUnwrap(actions.first(where: { $0.id == "chatgpt.startDictation" }))
        let increaseReasoning = try XCTUnwrap(actions.first(where: { $0.id == "chatgpt.increaseReasoning" }))

        XCTAssertEqual(newTask.defaultShortcut?.displayName, "⌘N")
        XCTAssertEqual(modelPicker.defaultShortcut?.displayName, "⌃⇧M")
        XCTAssertEqual(dictation.defaultShortcut?.displayName, "⌃⇧D")
        XCTAssertEqual(dictation.interaction, .pressAndHold)
        XCTAssertEqual(dictation.group, .codexMicroCore)
        XCTAssertEqual(newTask.interaction, .tap)
        XCTAssertNil(increaseReasoning.defaultShortcut)
        XCTAssertTrue(ApplicationActionRegistry.actions(for: "com.tencent.xinWeChat").isEmpty)
    }

    func testCodexMicroCommandBackedKeycapsAreAvailableAsActions() {
        let microCommands = Set(
            ApplicationActionRegistry.presets
                .filter { $0.group != .codexGeneral }
                .map(\.commandID)
        )

        XCTAssertTrue([
            "composer.toggleFastMode",
            "approval.approve",
            "approval.decline",
            "forkThread",
            "composer.startDictation",
            "composer.submit",
            "feedback",
            "toggleTerminal",
            "copyConversationMarkdown",
            "archiveThread",
            "newTask",
            "openBrowserTab",
            "toggleThreadPin",
            "toggleReviewTab",
            "environmentAction1",
            "git.commit",
            "git.createPullRequest",
            "composer.addPhotos",
            "settings",
            "openSideChat",
            "manageTasks",
            "composer.increaseReasoningEffort",
            "composer.decreaseReasoningEffort",
            "openFolder",
            "composer.addFiles",
            "openSkills"
        ].allSatisfy(microCommands.contains))
    }

    func testCodexKeybindingOverridesResolveByActionInsteadOfStoredShortcut() throws {
        let action = try XCTUnwrap(ApplicationActionRegistry.preset(id: "chatgpt.increaseReasoning"))
        let entries = [
            CodexKeybindingEntry(command: "composer.increaseReasoningEffort", key: "Cmd+Shift+]")
        ]

        let resolution = CodexKeybindingResolver.resolve(preset: action, entries: entries)

        XCTAssertEqual(resolution.source, .codexConfiguration)
        XCTAssertEqual(resolution.shortcut?.displayName, "⇧⌘]")
    }

    func testCodexNullKeybindingDisablesActionAndDoesNotUseFallback() throws {
        let action = try XCTUnwrap(ApplicationActionRegistry.preset(id: "chatgpt.newTask"))
        let entries = [CodexKeybindingEntry(command: "newTask", key: nil)]

        let resolution = CodexKeybindingResolver.resolve(preset: action, entries: entries)

        XCTAssertEqual(resolution.source, .disabled)
        XCTAssertNil(resolution.shortcut)
    }

    func testCodexKeybindingLocatorUsesCurrentUserAndCodexHomeWithoutFixedUsername() {
        let home = URL(fileURLWithPath: "/Users/test-user", isDirectory: true)
        let urls = CodexKeybindingLocator.candidateURLs(
            homeDirectory: home,
            environment: ["CODEX_HOME": "/Volumes/Settings/custom-codex"],
            applicationSupportDirectory: URL(fileURLWithPath: "/Users/test-user/Library/Application Support", isDirectory: true)
        )

        XCTAssertEqual(urls.first?.path, "/Volumes/Settings/custom-codex/keybindings.json")
        XCTAssertTrue(urls.contains { $0.path == "/Users/test-user/.codex/keybindings.json" })
        XCTAssertFalse(urls.contains { $0.path.contains("dolphin") })
    }

    @MainActor
    func testCodexKeybindingFileWatcherRefreshesCachedActionShortcut() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voke-keybindings-\(UUID().uuidString)", isDirectory: true)
        let keymap = directory.appendingPathComponent("keybindings.json")
        let service = ApplicationShortcutSyncService(candidateURLs: [keymap])
        defer {
            service.stop()
            try? FileManager.default.removeItem(at: directory)
        }

        service.start()
        let data = try JSONEncoder().encode([
            CodexKeybindingEntry(command: "composer.cycleReasoningEffort", key: "Cmd+Shift+R")
        ])
        try data.write(to: keymap, options: .atomic)
        try await Task.sleep(for: .milliseconds(350))

        let action = try XCTUnwrap(ApplicationActionRegistry.preset(id: "chatgpt.cycleReasoning"))
        let resolution = service.resolution(for: action)
        XCTAssertEqual(resolution.source, .codexConfiguration)
        XCTAssertEqual(resolution.shortcut?.displayName, "⇧⌘R")
    }

    func testExistingProfileCanBeBoundAndUnboundFromCurrentApplication() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        let defaultProfile = try! XCTUnwrap(store.activeProfileID)
        store.addProfile()
        let secondProfile = try! XCTUnwrap(store.activeProfileID)
        store.update(.b) { $0.actionKind = .screenshot }
        store.setActiveProfile(defaultProfile)

        store.updateApplicationContext(bundleIdentifier: "com.apple.Keynote", displayName: "Keynote")
        store.useProfileForCurrentApplication(secondProfile)
        XCTAssertTrue(store.currentApplicationUsesDedicatedProfile)
        XCTAssertEqual(store.mapping(for: .b).actionKind, .screenshot)

        store.stopUsingDedicatedProfileForCurrentApplication()
        XCTAssertFalse(store.currentApplicationUsesDedicatedProfile)
        XCTAssertEqual(store.activeProfileID, defaultProfile)
    }

    func testDisablingContextualProfilesUsesFallbackWithoutDeletingBinding() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        store.update(.a) { $0.actionKind = .screenshot }
        store.updateApplicationContext(bundleIdentifier: "com.openai.codex", displayName: "ChatGPT")
        store.addProfile()
        store.update(.a) { $0.actionKind = .none }

        store.contextualProfilesEnabled = false
        XCTAssertFalse(store.currentApplicationUsesDedicatedProfile)
        XCTAssertEqual(store.mapping(for: .a).actionKind, .screenshot)

        store.contextualProfilesEnabled = true
        XCTAssertTrue(store.currentApplicationUsesDedicatedProfile)
        XCTAssertEqual(store.mapping(for: .a).actionKind, .none)
    }

    func testApplicationBindingSurvivesStoreReload() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        store.updateApplicationContext(bundleIdentifier: "com.openai.codex", displayName: "ChatGPT")
        store.addProfile()
        store.update(.a) { $0.actionKind = .screenshot }

        let reloaded = MappingStore(defaults: defaults)
        reloaded.updateApplicationContext(bundleIdentifier: "com.openai.codex", displayName: "ChatGPT")

        XCTAssertTrue(reloaded.currentApplicationUsesDedicatedProfile)
        XCTAssertEqual(reloaded.mapping(for: .a).actionKind, .screenshot)
    }

    func testApplicationProfilesRemainIndependentPerDevice() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        store.registerDevice(gamepad(id: "gamepad.two"))
        store.selectDevice("gamepad.one")
        store.updateApplicationContext(bundleIdentifier: "com.apple.Keynote", displayName: "Keynote")
        store.addProfile()
        store.update(.a) { $0.actionKind = .screenshot }

        store.selectDevice("gamepad.two")
        XCTAssertFalse(store.currentApplicationUsesDedicatedProfile)
        XCTAssertEqual(store.mapping(for: .a).actionKind, .none)

        store.selectDevice("gamepad.one")
        XCTAssertTrue(store.currentApplicationUsesDedicatedProfile)
        XCTAssertEqual(store.mapping(for: .a).actionKind, .screenshot)
    }

    func testDeletingDedicatedProfileFallsBackToGenericProfile() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        store.update(.a) { $0.actionKind = .screenshot }
        store.updateApplicationContext(bundleIdentifier: "com.apple.Safari", displayName: "Safari")
        store.addProfile()
        let dedicatedProfile = try! XCTUnwrap(store.activeProfileID)
        store.update(.a) { $0.actionKind = .none }

        store.deleteProfile(dedicatedProfile)

        XCTAssertFalse(store.currentApplicationUsesDedicatedProfile)
        XCTAssertEqual(store.mapping(for: .a).actionKind, .screenshot)
    }

    func testLegacyV2ProfileWithoutApplicationBindingsStillImports() throws {
        let profileID = UUID()
        let json = """
        {
          "formatVersion": 2,
          "exportedAt": "1970-01-01T00:00:00Z",
          "devices": [{
            "deviceID": "legacy.device",
            "deviceName": "Legacy Controller",
            "deviceKind": "gameController",
            "activeProfileID": "\(profileID.uuidString)",
            "profiles": [{
              "id": "\(profileID.uuidString)",
              "name": "默认方案",
              "mappings": []
            }]
          }]
        }
        """
        let store = MappingStore(defaults: defaults)

        try store.importData(try XCTUnwrap(json.data(using: .utf8)))

        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertNil(store.profiles[0].applicationBundleIdentifiers)
        XCTAssertEqual(store.activeProfileID, profileID)
    }

    func testImportRejectsDuplicateApplicationBindings() throws {
        let bundleIdentifier = "com.openai.codex"
        let first = MappingProfile(
            id: UUID(),
            name: "First",
            mappings: [],
            applicationBundleIdentifiers: [bundleIdentifier]
        )
        let second = MappingProfile(
            id: UUID(),
            name: "Second",
            mappings: [],
            applicationBundleIdentifiers: [bundleIdentifier]
        )
        let device = DeviceMappingConfiguration(
            deviceID: "duplicate.bindings",
            deviceName: "Duplicate Bindings",
            deviceKind: .gameController,
            activeProfileID: first.id,
            profiles: [first, second]
        )
        let backup = MappingBackup(formatVersion: 2, exportedAt: Date(), devices: [device])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let store = MappingStore(defaults: defaults)

        XCTAssertThrowsError(try store.importData(encoder.encode(backup))) { error in
            guard case MappingBackupError.duplicateApplicationBinding(bundleIdentifier) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testImportRejectsDuplicateDevices() throws {
        let profile = MappingProfile(id: UUID(), name: "默认方案", mappings: [])
        let device = DeviceMappingConfiguration(
            deviceID: "duplicate",
            deviceName: "Duplicate",
            deviceKind: .gameController,
            activeProfileID: profile.id,
            profiles: [profile]
        )
        let backup = MappingBackup(formatVersion: 2, exportedAt: Date(), devices: [device, device])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let store = MappingStore(defaults: defaults)
        XCTAssertThrowsError(try store.importData(encoder.encode(backup))) { error in
            guard case MappingBackupError.duplicateDevice("duplicate") = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    private func gamepad(id: String) -> InputDeviceDescriptor {
        InputDeviceDescriptor(
            id: id,
            name: "Test Controller",
            kind: .gameController,
            connected: true,
            controls: ControllerControl.gamepadControls
        )
    }
}
