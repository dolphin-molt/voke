import SwiftUI

struct SettingsPanel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearanceTheme") private var themeRawValue = AppTheme.daylight.rawValue

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Voke 设置")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("权限、外观与故障排查")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("外观", icon: "paintpalette.fill") {
                        Picker("主题", selection: $themeRawValue) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.title).tag(theme.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    section("系统权限", icon: "lock.shield.fill") {
                        settingRow(
                            title: "辅助功能",
                            detail: model.keyboard.isAccessibilityTrusted ? "已授权快捷键、滚动和截图输出" : "尚未授权",
                            good: model.keyboard.isAccessibilityTrusted,
                            button: "打开设置",
                            action: model.openAccessibilitySettings
                        )
                        settingRow(
                            title: "输入监控",
                            detail: model.inputMonitoringGranted ? "已允许识别外接键盘和鼠标按键" : "打开列表中的 Voke；未列出时点“+”添加",
                            good: model.inputMonitoringGranted,
                            button: "打开设置",
                            action: model.requestInputMonitoring
                        )
                    }

                    section("自动运行", icon: "power.circle.fill") {
                        Toggle(isOn: $model.launchMappingAutomatically) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("启动后自动运行映射")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("重新打开 Voke 后，无需再次手动开启映射")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        Divider()

                        Toggle(
                            isOn: Binding(
                                get: { model.launchAtLoginEnabled },
                                set: model.setLaunchAtLogin
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("登录 Mac 时自动启动 Voke")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(model.launchAtLoginStatus)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        Label("关闭主窗口不会退出 Voke，手柄映射会继续在后台运行。", systemImage: "menubar.rectangle")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    section("配置与诊断", icon: "wrench.and.screwdriver.fill") {
                        HStack(spacing: 10) {
                            actionButton("导出配置", icon: "square.and.arrow.up", action: model.exportMappings)
                            actionButton("导入配置", icon: "square.and.arrow.down", action: model.importMappings)
                            actionButton("导出日志", icon: "doc.zipper", action: model.exportDiagnostics)
                        }
                    }

                    section("活动记录", icon: "waveform.path.ecg") {
                        LazyVStack(spacing: 0) {
                            if model.events.isEmpty {
                                Text("暂时没有活动")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 70)
                            } else {
                                ForEach(model.events.prefix(30)) { event in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(event.date, format: .dateTime.hour().minute().second())
                                            .foregroundStyle(.tertiary)
                                        Text(event.message)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .padding(.vertical, 7)
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 620, height: 680)
    }

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            content()
                .padding(15)
                .background(Color.primary.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func settingRow(title: String, detail: String, good: Bool, button: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(good ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(button, action: action)
        }
        .padding(.vertical, 4)
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.bordered)
    }
}
