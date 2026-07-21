import SwiftUI

struct ControllerMappingSurface: View {
    let controls: [ControllerControl]
    let pressed: Set<String>
    @Binding var selectedControl: ControllerControl
    let mapping: (ControllerControl) -> ButtonMapping
    let controlLabel: (ControllerControl) -> String

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

    private var backControls: [ControllerControl] {
        controls.filter { $0 == .leftTrigger || $0 == .rightTrigger }
    }

    private var directionalControls: [ControllerControl] {
        controls.filter { $0.isSketchDirection }
    }

    private var primaryControls: [ControllerControl] {
        controls.filter { !backControls.contains($0) && !directionalControls.contains($0) }
    }

    var body: some View {
        GeometryReader { geometry in
            let usesCompactStage = geometry.size.height < 600
            let layout = SketchControllerLayout(
                size: geometry.size,
                reservesMappingCard: usesCompactStage
            )
            let focused = hoveredControl ?? selectedControl
            let focusedPoint = layout.point(for: focused)
            let cardPoint = CGPoint(
                x: geometry.size.width * 0.5,
                y: geometry.size.height - (usesCompactStage ? 48 : 128)
            )

            ZStack {
                paperBackground

                stageHeader

                ForEach(backControls) { control in
                    standardButton(control, layout: layout, rear: true)
                        .position(layout.point(for: control))
                }

                controllerArtwork(layout: layout)

                mappingWire(from: focusedPoint, to: cardPoint)

                ForEach(primaryControls) { control in
                    standardButton(control, layout: layout, rear: false)
                        .position(layout.point(for: control))
                }

                ForEach(directionalControls) { control in
                    directionButton(control, layout: layout)
                        .position(layout.directionCenter(for: control))
                }

                focusedMappingCard(focused)
                    .frame(maxWidth: min(390, geometry.size.width - 46))
                    .position(cardPoint)
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
            RadialGradient(
                colors: [accent.opacity(0.055), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 390
            )
        }
    }

    private var stageHeader: some View {
        VStack {
            HStack(alignment: .center) {
                Text("CONTROLLER MAP · HAND DRAWN")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 7) {
                    Circle()
                        .fill(liveGreen)
                        .frame(width: 8, height: 8)
                    Text(pressed.isEmpty ? "等待手柄" : "LIVE INPUT")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.208, green: 0.416, blue: 0.275))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(accent.opacity(0.23))
                .clipShape(Capsule())
            }
            .padding(.top, 21)
            .padding(.horizontal, 24)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func controllerArtwork(layout: SketchControllerLayout) -> some View {
        ZStack {
            SketchControllerBodyShape()
                .fill(paper.opacity(0.98))

            SketchControllerBodyHatch(ink: ink)
                .clipShape(SketchControllerBodyShape())

            SketchControllerBodyShape()
                .stroke(ink, style: StrokeStyle(lineWidth: max(2.4, layout.scale * 4.5), lineJoin: .round))

            SketchControllerBodyShape()
                .stroke(
                    ink.opacity(0.34),
                    style: StrokeStyle(lineWidth: 1, lineJoin: .round, dash: [15, 4, 7, 4])
                )
                .offset(x: 3, y: 2)

            SketchControllerSeams()
                .stroke(ink.opacity(0.48), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [18, 4]))
        }
        .frame(width: layout.artRect.width, height: layout.artRect.height)
        .position(x: layout.artRect.midX, y: layout.artRect.midY)
        .shadow(color: .black.opacity(theme.palette.objectShadowOpacity), radius: 16, y: 10)
        .allowsHitTesting(false)
    }

    private func mappingWire(from focusedPoint: CGPoint, to cardPoint: CGPoint) -> some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: focusedPoint)
            let bendsRight = focusedPoint.x < cardPoint.x
            let controlX = bendsRight ? max(cardPoint.x + 38, focusedPoint.x + 34) : min(cardPoint.x - 38, focusedPoint.x - 34)
            let bendY = max(focusedPoint.y + 34, cardPoint.y - 62)
            path.addCurve(
                to: cardPoint,
                control1: CGPoint(x: controlX, y: bendY),
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

    @ViewBuilder
    private func standardButton(_ control: ControllerControl, layout: SketchControllerLayout, rear: Bool) -> some View {
        let state = visualState(for: control)
        let dimensions = layout.dimensions(for: control)

        Button {
            select(control)
        } label: {
            Group {
                if control == .leftStick || control == .rightStick {
                    sketchStick(control, state: state, diameter: dimensions.width)
                } else if control.group == "SHOULDER" {
                    sketchShoulder(control, state: state, size: dimensions, rear: rear)
                } else {
                    sketchButton(control, state: state, size: dimensions)
                }
            }
            .scaleEffect(state.isPressed ? 0.92 : (state.isEmphasized ? 1.04 : 1))
            .opacity(rear && !state.isEmphasized ? 0.60 : state.isConfigured ? 1 : 0.46)
            .animation(.snappy(duration: 0.18), value: state.isPressed)
            .animation(.easeOut(duration: 0.16), value: state.isEmphasized)
        }
        .buttonStyle(.plain)
        .onHover { hovering in hover(control, hovering: hovering) }
        .help("\(controlLabel(control)) · \(mapping(control).summary)")
    }

    private func sketchStick(_ control: ControllerControl, state: ControlVisualState, diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(fillColor(for: state))
                .overlay(Circle().stroke(strokeColor(for: state), lineWidth: state.isEmphasized ? 3 : 2.4))

            SketchHatch(color: ink.opacity(0.32), spacing: 8)
                .clipShape(Circle())
                .padding(diameter * 0.18)

            Circle()
                .stroke(ink.opacity(0.72), lineWidth: 2)
                .padding(diameter * 0.18)

            Circle()
                .stroke(ink.opacity(0.30), lineWidth: 1)
                .padding(diameter * 0.31)

            if state.isSelected {
                Circle()
                    .stroke(warning, style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [8, 7]))
                    .padding(-5)
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: glowColor(for: state), radius: state.isEmphasized ? 9 : 0)
    }

