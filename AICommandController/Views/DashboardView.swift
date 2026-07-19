import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsActivity = false
    @AppStorage("appearanceTheme") private var themeRawValue = AppTheme.daylight.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRawValue) ?? .daylight }
    private var background: Color { theme.palette.background }
    private var surface: Color { theme.palette.surface }
    private var elevated: Color { theme.palette.elevated }
    private var border: Color { theme.palette.border }
    private var accent: Color { theme.palette.accent }
    private var warning: Color { theme.palette.warning }

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
        .preferredColorScheme(theme.colorScheme)
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

            Menu {
                ForEach(AppTheme.allCases) { option in
                    Button {
                        themeRawValue = option.rawValue
                    } label: {
                        if option == theme {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                Image(systemName: "paintpalette")
                    .frame(width: 30, height: 30)
            }
            .menuStyle(.borderlessButton)

            if !compact {
                statusItem(
                    icon: model.selectedDevice?.kind.icon ?? "gamecontroller",
                    title: model.selectedDevice?.name ?? "等待设备",
                    tint: model.selectedDevice?.connected == true ? accent : .secondary
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
                    Text("实时设备")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(model.selectedDevice?.connected == true ? "按下任意按键即可选择并配置" : "连接设备后即可开始")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 7) {
                    Circle()
                        .fill(model.selectedDevice?.connected == true ? accent : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(model.selectedDevice?.connected == true ? "已连接" : "未连接")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(elevated)
                .clipShape(Capsule())
            }
            .padding(20)

            Group {
                if model.selectedDevice?.kind == .hidKeyboard {
                    keyboardVisual
                } else {
                    ControllerVisual(
                        pressed: model.pressedButtons,
                        leftStick: model.leftStick,
                        rightStick: model.rightStick,
                        leftTrigger: model.leftTrigger,
                        rightTrigger: model.rightTrigger
                    )
                }
            }
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
                VStack(spacing: 0) {
                    deviceProfileBar
                        .padding(.horizontal, 20)
                        .padding(.top, 18)

                    MappingStudio(
                        store: model.mappingStore,
                        selectedControl: $model.selectedControl,
                        accessibilityTrusted: model.keyboard.isAccessibilityTrusted,
                        openAccessibilitySettings: model.openAccessibilitySettings,
                        controls: model.selectedDeviceControls,
                        controlLabel: model.controlLabel
                    )
                    .padding(20)
                }
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

            Divider().overlay(border)

            HStack(spacing: 8) {
                toolButton("导出配置", icon: "square.and.arrow.up", action: model.exportMappings)
                toolButton("导入配置", icon: "square.and.arrow.down", action: model.importMappings)
                toolButton("复制诊断", icon: "stethoscope", action: model.copyDiagnostics)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(border))
    }

    private var keyboardVisual: some View {
        VStack(spacing: 18) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(accent)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 12)], spacing: 12) {
                ForEach(model.selectedDeviceControls) { control in
                    let pressed = model.pressedButtons.contains(control.rawValue)
                    VStack(spacing: 5) {
                        Text(model.controlLabel(control))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Text(model.mappingStore.mapping(for: control).summary)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(pressed ? accent : elevated)
                    .foregroundStyle(pressed ? Color.black.opacity(0.78) : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(pressed ? accent : border))
                }
            }
            Text("首次按下会学习为 K1–K12，并按设备记住。监听模式不会拦截原按键。")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(24)
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

    private var deviceProfileBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: model.selectedDevice?.kind.icon ?? "gamecontroller.fill")
                    .foregroundStyle(accent)
                Picker("设备", selection: Binding(
                    get: { model.selectedDeviceID ?? "" },
                    set: model.selectDevice
                )) {
                    ForEach(model.devices) { device in
                        Text("\(device.name)\(device.connected ? "" : " · 未连接")")
                            .tag(device.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Spacer()
                Text(model.selectedDevice?.kind.title ?? "设备")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField("方案名称", text: Binding(
                    get: { model.mappingStore.activeProfileName },
                    set: model.mappingStore.renameActiveProfile
                ))
                .textFieldStyle(.roundedBorder)

                Menu {
                    ForEach(model.mappingStore.profiles) { profile in
                        Button(profile.name) { model.mappingStore.setActiveProfile(profile.id) }
                    }
                } label: {
                    Image(systemName: "rectangle.stack")
                }
                .menuStyle(.borderlessButton)

                Button { model.mappingStore.addProfile() } label: {
                    Image(systemName: "plus")
                }
                .help("复制当前方案")

                Button { model.mappingStore.deleteActiveProfile() } label: {
                    Image(systemName: "trash")
                }
                .disabled(model.mappingStore.profiles.count <= 1)
                .help("删除当前方案")
            }

            if model.selectedDevice?.kind == .hidKeyboard, !model.inputMonitoringGranted {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard.badge.ellipsis")
                    Text("小键盘输入需要“输入监控”权限")
                    Spacer()
                    Button("请求权限") { model.requestInputMonitoring() }
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(warning)
            }
        }
        .padding(12)
        .background(elevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func toolButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
}
