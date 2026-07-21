import Foundation
import XCTest
@testable import Voke

final class DiagnosticLogStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VokeDiagnosticLogStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }

    func testPersistentLogSurvivesStoreRecreation() {
        DiagnosticLogStore(directoryURL: directoryURL).record("手柄已连接")

        let reopened = DiagnosticLogStore(directoryURL: directoryURL)
        let exported = reopened.exportText(diagnosticReport: "diagnostic")

        XCTAssertTrue(exported.contains("diagnostic"))
        XCTAssertTrue(exported.contains("手柄已连接"))
    }

    func testTerminalCommandsAndOutputAreRedacted() {
        let store = DiagnosticLogStore(directoryURL: directoryURL)
        store.record("A → $ echo private-token")
        store.record("命令退出 0 · private-output")

        let exported = store.exportText(diagnosticReport: "diagnostic")
        XCTAssertFalse(exported.contains("private-token"))
        XCTAssertFalse(exported.contains("private-output"))
        XCTAssertTrue(exported.contains("terminal command invoked [redacted]"))
        XCTAssertTrue(exported.contains("terminal command completed [output redacted]"))
    }

    func testLogRotatesWhenSizeLimitIsReached() {
        let store = DiagnosticLogStore(directoryURL: directoryURL, maxBytes: 1, retainedFileCount: 2)
        store.record("first")
        store.record("second")

        XCTAssertTrue(FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("voke.log.1").path))
        XCTAssertTrue(store.exportText(diagnosticReport: "diagnostic").contains("first"))
        XCTAssertTrue(store.exportText(diagnosticReport: "diagnostic").contains("second"))
    }
}