    private func sketchShoulder(
        _ control: ControllerControl,
        state: ControlVisualState,
        size: CGSize,
        rear: Bool
    ) -> some View {
        let side: ShoulderSide = control == .leftShoulder || control == .leftTrigger ? .left : .right
        let shape = ShoulderKeyShape(side: side, rear: rear)
        return ZStack {
            shape
                .fill(fillColor(for: state))
                .overlay(shape.stroke(strokeColor(for: state), lineWidth: state.isEmphasized ? 3 : 2))

            if rear {
                ShoulderInnerLine(side: side)
                    .stroke(ink.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                    .padding(.horizontal, size.width * 0.10)
                    .padding(.vertical, size.height * 0.14)
            }

            Text(controlLabel(control))
                .font(.system(size: rear ? 10 : 11, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
            if state.isSelected {
                shape
                    .stroke(warning, style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [9, 7]))
                    .padding(-4)
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: glowColor(for: state), radius: state.isEmphasized ? 8 : 0)
    }

    private func sketchButton(_ control: ControllerControl, state: ControlVisualState, size: CGSize) -> some View {
        let compact = control.group == "SYSTEM"
        return ZStack {
            if compact && (control == .capture) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(fillColor(for: state))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(strokeColor(for: state), lineWidth: 2))
            } else {
                Circle()
                    .fill(fillColor(for: state))
                    .overlay(Circle().stroke(strokeColor(for: state), lineWidth: state.isEmphasized ? 3 : 2))
            }

            Text(symbol(for: control))
                .font(.system(size: compact ? 11 : 15, weight: .bold, design: .rounded))
                .foregroundStyle(ink)

            if state.isSelected {
                Group {
                    if compact && control == .capture {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(warning, style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [7, 6]))
                    } else {
                        Circle()
                            .stroke(warning, style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [7, 6]))
                    }
                }
                .padding(-5)
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: glowColor(for: state), radius: state.isEmphasized ? 8 : 0)
    }

