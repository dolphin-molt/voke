import SwiftUI

struct MouseMappingSurface: View {
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
    private var paper: Color { theme.palette.paper }

    private var mouseControls: [ControllerControl] {
        controls.filter { control in
            guard case let .hid(usagePage, _) = control else { return false }
            return usagePage == 9
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = MouseSketchLayout(size: geometry.size)
            let candidate = hoveredControl ?? selectedControl
            let focused = mouseControls.contains(candidate) ? candidate : mouseControls.first

            ZStack {
                paperBackground
                stageHeader
                mouseArtwork(layout: layout)

                if let control = control(usage: 1) {
                    mouseButton(control, side: .left, layout: layout)
                        .frame(width: layout.mainButtonSize.width, height: layout.mainButtonSize.height)
                        .position(layout.mainButtonCanvasCenter)
                } else {
                    inactiveMainButton(side: .left, label: "L", layout: layout)
                        .position(layout.mainButtonCanvasCenter)
                }
                if let control = control(usage: 2) {
                    mouseButton(control, side: .right, layout: layout)
                        .frame(width: layout.mainButtonSize.width, height: layout.mainButtonSize.height)
                        .position(layout.mainButtonCanvasCenter)
                } else {
                    inactiveMainButton(side: .right, label: "R", layout: layout)
                        .position(layout.mainButtonCanvasCenter)
                }
                if let control = control(usage: 3) {
                    wheelButton(control, layout: layout)
                        .position(layout.point(forUsage: 3))
                } else {
                    inactiveWheel(layout: layout)
                        .position(layout.point(forUsage: 3))
                }

                if sideControls.isEmpty {
                    inactiveSideButton(label: "S1", layout: layout)
                        .position(layout.point(forUsage: 4))
                    inactiveSideButton(label: "S2", layout: layout)
                        .position(layout.point(forUsage: 5))
                } else {
                    ForEach(sideControls) { control in
                        sideButton(control, layout: layout)
                            .position(layout.point(for: control))
                    }
                }

                if let focused {
                    mappingWire(
                        from: layout.point(for: focused),
                        to: layout.mappingCardPoint
                    )

                    focusedMappingCard(focused)
                        .frame(maxWidth: min(410, geometry.size.width - 46))
                        .position(layout.mappingCardPoint)
                } else {
                    inactiveMappingCard
                        .frame(maxWidth: min(440, geometry.size.width - 46))
                        .position(layout.mappingCardPoint)
                }
            }
        }
        .clipShape(stageShape)
        .overlay(stageShape.stroke(border))
        .shadow(color: ink.opacity(theme.palette.panelShadowOpacity), radius: 35, y: 18)
    }

    private var sideControls: [ControllerControl] {
        mouseControls.filter { mouseUsage($0) ?? 0 >= 4 }
            .sorted { (mouseUsage($0) ?? 0) < (mouseUsage($1) ?? 0) }
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
            RadialGradient(
                colors: [accent.opacity(0.07), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 430
            )
        }
    }

    private var stageHeader: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MOUSE MAP · HAND DRAWN")
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
                    Text(pressed.isEmpty ? "等待鼠标" : "LIVE INPUT")
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

