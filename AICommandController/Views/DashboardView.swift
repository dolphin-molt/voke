import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsActivity = false

    private let background = Color(red: 0.055, green: 0.059, blue: 0.067)
    private let surface = Color(red: 0.085, green: 0.091, blue: 0.102)
    private let elevated = Color(red: 0.108, green: 0.115, blue: 0.128)
    private let border = Color.white.opacity(0.085)
    private let accent = Color(red: 0.58, green: 0.94, blue: 0.56)
    private let warning = Color(red: 1.0, green: 0.70, blue: 0.28)

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 980

            ZStack {
                background.ignoresSafeArea()
                VStack(spacing: 0) {
                    header(compact: geometry.size.width < 760)
                    Divider().overlay(border)

                    if !model.keyboard.isAccessibilityTrusted {
                        permissionBanner
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                    }

                    Group {
                        if wide {
                            HStack(spacing: 16) {
                                controllerPanel
                                    .frame(minWidth: 430, maxWidth: .infinity, maxHeight: .infinity)
                                mappingPanel
                                    .frame(width: min(430, max(360, geometry.size.width * 0.38)))
                                    .frame(maxHeight: .infinity)
                            }
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 14) {
                                    controllerPanel
                                        .frame(height: min(420, max(300, geometry.size.height * 0.48)))
                                    mappingPanel
                                }
                            }
                        }
                    }
                    .padding(18)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black.opacity(0.78))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("Controller Studio")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                if !compact {
                    Text("把手柄变成你的快捷键")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if !compact {
                statusItem(
                    icon: "gamecontroller",
                    title: model.controllerConnected ? model.controllerName : "等待手柄",
                    tint: model.controllerConnected ? accent : .secondary
                )
                statusItem(icon: "arrow.up.forward.app", title: model.activeApplication, tint: .secondary)
            }

            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(model.mappingEnabled ? "映射已开启" : "映射已暂停")
                        .font(.system(size: 12, weight: .semibold))
                    if !compact {
                        Text(model.mappingEnabled ? "手柄操作会立即执行" : "不会发送按键或命令")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("", isOn: $model.mappingEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(accent)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: compact ? 64 : 72)
        .background(surface.opacity(0.72))
    }

    private var controllerPanel: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("实时手柄")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(model.controllerConnected ? "按下任意按键即可选择并配置" : "连接手柄后即可开始")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 7) {
                    Circle()
                        .fill(model.controllerConnected ? accent : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(model.controllerConnected ? "已连接" : "未连接")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(elevated)
                .clipShape(Capsule())
            }
            .padding(20)

            ControllerVisual(
                pressed: model.pressedButtons,
                leftStick: model.leftStick,
                rightStick: model.rightStick,
                leftTrigger: model.leftTrigger,
                rightTrigger: model.rightTrigger
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 4)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前按键")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(model.pressedButtons.isEmpty ? model.selectedControl.rawValue : model.pressedButtons.sorted().joined(separator: " + "))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(model.pressedButtons.isEmpty ? .primary : accent)
                }
                Spacer()
                Text(model.mappingStore.mapping(for: model.selectedControl).summary)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(20)
            .background(Color.black.opacity(0.12))
        }
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(border))
    }

    private var mappingPanel: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                MappingStudio(
                    store: model.mappingStore,
                    selectedControl: $model.selectedControl,
                    accessibilityTrusted: model.keyboard.isAccessibilityTrusted,
                    openAccessibilitySettings: model.openAccessibilitySettings
                )
                .padding(20)
            }

            Divider().overlay(border)

            DisclosureGroup(isExpanded: $showsActivity) {
                VStack(spacing: 0) {
                    ForEach(model.events.prefix(5)) { event in
                        HStack(alignment: .top, spacing: 10) {
                            Text(event.date, format: .dateTime.hour().minute().second())
                                .foregroundStyle(.tertiary)
                            Text(event.message)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .padding(.top, 8)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                    Text("活动记录")
                    Spacer()
                    if let latest = model.events.first {
                        Text(latest.message)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 10, weight: .semibold))
            }
            .tint(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
        }
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(border))
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("快捷键输出尚未授权")
                    .font(.system(size: 12, weight: .semibold))
                Text("终端命令不受影响；快捷键需要在系统设置中允许辅助功能。")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("打开系统设置") { model.openAccessibilitySettings() }
                .buttonStyle(.borderedProminent)
                .tint(warning)
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .background(warning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(warning.opacity(0.25)))
    }

    private func statusItem(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(title)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(maxWidth: 160, minHeight: 30)
        .background(elevated)
        .clipShape(Capsule())
    }
}