    private func directionButton(_ control: ControllerControl, layout: SketchControllerLayout) -> some View {
        let state = visualState(for: control)
        let size = layout.directionSize(for: control)
        let direction = control.sketchDirection ?? .up
        let hitShape = control.group == "DPAD"
            ? AnyShape(DPadArmShape(direction: direction))
            : AnyShape(StickWedgeShape(direction: direction))

        return Button {
            select(control)
        } label: {
            Group {
                if control.group == "DPAD" {
                    DPadArmShape(direction: direction)
                        .fill(fillColor(for: state))
                        .overlay(
                            DPadArmShape(direction: direction)
                                .stroke(strokeColor(for: state), lineWidth: state.isEmphasized ? 2.8 : 2)
                        )
                        .shadow(color: glowColor(for: state), radius: state.isEmphasized ? 8 : 0)
                } else {
                    StickWedgeShape(direction: direction)
                        .fill(state.isEmphasized ? activeColor(for: state).opacity(0.78) : Color.primary.opacity(0.001))
                        .overlay(
                            StickWedgeShape(direction: direction)
                                .stroke(state.isEmphasized ? activeColor(for: state) : .clear, lineWidth: 2)
                        )
                        .shadow(color: glowColor(for: state), radius: state.isEmphasized ? 7 : 0)
                }
            }
            .frame(width: size, height: size)
            .opacity(state.isConfigured ? 1 : 0.46)
            .scaleEffect(state.isPressed ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .contentShape(hitShape)
        .onHover { hovering in hover(control, hovering: hovering) }
        .help("\(controlLabel(control)) · \(mapping(control).summary)")
    }

    private func focusedMappingCard(_ control: ControllerControl) -> some View {
        HStack(spacing: 12) {
            Text(control.compactSketchLabel)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.78))
                .frame(minWidth: 42, minHeight: 30)
                .padding(.horizontal, 4)
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

    private func visualState(for control: ControllerControl) -> ControlVisualState {
        ControlVisualState(
            isPressed: pressed.contains(control.rawValue),
            isSelected: selectedControl == control,
            isHovered: hoveredControl == control,
            isConfigured: mapping(control).actionKind != .none
        )
    }

    private func select(_ control: ControllerControl) {
        withAnimation(.snappy(duration: 0.20)) { selectedControl = control }
    }

    private func hover(_ control: ControllerControl, hovering: Bool) {
        withAnimation(.easeOut(duration: 0.14)) {
            hoveredControl = hovering ? control : (hoveredControl == control ? nil : hoveredControl)
        }
    }

    private func activeColor(for state: ControlVisualState) -> Color {
        state.isPressed ? accent : warning
    }

    private func fillColor(for state: ControlVisualState) -> Color {
        if state.isPressed { return accent.opacity(0.78) }
        if state.isHovered { return accent.opacity(0.22) }
        return elevated.opacity(0.74)
    }

    private func strokeColor(for state: ControlVisualState) -> Color {
        state.isPressed ? accent : ink.opacity(state.isConfigured ? 0.90 : 0.42)
    }

    private func glowColor(for state: ControlVisualState) -> Color {
        if state.isPressed { return accent.opacity(0.72) }
        if state.isSelected { return warning.opacity(0.62) }
        if state.isHovered { return accent.opacity(0.40) }
        return .clear
    }

    private func symbol(for control: ControllerControl) -> String {
        switch control {
        case .capture: "◎"
        case .home: "⌂"
        case .options: "−"
        case .menu: "+"
        default: controlLabel(control)
        }
    }
}

private struct ControlVisualState {
    let isPressed: Bool
    let isSelected: Bool
    let isHovered: Bool
    let isConfigured: Bool

    var isEmphasized: Bool { isPressed || isSelected || isHovered }
}

private struct SketchControllerLayout {
    let size: CGSize
    let scale: CGFloat
    let artRect: CGRect

    init(size: CGSize, reservesMappingCard: Bool = false) {
        self.size = size
        let topInset: CGFloat = 64
        let bottomInset: CGFloat = reservesMappingCard ? 116 : 40
        let availableHeight = max(260, size.height - topInset - bottomInset)
        scale = min((size.width * 0.94) / 1000, availableHeight / 680)
        let artSize = CGSize(width: 1000 * scale, height: 680 * scale)
        let originY = topInset + max(0, (availableHeight - artSize.height) * 0.18) - 10
        artRect = CGRect(
            x: (size.width - artSize.width) * 0.5,
            y: originY,
            width: artSize.width,
            height: artSize.height
        )
    }

    func point(for control: ControllerControl) -> CGPoint {
        let designPoint: CGPoint = switch control {
        case .a: CGPoint(x: 815, y: 305)
        case .b: CGPoint(x: 755, y: 365)
        case .x: CGPoint(x: 755, y: 245)
        case .y: CGPoint(x: 695, y: 305)
        case .leftTrigger: CGPoint(x: 268, y: 122.5)
        case .rightTrigger: CGPoint(x: 732, y: 122.5)
        case .leftShoulder: CGPoint(x: 276.5, y: 142)
        case .rightShoulder: CGPoint(x: 723.5, y: 142)
        case .leftStick: CGPoint(x: 310, y: 270)
        case .rightStick: CGPoint(x: 620, y: 430)
        case .leftStickUp: CGPoint(x: 310, y: 237)
        case .leftStickDown: CGPoint(x: 310, y: 303)
        case .leftStickLeft: CGPoint(x: 277, y: 270)
        case .leftStickRight: CGPoint(x: 343, y: 270)
        case .rightStickUp: CGPoint(x: 620, y: 397)
        case .rightStickDown: CGPoint(x: 620, y: 463)
        case .rightStickLeft: CGPoint(x: 587, y: 430)
        case .rightStickRight: CGPoint(x: 653, y: 430)
        case .up: CGPoint(x: 323, y: 355)
        case .down: CGPoint(x: 323, y: 431)
        case .left: CGPoint(x: 285, y: 393)
        case .right: CGPoint(x: 361, y: 393)
        case .options: CGPoint(x: 435, y: 256)
        case .menu: CGPoint(x: 565, y: 256)
        case .capture: CGPoint(x: 433, y: 335)
        case .home: CGPoint(x: 567, y: 335)
        default: CGPoint(x: 500, y: 340)
        }
        return CGPoint(x: artRect.minX + designPoint.x * scale, y: artRect.minY + designPoint.y * scale)
    }

    func directionCenter(for control: ControllerControl) -> CGPoint {
        switch control.group {
        case "DPAD": CGPoint(x: artRect.minX + 323 * scale, y: artRect.minY + 393 * scale)
        case "STICK" where control.rawValue.hasPrefix("LS"): point(for: .leftStick)
        case "STICK" where control.rawValue.hasPrefix("RS"): point(for: .rightStick)
        default: point(for: control)
        }
    }

    func dimensions(for control: ControllerControl) -> CGSize {
        let designSize: CGSize = switch control {
        case .leftTrigger, .rightTrigger: CGSize(width: 180, height: 47)
        case .leftShoulder, .rightShoulder: CGSize(width: 163, height: 46)
        case .leftStick, .rightStick: CGSize(width: 106, height: 106)
        case .a, .b, .x, .y: CGSize(width: 58, height: 58)
        case .capture: CGSize(width: 34, height: 34)
        case .home: CGSize(width: 40, height: 40)
        case .options, .menu: CGSize(width: 34, height: 34)
        default: CGSize(width: 42, height: 42)
        }
        return CGSize(width: max(24, designSize.width * scale), height: max(24, designSize.height * scale))
    }

    func directionSize(for control: ControllerControl) -> CGFloat {
        (control.group == "DPAD" ? 112 : 112) * scale
    }
}

private enum ShoulderSide {
    case left, right
}

/// Matches the four asymmetric shoulder silhouettes used by the approved SVG study.
private struct ShoulderKeyShape: Shape {
    let side: ShoulderSide
    let rear: Bool

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let mirroredX = side == .left ? x : 1 - x
            return CGPoint(
                x: rect.minX + mirroredX * rect.width,
                y: rect.minY + y * rect.height
            )
        }

        var path = Path()
        if rear {
            // SVG: M178 137c10-34 59-50 137-38l43 22-20 25H201c-18 0-27-3-23-9Z
            path.move(to: point(0.00, 0.81))
            path.addCurve(
                to: point(0.76, 0.00),
                control1: point(0.06, 0.09),
                control2: point(0.33, -0.26)
            )
            path.addLine(to: point(1.00, 0.47))
            path.addLine(to: point(0.89, 1.00))
            path.addLine(to: point(0.13, 1.00))
            path.addCurve(
                to: point(0.00, 0.81),
                control1: point(0.03, 1.00),
                control2: point(-0.05, 0.94)
            )
        } else {
            // SVG: M195 141c31-28 83-35 137-22l26 18-17 28H211c-20 0-29-10-16-24Z
            path.move(to: point(0.00, 0.48))
            path.addCurve(
                to: point(0.84, 0.00),
                control1: point(0.19, -0.13),
                control2: point(0.51, -0.35)
            )
            path.addLine(to: point(1.00, 0.39))
            path.addLine(to: point(0.90, 1.00))
            path.addLine(to: point(0.10, 1.00))
            path.addCurve(
                to: point(0.00, 0.48),
                control1: point(-0.02, 1.00),
                control2: point(-0.08, 0.78)
            )
        }
        path.closeSubpath()
        return path
    }
}