    private func mouseArtwork(layout: MouseSketchLayout) -> some View {
        ZStack {
            MouseBodyShape()
                .fill(paper.opacity(0.98))
            MouseSketchHatch(color: ink.opacity(0.20), spacing: 11)
                .clipShape(MouseBodyShape())
            MouseBodyShape()
                .stroke(ink, style: StrokeStyle(lineWidth: max(2.4, layout.scale * 4), lineJoin: .round))
            MouseBodyShape()
                .stroke(ink.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [15, 4, 7, 4]))
                .offset(x: 3, y: 2)
            MouseSeamShape()
                .stroke(ink.opacity(0.48), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [18, 4]))
        }
        .frame(width: layout.mouseRect.width, height: layout.mouseRect.height)
        .position(x: layout.mouseRect.midX, y: layout.mouseRect.midY)
        .shadow(color: .black.opacity(theme.palette.objectShadowOpacity), radius: 17, y: 11)
        .allowsHitTesting(false)
    }

    private func mouseButton(
        _ control: ControllerControl,
        side: MouseButtonSide,
        layout: MouseSketchLayout
    ) -> some View {
        let state = visualState(for: control)
        let shape = MouseMainButtonShape(side: side)
        return Button { select(control) } label: {
            ZStack {
                shape
                    .fill(fillColor(for: state))
                    .overlay(shape.stroke(strokeColor(for: state), lineWidth: state.isEmphasized ? 3 : 2))
                Text(mouseUsage(control) == 1 ? "L" : "R")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(ink.opacity(0.72))
                    .position(layout.mainButtonLabelPoint(side: side))
                if state.isSelected {
                    shape
                        .stroke(warning, style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [9, 7]))
                        .padding(-5)
                }
            }
            .scaleEffect(state.isPressed ? 0.96 : (state.isHovered ? 1.02 : 1))
            .shadow(color: glowColor(for: state), radius: state.isEmphasized ? 9 : 0)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .onHover { hover(control, $0) }
        .help("\(controlLabel(control)) · \(mapping(control).summary)")
    }

    private func inactiveMainButton(
        side: MouseButtonSide,
        label: String,
        layout: MouseSketchLayout
    ) -> some View {
        let shape = MouseMainButtonShape(side: side)
        return ZStack {
            shape.fill(elevated.opacity(0.32))
            shape.stroke(ink.opacity(0.30), lineWidth: 2)
            Text(label)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(ink.opacity(0.38))
                .position(layout.mainButtonLabelPoint(side: side))
        }
        .frame(width: layout.mainButtonSize.width, height: layout.mainButtonSize.height)
        .allowsHitTesting(false)
    }

    private func wheelButton(_ control: ControllerControl, layout: MouseSketchLayout) -> some View {
        let state = visualState(for: control)
        return Button { select(control) } label: {
            ZStack {
                Capsule()
                    .fill(fillColor(for: state))
                    .overlay(Capsule().stroke(strokeColor(for: state), lineWidth: state.isEmphasized ? 3 : 2))
                VStack(spacing: 4 * layout.scale) {
                    ForEach(0..<6, id: \.self) { _ in
                        Capsule().fill(ink.opacity(0.55)).frame(width: 12 * layout.scale, height: 1.4)
                    }
                }
                if state.isSelected {
                    Capsule()
                        .stroke(warning, style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [7, 6]))
                        .padding(-5)
                }
            }
            .frame(width: 36 * layout.scale, height: 82 * layout.scale)
            .scaleEffect(state.isPressed ? 0.92 : 1)
            .shadow(color: glowColor(for: state), radius: state.isEmphasized ? 9 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hover(control, $0) }
        .help("滚轮按压 · \(mapping(control).summary)")
    }

    private func inactiveWheel(layout: MouseSketchLayout) -> some View {
        ZStack {
            Capsule()
                .fill(elevated.opacity(0.48))
                .overlay(Capsule().stroke(ink.opacity(0.38), lineWidth: 2))
            VStack(spacing: 4 * layout.scale) {
                ForEach(0..<6, id: \.self) { _ in
                    Capsule().fill(ink.opacity(0.34)).frame(width: 12 * layout.scale, height: 1.4)
                }
            }
        }
        .frame(width: 36 * layout.scale, height: 82 * layout.scale)
        .allowsHitTesting(false)
    }

    private func sideButton(_ control: ControllerControl, layout: MouseSketchLayout) -> some View {
        let state = visualState(for: control)
        return Button { select(control) } label: {
            ZStack {
                Capsule()
                    .fill(fillColor(for: state))
                    .overlay(Capsule().stroke(strokeColor(for: state), lineWidth: state.isEmphasized ? 3 : 2))
                Text("S\((mouseUsage(control) ?? 3) - 3)")
                    .font(.system(size: max(8, 10 * layout.scale), weight: .black, design: .rounded))
                    .foregroundStyle(ink.opacity(0.76))
                if state.isSelected {
                    Capsule()
                        .stroke(warning, style: StrokeStyle(lineWidth: 6, dash: [7, 6]))
                        .padding(-5)
                }
            }
            .frame(width: 72 * layout.scale, height: 32 * layout.scale)
            .rotationEffect(.degrees(-8))
            .scaleEffect(state.isPressed ? 0.92 : 1)
            .shadow(color: glowColor(for: state), radius: state.isEmphasized ? 8 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hover(control, $0) }
        .help("\(controlLabel(control)) · \(mapping(control).summary)")
    }

    private func inactiveSideButton(label: String, layout: MouseSketchLayout) -> some View {
        Text(label)
            .font(.system(size: max(8, 10 * layout.scale), weight: .black, design: .rounded))
            .foregroundStyle(ink.opacity(0.38))
            .frame(width: 72 * layout.scale, height: 32 * layout.scale)
            .background(elevated.opacity(0.42))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(ink.opacity(0.32), lineWidth: 2))
            .rotationEffect(.degrees(-8))
            .allowsHitTesting(false)
    }

    private func mappingWire(from focusedPoint: CGPoint, to cardPoint: CGPoint) -> some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: focusedPoint)
            let bendY = max(focusedPoint.y + 34, cardPoint.y - 56)
            path.addCurve(
                to: cardPoint,
                control1: CGPoint(x: focusedPoint.x + 78, y: bendY),
                control2: CGPoint(x: cardPoint.x, y: bendY)
            )
            context.stroke(
                path,
                with: .color(liveGreen.opacity(0.82)),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [6, 6])
            )
            context.fill(
                Path(ellipseIn: CGRect(x: focusedPoint.x - 3.5, y: focusedPoint.y - 3.5, width: 7, height: 7)),
                with: .color(liveGreen)
            )
        }
        .allowsHitTesting(false)
    }

    private func focusedMappingCard(_ control: ControllerControl) -> some View {
        HStack(spacing: 12) {
            Text(controlLabel(control))
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.78))
                .frame(minWidth: 56, minHeight: 30)
                .padding(.horizontal, 8)
                .background(accent)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text("当前映射")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
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
        .background(surface.opacity(0.84))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(liveGreen.opacity(0.56), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .shadow(color: .black.opacity(0.11), radius: 15, y: 7)
    }

    private var inactiveMappingCard: some View {
        Button(action: openInputMonitoringSettings) {
            HStack(spacing: 12) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ink.opacity(0.70))
                    .frame(width: 34, height: 30)
                    .background(accent)
                    .clipShape(Capsule())
                VStack(alignment: .leading, spacing: 2) {
                    Text("打开输入监控设置")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                    Text("允许后，模型上的五个按键会自动启用")
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
        mouseControls.first { mouseUsage($0) == usage }
    }

    private func mouseUsage(_ control: ControllerControl) -> UInt32? {
        guard case let .hid(usagePage, usage) = control, usagePage == 9 else { return nil }
        return usage
    }

    private func visualState(for control: ControllerControl) -> MouseControlVisualState {
        MouseControlVisualState(
            isPressed: pressed.contains(control.rawValue),
            isSelected: selectedControl == control,
            isHovered: hoveredControl == control,
            isConfigured: mapping(control).actionKind != .none
        )
    }

    private func select(_ control: ControllerControl) {
        withAnimation(.snappy(duration: 0.20)) { selectedControl = control }
    }

    private func hover(_ control: ControllerControl, _ hovering: Bool) {
        withAnimation(.easeOut(duration: 0.14)) {
            hoveredControl = hovering ? control : (hoveredControl == control ? nil : hoveredControl)
        }
    }

    private func fillColor(for state: MouseControlVisualState) -> Color {
        if state.isPressed { return accent.opacity(0.82) }
        if state.isHovered { return accent.opacity(0.24) }
        return elevated.opacity(state.isConfigured ? 0.92 : 0.76)
    }

    private func strokeColor(for state: MouseControlVisualState) -> Color {
        state.isPressed ? accent : ink.opacity(state.isConfigured ? 0.92 : 0.48)
    }

    private func glowColor(for state: MouseControlVisualState) -> Color {
        if state.isPressed { return accent.opacity(0.72) }
        if state.isSelected { return warning.opacity(0.60) }
        if state.isHovered { return accent.opacity(0.38) }
        return .clear
    }
}

