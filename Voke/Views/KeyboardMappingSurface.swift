import SwiftUI

struct KeyboardMappingSurface: View {
    let controls: [ControllerControl]
    let pressed: Set<String>
    @Binding var selectedControl: ControllerControl
    let mapping: (ControllerControl) -> ButtonMapping
    let controlLabel: (ControllerControl) -> String
    let deviceName: String
    let deviceDetail: String
    let openInputMonitoringSettings: () -> Void

    @State private var hoveredControl: ControllerControl?
    @AppStorage("appearanceTheme") private var themeRawValue = AppTheme.daylight.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRawValue) ?? .daylight }
    private var accent: Color { theme.palette.accent }
    private var warning: Color { theme.palette.warning }
    private var surface: Color { theme.palette.surface }
    private var elevated: Color { theme.palette.elevated }
    private var border: Color { theme.palette.border }
    private var ink: Color { theme.palette.ink }
    private var liveGreen: Color { Color(red: 0.263, green: 0.557, blue: 0.365) }

    private var keyboardControls: [ControllerControl] {
        controls.filter {
            guard case let .hid(usagePage, _) = $0 else { return false }
            return usagePage == 7
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = KeyboardSketchLayout(size: geometry.size)
            let candidate = hoveredControl ?? selectedControl
            let focused = keyboardControls.contains(candidate) ? candidate : keyboardControls.first

            ZStack {
                paperBackground
                stageHeader

                keyboardDeck(layout: layout)
                    .frame(width: layout.deckSize.width, height: layout.deckSize.height)
                    .position(layout.deckCenter)

                if let focused {
                    focusedMappingCard(focused)
                        .frame(maxWidth: min(460, geometry.size.width - 46))
                        .position(layout.mappingCardPoint)
                } else {
                    inactiveMappingCard
                        .frame(maxWidth: min(460, geometry.size.width - 46))
                        .position(layout.mappingCardPoint)
                }
            }
        }
        .clipShape(stageShape)
        .overlay(stageShape.stroke(border))
        .shadow(color: ink.opacity(theme.palette.panelShadowOpacity), radius: 35, y: 18)
    }

    private var stageShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 40,
            bottomLeadingRadius: 34,
            bottomTrailingRadius: 42,
            topTrailingRadius: 36,
            style: .continuous
        )
    }

    private var paperBackground: some View {
        ZStack {
            surface.opacity(theme.palette.stageOpacity)
            RadialGradient(colors: [accent.opacity(0.07), .clear], center: .topLeading, startRadius: 20, endRadius: 430)
        }
    }

    private var stageHeader: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("KEYBOARD MAP · HAND DRAWN")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.7)
                        .foregroundStyle(.secondary)
                    Text(deviceName)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                    Text(deviceDetail)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(liveGreen).frame(width: 8, height: 8)
                    Text(pressed.isEmpty ? "等待键盘" : "LIVE INPUT")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.208, green: 0.416, blue: 0.275))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(accent.opacity(0.23))
                .clipShape(Capsule())
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func keyboardDeck(layout: KeyboardSketchLayout) -> some View {
        ZStack {
            KeyboardDeckShape()
                .fill(theme.palette.paper)
            KeyboardHatch(color: ink.opacity(0.13), spacing: 12 * layout.scale)
                .clipShape(KeyboardDeckShape())
            KeyboardDeckShape()
                .stroke(ink, style: StrokeStyle(lineWidth: max(2.2, 3.4 * layout.scale), lineJoin: .round))
            KeyboardDeckShape()
                .stroke(ink.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [12, 4, 5, 4]))
                .offset(x: 3, y: 3)

            VStack(spacing: layout.rowSpacing) {
                ForEach(Array(KeyboardKeySpec.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: layout.keySpacing) {
                        ForEach(row) { spec in
                            if let usage = spec.usage {
                                key(spec, control: control(usage: usage), layout: layout)
                            } else {
                                Color.clear.frame(width: layout.keyWidth(spec.units), height: layout.keyHeight)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(layout.deckPadding)
        }
        .rotationEffect(.degrees(-0.35))
        .shadow(color: .black.opacity(theme.palette.objectShadowOpacity), radius: 17, y: 11)
    }

    @ViewBuilder
    private func key(_ spec: KeyboardKeySpec, control: ControllerControl?, layout: KeyboardSketchLayout) -> some View {
        if let control {
            let selected = selectedControl == control
            let isPressed = pressed.contains(control.rawValue)
            let hovered = hoveredControl == control
            Button {
                withAnimation(.snappy(duration: 0.20)) { selectedControl = control }
            } label: {
                keyFace(spec, active: true, selected: selected, pressed: isPressed, hovered: hovered, layout: layout)
            }
            .buttonStyle(.plain)
            .onHover { value in
                withAnimation(.easeOut(duration: 0.14)) {
                    hoveredControl = value ? control : (hoveredControl == control ? nil : hoveredControl)
                }
            }
            .help("\(controlLabel(control)) · \(mapping(control).summary)")
        } else {
            keyFace(spec, active: false, selected: false, pressed: false, hovered: false, layout: layout)
                .allowsHitTesting(false)
        }
    }

    private func keyFace(
        _ spec: KeyboardKeySpec,
        active: Bool,
        selected: Bool,
        pressed: Bool,
        hovered: Bool,
        layout: KeyboardSketchLayout
    ) -> some View {
        let emphasized = selected || pressed || hovered
        let corner = max(4, 7 * layout.scale)
        let keyFill = pressed
            ? accent.opacity(0.86)
            : (hovered ? accent.opacity(0.25) : elevated.opacity(active ? 0.90 : 0.38))
        let keyStroke = emphasized ? (selected ? warning : accent) : ink.opacity(active ? 0.56 : 0.20)
        let keyShadow = emphasized ? warning.opacity(0.30) : ink.opacity(0.08)

        return ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(keyFill)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(keyStroke, lineWidth: emphasized ? 2.2 : 1)
                )

            Text(spec.label)
                .font(.system(size: max(6.5, 8.5 * layout.scale), weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(active ? ink.opacity(0.78) : ink.opacity(0.28))

            if selected {
                RoundedRectangle(cornerRadius: max(5, 8 * layout.scale), style: .continuous)
                    .stroke(warning, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [6, 5]))
                    .padding(-3)
            }
        }
            .frame(width: layout.keyWidth(spec.units), height: layout.keyHeight)
            .scaleEffect(pressed ? 0.94 : (hovered ? 1.025 : 1))
            .shadow(color: keyShadow, radius: emphasized ? 7 : 0, x: 2, y: 3)
    }

    private func focusedMappingCard(_ control: ControllerControl) -> some View {
        HStack(spacing: 12) {
            Text(controlLabel(control))
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.78))
                .frame(minWidth: 58, minHeight: 30)
                .padding(.horizontal, 8)
                .background(accent)
                .clipShape(Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text("当前映射").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                Text(mapping(control).summary)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(liveGreen)
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(surface.opacity(0.88))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(liveGreen.opacity(0.56), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .shadow(color: .black.opacity(0.11), radius: 15, y: 7)
    }

    private var inactiveMappingCard: some View {
        Button(action: openInputMonitoringSettings) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ink.opacity(0.70))
                    .frame(width: 34, height: 30)
                    .background(accent)
                    .clipShape(Capsule())
                VStack(alignment: .leading, spacing: 2) {
                    Text("打开输入监控设置").font(.system(size: 10, weight: .bold, design: .rounded))
                    Text("允许后，按下的真实键帽会自动启用")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(liveGreen)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(surface.opacity(0.90))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(liveGreen.opacity(0.56), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .shadow(color: .black.opacity(0.09), radius: 13, y: 6)
        }
        .buttonStyle(.plain)
        .help("打开系统设置 → 隐私与安全性 → 输入监控")
    }

    private func control(usage: UInt32) -> ControllerControl? {
        keyboardControls.first {
            guard case let .hid(page, value) = $0 else { return false }
            return page == 7 && value == usage
        }
    }
}

private struct KeyboardSketchLayout {
    let size: CGSize
    let scale: CGFloat
    let deckSize: CGSize
    let deckCenter: CGPoint
    let mappingCardPoint: CGPoint

    init(size: CGSize) {
        self.size = size
        let availableWidth = max(420, size.width - 64)
        let availableHeight = max(235, size.height - 190)
        scale = min(availableWidth / 720, availableHeight / 292, 1.05)
        deckSize = CGSize(width: 720 * scale, height: 292 * scale)
        deckCenter = CGPoint(x: size.width * 0.5, y: 87 + deckSize.height * 0.5)
        mappingCardPoint = CGPoint(x: size.width * 0.5, y: size.height - 47)
    }

    var keyUnit: CGFloat { 38 * scale }
    var keyHeight: CGFloat { 34 * scale }
    var keySpacing: CGFloat { 4 * scale }
    var rowSpacing: CGFloat { 6 * scale }
    var deckPadding: CGFloat { 21 * scale }

    func keyWidth(_ units: CGFloat) -> CGFloat {
        keyUnit * units + keySpacing * max(0, units - 1)
    }
}

private struct KeyboardKeySpec: Identifiable {
    let usage: UInt32?
    let label: String
    let units: CGFloat
    var id: String { usage.map(String.init) ?? "gap-\(label)-\(units)" }

    static func key(_ usage: UInt32, _ label: String, _ units: CGFloat = 1) -> Self {
        Self(usage: usage, label: label, units: units)
    }

    static func gap(_ units: CGFloat) -> Self { Self(usage: nil, label: UUID().uuidString, units: units) }

    static let rows: [[KeyboardKeySpec]] = [
        [key(41, "Esc"), gap(0.55), key(58, "F1"), key(59, "F2"), key(60, "F3"), key(61, "F4"), gap(0.25), key(62, "F5"), key(63, "F6"), key(64, "F7"), key(65, "F8"), gap(0.25), key(66, "F9"), key(67, "F10"), key(68, "F11"), key(69, "F12")],
        [key(53, "~"), key(30, "1"), key(31, "2"), key(32, "3"), key(33, "4"), key(34, "5"), key(35, "6"), key(36, "7"), key(37, "8"), key(38, "9"), key(39, "0"), key(45, "−"), key(46, "="), key(42, "Delete", 2)],
        [key(43, "Tab", 1.5), key(20, "Q"), key(26, "W"), key(8, "E"), key(21, "R"), key(23, "T"), key(28, "Y"), key(24, "U"), key(12, "I"), key(18, "O"), key(19, "P"), key(47, "["), key(48, "]"), key(49, "\\", 1.5)],
        [key(57, "Caps", 1.75), key(4, "A"), key(22, "S"), key(7, "D"), key(9, "F"), key(10, "G"), key(11, "H"), key(13, "J"), key(14, "K"), key(15, "L"), key(51, ";"), key(52, "'"), key(40, "Return", 2.25)],
        [key(225, "Shift", 2.25), key(29, "Z"), key(27, "X"), key(6, "C"), key(25, "V"), key(5, "B"), key(17, "N"), key(16, "M"), key(54, ","), key(55, "."), key(56, "/"), key(229, "Shift", 2.75)],
        [key(224, "Ctrl", 1.25), key(226, "Opt", 1.25), key(227, "Cmd", 1.5), key(44, "Space", 5.5), key(231, "Cmd", 1.5), key(230, "Opt", 1.25), gap(0.25), key(80, "←"), key(81, "↓"), key(82, "↑"), key(79, "→")]
    ]
}

private struct KeyboardDeckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 18, y: rect.minY + 8))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 14, y: rect.minY + 4), control: CGPoint(x: rect.midX, y: rect.minY - 5))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 5, y: rect.maxY - 17), control: CGPoint(x: rect.maxX + 5, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 13, y: rect.maxY - 5), control: CGPoint(x: rect.midX, y: rect.maxY + 5))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 18, y: rect.minY + 8), control: CGPoint(x: rect.minX - 5, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct KeyboardHatch: View {
    let color: Color
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            for offset in stride(from: -size.height, through: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                context.stroke(path, with: .color(color), lineWidth: 0.7)
            }
        }
        .allowsHitTesting(false)
    }
}