private struct ShoulderInnerLine: Shape {
    let side: ShoulderSide

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let mirroredX = side == .left ? x : 1 - x
            return CGPoint(x: rect.minX + mirroredX * rect.width, y: rect.minY + y * rect.height)
        }

        var path = Path()
        path.move(to: point(0.02, 0.67))
        path.addCurve(
            to: point(0.98, 0.40),
            control1: point(0.32, 0.12),
            control2: point(0.72, 0.05)
        )
        return path
    }
}

private struct SketchControllerBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 1000, y: rect.minY + rect.height * y / 680)
        }

        var path = Path()
        path.move(to: point(255, 137))
        path.addCurve(to: point(87, 297), control1: point(164, 129), control2: point(102, 203))
        path.addLine(to: point(46, 507))
        path.addCurve(to: point(112, 615), control1: point(35, 565), control2: point(64, 615))
        path.addCurve(to: point(200, 527), control1: point(150, 615), control2: point(173, 571))
        path.addLine(to: point(278, 438))
        path.addCurve(to: point(722, 438), control1: point(365, 545), control2: point(635, 545))
        path.addLine(to: point(800, 527))
        path.addCurve(to: point(888, 615), control1: point(827, 571), control2: point(850, 615))
        path.addCurve(to: point(954, 507), control1: point(936, 615), control2: point(965, 565))
        path.addLine(to: point(913, 297))
        path.addCurve(to: point(745, 137), control1: point(898, 203), control2: point(836, 129))
        path.addCurve(to: point(255, 137), control1: point(654, 144), control2: point(374, 174))
        path.closeSubpath()
        return path
    }
}