private struct MouseControlVisualState {
    let isPressed: Bool
    let isSelected: Bool
    let isHovered: Bool
    let isConfigured: Bool
    var isEmphasized: Bool { isPressed || isSelected || isHovered }
}

private struct MouseSketchLayout {
    let size: CGSize
    let scale: CGFloat
    let mouseRect: CGRect
    let mappingCardPoint: CGPoint

    init(size: CGSize) {
        self.size = size
        let topInset: CGFloat = 78
        let bottomReserve: CGFloat = 94
        let availableHeight = max(260, size.height - topInset - bottomReserve)
        scale = min((size.width * 0.58) / 320, availableHeight / 450, 1.08)
        let mouseSize = CGSize(width: 320 * scale, height: 450 * scale)
        mouseRect = CGRect(
            x: (size.width - mouseSize.width) * 0.5,
            y: topInset + max(0, (availableHeight - mouseSize.height) * 0.18),
            width: mouseSize.width,
            height: mouseSize.height
        )
        mappingCardPoint = CGPoint(x: size.width * 0.5, y: size.height - 47)
    }

    var mainButtonSize: CGSize { mouseRect.size }
    var mainButtonCanvasCenter: CGPoint { CGPoint(x: mouseRect.midX, y: mouseRect.midY) }

    func mainButtonLabelPoint(side: MouseButtonSide) -> CGPoint {
        CGPoint(
            x: mouseRect.width * (side == .left ? 0.29 : 0.71),
            y: mouseRect.height * 0.22
        )
    }

