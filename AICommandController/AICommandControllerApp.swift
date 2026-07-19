import SwiftUI

@main
struct AICommandControllerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(model)
                .frame(minWidth: 1080, minHeight: 680)
                .onAppear { model.start() }
                .onDisappear { model.stop() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1220, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("检查辅助功能权限") {
                    model.keyboard.requestAccessibilityPermission()
                }
            }
        }
    }
}