private struct SketchControllerSeams: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 1000, y: rect.minY + rect.height * y / 680)
        }

        var path = Path()
        path.move(to: point(222, 170))
        path.addCurve(to: point(67, 492), control1: point(155, 174), control2: point(117, 228))
        path.move(to: point(778, 170))
        path.addCurve(to: point(933, 492), control1: point(845, 174), control2: point(883, 228))
        path.move(to: point(278, 438))
        path.addCurve(to: point(295, 276), control1: point(266, 373), control2: point(274, 319))
        path.move(to: point(722, 438))
        path.addCurve(to: point(705, 276), control1: point(734, 373), control2: point(726, 319))
        path.move(to: point(408, 188))
        path.addCurve(to: point(592, 188), control1: point(458, 206), control2: point(542, 206))
        return path
    }
}

private struct SketchControllerBodyHatch: View {
    let ink: Color

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for offset in stride(from: -size.height, through: size.width + size.height, by: 11) {
                    var path = Path()
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset - size.height * 0.28, y: size.height))
                    context.stroke(path, with: .color(ink.opacity(0.10)), lineWidth: 0.7)
                }
            }
        }
    }
}

private struct SketchHatch: View {
    let color: Color
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            for offset in stride(from: -size.height, through: size.width + size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset - size.height * 0.35, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: 0.8)
            }
        }
    }
}