    func point(forUsage usage: UInt32) -> CGPoint {
        let designPoint: CGPoint = switch usage {
        case 1: CGPoint(x: 91, y: 112)
        case 2: CGPoint(x: 229, y: 112)
        case 3: CGPoint(x: 160, y: 142)
        case 4: CGPoint(x: 59, y: 244)
        case 5: CGPoint(x: 68, y: 292)
        default: CGPoint(x: 76, y: 292 + CGFloat(usage - 5) * 38)
        }
        return CGPoint(x: mouseRect.minX + designPoint.x * scale, y: mouseRect.minY + designPoint.y * scale)
    }

    func point(for control: ControllerControl) -> CGPoint {
        guard case let .hid(usagePage, usage) = control, usagePage == 9 else {
            return CGPoint(x: mouseRect.midX, y: mouseRect.midY)
        }
        return point(forUsage: usage)
    }
}

private enum MouseButtonSide { case left, right }

private struct MouseMainButtonShape: Shape {
    let side: MouseButtonSide

    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        if side == .left {
            path.move(to: p(0.50, 0.01))
            path.addCurve(to: p(0.17, 0.14), control1: p(0.34, 0.01), control2: p(0.23, 0.06))
            path.addCurve(to: p(0.10, 0.42), control1: p(0.13, 0.22), control2: p(0.10, 0.33))
            path.addQuadCurve(to: p(0.50, 0.45), control: p(0.30, 0.45))
        } else {
            path.move(to: p(0.50, 0.01))
            path.addCurve(to: p(0.83, 0.14), control1: p(0.66, 0.01), control2: p(0.77, 0.06))
            path.addCurve(to: p(0.90, 0.42), control1: p(0.87, 0.22), control2: p(0.90, 0.33))
            path.addQuadCurve(to: p(0.50, 0.45), control: p(0.70, 0.45))
        }
        path.closeSubpath()
        return path
    }
}

private struct MouseBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: p(0.50, 0.01))
        path.addCurve(to: p(0.17, 0.14), control1: p(0.34, 0.01), control2: p(0.23, 0.06))
        path.addCurve(to: p(0.05, 0.57), control1: p(0.08, 0.27), control2: p(0.03, 0.42))
        path.addCurve(to: p(0.17, 0.91), control1: p(0.06, 0.73), control2: p(0.10, 0.85))
        path.addCurve(to: p(0.50, 0.99), control1: p(0.26, 0.98), control2: p(0.39, 1.00))
        path.addCurve(to: p(0.83, 0.91), control1: p(0.61, 1.00), control2: p(0.74, 0.98))
        path.addCurve(to: p(0.95, 0.57), control1: p(0.90, 0.85), control2: p(0.94, 0.73))
        path.addCurve(to: p(0.83, 0.14), control1: p(0.97, 0.42), control2: p(0.92, 0.27))
        path.addCurve(to: p(0.50, 0.01), control1: p(0.77, 0.06), control2: p(0.66, 0.01))
        path.closeSubpath()
        return path
    }
}

private struct MouseSeamShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.02))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.45))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.42))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.minY + rect.height * 0.42),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.48)
        )
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.54))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.54),
            control1: CGPoint(x: rect.width * 0.33, y: rect.height * 0.58),
            control2: CGPoint(x: rect.width * 0.67, y: rect.height * 0.58)
        )
        return path
    }
}

private struct MouseSketchHatch: View {
    let color: Color
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            for offset in stride(from: -size.height, through: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                context.stroke(path, with: .color(color), lineWidth: 0.8)
            }
        }
        .allowsHitTesting(false)
    }
}
