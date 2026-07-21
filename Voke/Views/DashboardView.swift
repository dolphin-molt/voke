import AppKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsSettings = false
    @AppStorage("appearanceTheme") private var themeRawValue = AppTheme.daylight.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRawValue) ?? .daylight }
    private var background: Color { theme.palette.background }
    private var surface: Color { theme.palette.surface }
    private var elevated: Color { theme.palette.elevated }
    private var border: Color { theme.palette.border }
    private var accent: Color { theme.palette.accent }
    private var warning: Color { theme.palette.warning }
    private var ink: Color { theme.palette.ink }
    private var liveGreen: Color { Color(red: 0.263, green: 0.557, blue: 0.365) }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 980

            ZStack {
                background.ignoresSafeArea()
                notebookGrid
                ambientBackground

                VStack(spacing: 12) {
                    header
                    deviceDock

                    Group {
                        if wide {
                            HStack(spacing: 14) {
                                deviceSurface
                                    .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
                                mappingPanel
                                    .frame(width: max(300, geometry.size.width * 0.266))
                                    .frame(maxHeight: .infinity)
                            }
                        } else {
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: 14) {
                                    deviceSurface.frame(height: 520)
                                    mappingPanel.frame(height: 680)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                }
                .padding(.top, 18)
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .sheet(isPresented: $showsSettings) {
            SettingsPanel().environmentObject(model)
        }
    }

    private var ambientBackground: some View {
        GeometryReader { geometry in
            Circle()
                .fill(accent.opacity(0.08))
                .frame(width: geometry.size.width * 0.55)
                .blur(radius: 90)
                .offset(x: -geometry.size.width * 0.16, y: -geometry.size.height * 0.28)
        }
        .allowsHitTesting(false)
    }

    private var notebookGrid: some View {
        Canvas { context, size in
            let vertical = ink.opacity(theme.palette.gridVerticalOpacity)
            let horizontal = ink.opacity(theme.palette.gridHorizontalOpacity)
            for x in stride(from: 0.0, through: size.width, by: 24) {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(vertical), lineWidth: 0.6)
            }
            for y in stride(from: 0.0, through: size.height, by: 24) {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(horizontal), lineWidth: 0.6)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .shadow(color: Color.black.opacity(0.24), radius: 5, x: 0, y: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("VOKE")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .tracking(3.4)
                Text("INPUT, YOUR WAY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.25)
                    .foregroundStyle(ink.opacity(0.52))
            }

            Spacer()

            HStack(spacing: 10) {
                Circle()
                    .fill(model.mappingEnabled ? liveGreen : Color.secondary.opacity(0.45))
                    .frame(width: 8, height: 8)
                    .shadow(color: liveGreen.opacity(0.18), radius: 0, x: 0, y: 0)
                Text(model.mappingEnabled ? "映射运行中" : "映射已暂停")
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .foregroundStyle(model.mappingEnabled ? Color(red: 0.286, green: 0.376, blue: 0.310) : .secondary)
            .background(surface.opacity(0.62))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(border))
            .onTapGesture { model.mappingEnabled.toggle() }

            Button { showsSettings = true } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(surface.opacity(0.62))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(border))
            }
            .buttonStyle(.plain)
            .help("设置与诊断")
        }
        .padding(.horizontal, 22)
        .frame(height: 58)
    }

    private var deviceDock: some View {
        HStack(spacing: 9) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if model.devices.isEmpty {
                        Label("等待连接", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(elevated)
                            .clipShape(Capsule())
                    } else {
                        ForEach(model.devices) { device in
                            let selected = device.id == model.selectedDeviceID
                            Button { model.selectDevice(device.id) } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: device.kind.icon)
                                    Text(device.kind == .gameController ? device.name : "\(device.name) · \(device.kind.title)")
                                        .lineLimit(1)
                                    Circle()
                                        .fill(device.connected ? (selected ? Color.black.opacity(0.58) : accent) : Color.secondary)
                                        .frame(width: 6, height: 6)
                                }
                                .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(selected ? ink : .primary)
                                .padding(.horizontal, 14)
                                .frame(height: 34)
                                .background(selected ? accent : elevated)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(selected ? ink : border, lineWidth: selected ? 1.2 : 1))
                                .shadow(color: selected ? ink.opacity(0.12) : .clear, radius: 0, x: 3, y: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

        }
        .padding(.horizontal, 22)
        .frame(height: 42)
    }

    private var deviceSurface: some View {
        Group {
            if model.selectedDevice?.kind == .hidMouse {
                MouseMappingSurface(
                    controls: model.selectedDeviceControls,
                    pressed: model.pressedButtons,
                    selectedControl: $model.selectedControl,
                    mapping: model.mappingStore.mapping,
                    controlLabel: model.controlLabel,
                    deviceName: model.selectedDevice?.name ?? "鼠标",
                    deviceDetail: hidDeviceDetailText,
                    openInputMonitoringSettings: model.requestInputMonitoring
                )
            } else if model.selectedDevice?.kind.isHID == true {
                KeyboardMappingSurface(
                    controls: model.selectedDeviceControls,
                    pressed: model.pressedButtons,
                    selectedControl: $model.selectedControl,
                    mapping: model.mappingStore.mapping,
                    controlLabel: model.controlLabel,
                    deviceName: model.selectedDevice?.name ?? "键盘",
                    deviceDetail: hidDeviceDetailText,
                    openInputMonitoringSettings: model.requestInputMonitoring
                )
            } else {
                ControllerMappingSurface(
                    controls: model.selectedDeviceControls,
                    pressed: model.pressedButtons,
                    selectedControl: $model.selectedControl,
                    mapping: model.mappingStore.mapping,
                    controlLabel: model.controlLabel
                )
            }
        }
    }

    private var keyboardSurface: some View {
        VStack(alignment: .leading, spacing: 18) {
            hidDeviceIdentity

            if model.selectedDeviceControls.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: model.inputMonitoringGranted ? "hand.tap.fill" : "lock.shield.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(model.inputMonitoringGranted ? "按一下设备上的按键" : "需要输入监控权限")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    Text(model.inputMonitoringGranted ? "Voke 会学习真实按键，不再预先显示 K1–K12。" : "在系统设置中打开 Voke；若未列出，请点“+”添加 /Applications/Voke.app。")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if !model.inputMonitoringGranted {
                        Button("打开输入监控设置", action: model.requestInputMonitoring)
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                        ForEach(model.selectedDeviceControls) { control in
                            let selected = model.selectedControl == control
                            let pressed = model.pressedButtons.contains(control.rawValue)
                            Button { model.selectedControl = control } label: {
                                VStack(spacing: 6) {
                                    Text(model.controlLabel(control))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Text(model.mappingStore.mapping(for: control).summary)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(selected || pressed ? Color.black.opacity(0.62) : .secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 68)
                                .foregroundStyle(selected || pressed ? Color.black.opacity(0.78) : .primary)
                                .background(selected || pressed ? accent : surface)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected || pressed ? accent : border))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(border))
    }

    private var mappingPanel: some View {
        Group {
            if model.selectedDevice?.kind.isHID == true && model.selectedDeviceControls.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wave.3.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(accent)
                    Text(model.inputMonitoringGranted ? "等待学习第一个按键" : "尚未获得输入监控权限")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                    Text(model.inputMonitoringGranted ? "按下设备按键后，这里会自动出现映射设置。" : "在输入监控列表中打开 Voke；若未列出，请点“+”添加它，然后重新打开 Voke。")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if !model.inputMonitoringGranted {
                        Button(action: model.requestInputMonitoring) {
                            Label("打开输入监控设置", systemImage: "arrow.up.forward.app.fill")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ink)
                        .background(accent)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(ink.opacity(0.72), lineWidth: 1.2))
                        .shadow(color: ink.opacity(0.12), radius: 0, x: 3, y: 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MappingStudio(
                    store: model.mappingStore,
                    selectedControl: $model.selectedControl,
                    accessibilityTrusted: model.keyboard.isAccessibilityTrusted,
                    openAccessibilitySettings: model.openAccessibilitySettings,
                    controls: model.selectedDeviceControls,
                    controlLabel: model.controlLabel
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(surface.opacity(0.67))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                bottomLeadingRadius: 30,
                bottomTrailingRadius: 34,
                topTrailingRadius: 38,
                style: .continuous
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                bottomLeadingRadius: 30,
                bottomTrailingRadius: 34,
                topTrailingRadius: 38,
                style: .continuous
            )
            .stroke(border)
        )
        .shadow(color: ink.opacity(theme.palette.panelShadowOpacity), radius: 35, y: 18)
    }

    private var hidDeviceIdentity: some View {
        HStack(spacing: 10) {
            Image(systemName: model.selectedDevice?.kind.icon ?? "questionmark")
                .foregroundStyle(ink)
                .frame(width: 30, height: 30)
                .background(accent)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(model.selectedDevice?.name ?? "外接设备")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                Text(hidDeviceDetailText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(elevated.opacity(0.76))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(border))
    }

    private var hidDeviceDetailText: String {
        guard let device = model.selectedDevice else { return "等待设备信息" }
        let transport = device.transport ?? "HID"
        let identifier = if let vendorID = device.vendorID, let productID = device.productID {
            String(format: "%04X:%04X", vendorID, productID)
        } else {
            "未知型号"
        }
        let buttons = device.declaredButtonCount > 0 ? " · \(device.declaredButtonCount) 个鼠标按键" : ""
        return "\(device.kind.title) · \(transport) · \(identifier)\(buttons)"
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill").foregroundStyle(warning)
            Text("快捷键输出需要辅助功能权限")
                .font(.system(size: 10, weight: .semibold))
            Spacer()
            Button("打开系统设置", action: model.openAccessibilitySettings)
                .buttonStyle(.link)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(warning.opacity(0.09))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(warning.opacity(0.22)))
    }
}