private enum SketchDirection {
    case up, down, left, right
}

private struct DPadArmShape: Shape {
    let direction: SketchDirection

    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = switch direction {
        case .up: [p(0.33, 0.08), p(0.67, 0.08), p(0.67, 0.37), p(0.50, 0.52), p(0.33, 0.37)]
        case .down: [p(0.50, 0.48), p(0.67, 0.63), p(0.67, 0.92), p(0.33, 0.92), p(0.33, 0.63)]
        case .left: [p(0.08, 0.33), p(0.37, 0.33), p(0.52, 0.50), p(0.37, 0.67), p(0.08, 0.67)]
        case .right: [p(0.48, 0.50), p(0.63, 0.33), p(0.92, 0.33), p(0.92, 0.67), p(0.63, 0.67)]
        }
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}

private struct StickWedgeShape: Shape {
    let direction: SketchDirection

    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = switch direction {
        case .up: [p(0.25, 0.32), p(0.35, 0.15), p(0.50, 0.08), p(0.65, 0.15), p(0.75, 0.32), p(0.62, 0.40), p(0.50, 0.34), p(0.38, 0.40)]
        case .down: [p(0.25, 0.68), p(0.38, 0.60), p(0.50, 0.66), p(0.62, 0.60), p(0.75, 0.68), p(0.65, 0.85), p(0.50, 0.92), p(0.35, 0.85)]
        case .left: [p(0.32, 0.25), p(0.40, 0.38), p(0.34, 0.50), p(0.40, 0.62), p(0.32, 0.75), p(0.15, 0.65), p(0.08, 0.50), p(0.15, 0.35)]
        case .right: [p(0.68, 0.25), p(0.85, 0.35), p(0.92, 0.50), p(0.85, 0.65), p(0.68, 0.75), p(0.60, 0.62), p(0.66, 0.50), p(0.60, 0.38)]
        }
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}

private extension ControllerControl {
    var isSketchDirection: Bool {
        switch self {
        case .leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight,
             .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight,
             .up, .down, .left, .right:
            true
        default:
            false
        }
    }

    var sketchDirection: SketchDirection? {
        switch self {
        case .leftStickUp, .rightStickUp, .up: .up
        case .leftStickDown, .rightStickDown, .down: .down
        case .leftStickLeft, .rightStickLeft, .left: .left
        case .leftStickRight, .rightStickRight, .right: .right
        default: nil
        }
    }

    var compactSketchLabel: String {
        switch self {
        case .leftStickUp: "L↑"
        case .leftStickDown: "L↓"
        case .leftStickLeft: "L←"
        case .leftStickRight: "L→"
        case .rightStickUp: "R↑"
        case .rightStickDown: "R↓"
        case .rightStickLeft: "R←"
        case .rightStickRight: "R→"
        default: compactLabel
        }
    }
}
