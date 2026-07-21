import AppKit
import SwiftUI

final class VokeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct VokeApp: App {
    @NSApplicationDelegateAdaptor(VokeAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 560)
                .onAppear { model.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1309, height: 889)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("检查辅助功能权限") {
                    model.keyboard.requestAccessibilityPermission()
                }
            }
        }
    }
}
