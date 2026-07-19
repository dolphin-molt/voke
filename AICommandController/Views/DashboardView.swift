import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    private let panel = Color(red: 0.075, green: 0.082, blue: 0.09)
    private let line = Color.white.opacity(0.10)
    private let cyan = Color(red: 0.25, green: 0.91, blue: 0.82)
    private let amber = Color(red: 1.0, green: 0.67, blue: 0.22)

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.039, blue: 0.044).ignoresSafeArea()
            GridTexture().opacity(0.34).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Rectangle().fill(line).frame(height: 1)
                HStack(spacing: 0) {
                    deviceRail
                    Rectangle().fill(line).frame(width: 1)
                    controllerDeck
                    Rectangle().fill(line).frame(width: 1)
                    actionRail
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI COMMAND")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(2.4)
                Text("HANDS-FREE CONTROL DECK / 01")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1.7)
            }
            Spacer()
            statusPill(label: model.activeApplication.uppercased(), active: true, tint: cyan)
            statusPill(label: model.controllerConnected ? "CONTROLLER ONLINE" : "NO CONTROLLER", active: model.controllerConnected, tint: cyan)
            Toggle(isOn: $model.mappingEnabled) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("OUTPUT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(model.mappingEnabled ? "ARMED" : "SAFE")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(model.mappingEnabled ? amber : .white)
                }
            }
            .toggleStyle(.switch)
            .tint(amber)
        }
        .padding(.horizontal, 26)
        .frame(height: 82)
        .background(.black.opacity(0.18))
    }

    private var deviceRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionLabel("SIGNAL CHAIN", index: "A")
            DeviceCard(
                icon: "gamecontroller.fill",
                eyebrow: "CONTROL",
                title: model.controllerName,
                detail: model.controllerConnected ? "Bluetooth · 实时监听" : "按任意手柄键唤醒",
                online: model.controllerConnected,
                tint: cyan
            )
            DeviceCard(
                icon: "mic.fill",
                eyebrow: "VOICE INPUT",
                title: model.defaultInput?.name ?? "未发现默认麦克风",
                detail: model.defaultInput == nil ? "检查音频连接" : "系统默认输入",
                online: model.defaultInput != nil,
                tint: amber
            )
            DeviceCard(
                icon: "headphones",
                eyebrow: "MONITOR",
                title: model.defaultOutput?.name ?? "未发现默认输出",
                detail: model.defaultOutput == nil ? "检查耳机连接" : "系统默认输出",
                online: model.defaultOutput != nil,
                tint: Color(red: 0.46, green: 0.65, blue: 1)
            )

            Spacer()
            VStack(alignment: .leading, spacing: 9) {
                Text("AUDIO DEVICES")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                ForEach(model.audioDevices.prefix(4)) { device in
                    HStack(spacing: 7) {
                        Circle().fill((device.isDefaultInput || device.isDefaultOutput) ? cyan : Color.white.opacity(0.2)).frame(width: 5, height: 5)
                        Text(device.name)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                    }
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(panel)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(line))
        }
        .padding(20)
        .frame(width: 292)
    }

    private var controllerDeck: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionLabel("LIVE INPUT", index: "B")
                Spacer()
                Text(model.pressedButtons.isEmpty ? "STANDBY" : model.pressedButtons.sorted().joined(separator: "  "))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(model.pressedButtons.isEmpty ? .secondary : cyan)
            }
            .padding(22)

            Spacer(minLength: 8)
            ControllerVisual(
                pressed: model.pressedButtons,
                leftStick: model.leftStick,
                rightStick: model.rightStick,
                leftTrigger: model.leftTrigger,
                rightTrigger: model.rightTrigger
            )
            .frame(maxWidth: .infinity)
            Spacer()

            HStack(spacing: 8) {
                ForEach(["ZL", "ZR", "A", "B", "X", "Y"], id: \.self) { key in
                    Text(key)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(model.pressedButtons.contains(key) ? Color.black : Color.white.opacity(0.55))
                        .frame(width: 36, height: 25)
                        .background(model.pressedButtons.contains(key) ? cyan : panel)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(line))
                }
                Spacer()
                Text("PRESS ANY CONTROL")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionRail: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("ACTIVE ROUTE", index: "C")

            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("01")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(amber)
                    Spacer()
                    Text("GLOBAL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text("HOLD TO TALK")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .tracking(0.7)
                HStack(alignment: .center, spacing: 12) {
                    Text("ZR")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(model.pressedButtons.contains("ZR") ? .black : amber)
                        .frame(width: 54, height: 42)
                        .background(model.pressedButtons.contains("ZR") ? amber : amber.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(amber.opacity(0.7)))
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    Text("⌘")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Spacer()
                }
                Text("按住右扳机启动闪电说，松开结束语音输入。")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .padding(16)
            .background(panel)
            .overlay(alignment: .leading) { Rectangle().fill(amber).frame(width: 2) }
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(line))

            if !model.keyboard.isAccessibilityTrusted {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 9) {
                        Image(systemName: "lock.shield.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("需要辅助功能权限")
                                .font(.system(size: 11, weight: .bold))
                            Text("系统不允许应用自动替你打开授权开关")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        model.openAccessibilitySettings()
                    } label: {
                        HStack {
                            Text("打开系统设置")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .background(amber)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(13)
                .background(amber.opacity(0.10))
                .foregroundStyle(amber)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(amber.opacity(0.45)))
            }

            sectionLabel("EVENT LOG", index: "D")
                .padding(.top, 6)
            VStack(spacing: 0) {
                ForEach(model.events.prefix(6)) { event in
                    HStack(alignment: .top, spacing: 9) {
                        Text(event.date, format: .dateTime.hour().minute().second())
                            .foregroundStyle(.secondary)
                        Text(event.message)
                            .foregroundStyle(.white.opacity(0.82))
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(line).frame(height: 1) }
                }
            }
            Spacer()
            HStack {
                Circle().fill(model.mappingEnabled ? amber : Color.white.opacity(0.22)).frame(width: 7, height: 7)
                Text(model.mappingEnabled ? "OUTPUT ARMED" : "SAFE MODE · NO KEYS SENT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(model.mappingEnabled ? amber : .secondary)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func sectionLabel(_ text: String, index: String) -> some View {
        HStack(spacing: 8) {
            Text(index)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .background(Color.white.opacity(0.8))
                .clipShape(Rectangle())
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1.2)
        }
    }

    private func statusPill(label: String, active: Bool, tint: Color) -> some View {
        HStack(spacing: 7) {
            Circle().fill(active ? tint : Color.white.opacity(0.2)).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(panel)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(line))
    }
}

private struct DeviceCard: View {
    let icon: String
    let eyebrow: String
    let title: String
    let detail: String
    let online: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(online ? tint : .secondary)
                .frame(width: 38, height: 38)
                .background(tint.opacity(online ? 0.10 : 0.03))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(red: 0.075, green: 0.082, blue: 0.09))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.10)))
    }
}

private struct GridTexture: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 28
            for x in stride(from: 0, through: size.width, by: spacing) {
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: spacing) {
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.white.opacity(0.028)), lineWidth: 0.5)
        }
    }
}
