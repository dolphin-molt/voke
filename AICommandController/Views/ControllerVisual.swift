import SwiftUI

struct ControllerVisual: View {
    let pressed: Set<String>
    let leftStick: CGPoint
    let rightStick: CGPoint
    let leftTrigger: Float
    let rightTrigger: Float

    private let shell = Color(red: 0.13, green: 0.145, blue: 0.16)
    private let cyan = Color(red: 0.25, green: 0.91, blue: 0.82)
    private let amber = Color(red: 1.0, green: 0.67, blue: 0.22)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 150) {
                trigger("ZL", value: leftTrigger)
                trigger("ZR", value: rightTrigger)
            }
            .zIndex(0)

            ZStack {
                GamepadBody()
                    .fill(
                        LinearGradient(colors: [shell.opacity(0.96), shell.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(GamepadBody().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.55), radius: 28, y: 16)

                HStack(spacing: 86) {
                    VStack(spacing: 28) {
                        StickView(offset: leftStick, active: pressed.contains("L3"))
                        DPadView(pressed: pressed)
                    }
                    VStack(spacing: 30) {
                        FaceButtons(pressed: pressed)
                        StickView(offset: rightStick, active: pressed.contains("R3"))
                    }
                }

                HStack(spacing: 18) {
                    smallButton("−")
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.40))
                        .frame(width: 38, height: 22)
                        .overlay(Text("AI").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(cyan))
                    smallButton("+")
                }
                .offset(y: -44)
            }
            .frame(width: 430, height: 280)
            .offset(y: -5)
        }
        .frame(width: 500, height: 370)
    }

    private func trigger(_ name: String, value: Float) -> some View {
        VStack(spacing: 6) {
            Text(name)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(value > 0.1 ? amber : .secondary)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08)).frame(width: 82, height: 7)
                Capsule().fill(amber).frame(width: max(4, 82 * CGFloat(value)), height: 7)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func smallButton(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(pressed.contains(name) ? .black : .white.opacity(0.55))
            .frame(width: 28, height: 18)
            .background(pressed.contains(name) ? cyan : Color.black.opacity(0.35))
            .clipShape(Capsule())
    }
}

private struct GamepadBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.09))
        path.addCurve(to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.38), control1: CGPoint(x: rect.width * 0.10, y: rect.height * 0.10), control2: CGPoint(x: rect.width * 0.06, y: rect.height * 0.23))
        path.addCurve(to: CGPoint(x: rect.width * 0.12, y: rect.height * 0.94), control1: CGPoint(x: rect.width * 0.01, y: rect.height * 0.58), control2: CGPoint(x: rect.width * 0.02, y: rect.height * 0.88))
        path.addCurve(to: CGPoint(x: rect.width * 0.29, y: rect.height * 0.60), control1: CGPoint(x: rect.width * 0.21, y: rect.height * 1.0), control2: CGPoint(x: rect.width * 0.23, y: rect.height * 0.72))
        path.addCurve(to: CGPoint(x: rect.width * 0.71, y: rect.height * 0.60), control1: CGPoint(x: rect.width * 0.39, y: rect.height * 0.54), control2: CGPoint(x: rect.width * 0.61, y: rect.height * 0.54))
        path.addCurve(to: CGPoint(x: rect.width * 0.88, y: rect.height * 0.94), control1: CGPoint(x: rect.width * 0.77, y: rect.height * 0.72), control2: CGPoint(x: rect.width * 0.79, y: rect.height * 1.0))
        path.addCurve(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.38), control1: CGPoint(x: rect.width * 0.98, y: rect.height * 0.88), control2: CGPoint(x: rect.width * 0.99, y: rect.height * 0.58))
        path.addCurve(to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.09), control1: CGPoint(x: rect.width * 0.94, y: rect.height * 0.23), control2: CGPoint(x: rect.width * 0.90, y: rect.height * 0.10))
        path.addCurve(to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.09), control1: CGPoint(x: rect.width * 0.62, y: 0), control2: CGPoint(x: rect.width * 0.38, y: 0))
        path.closeSubpath()
        return path
    }
}

private struct StickView: View {
    let offset: CGPoint
    let active: Bool
    private let cyan = Color(red: 0.25, green: 0.91, blue: 0.82)

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.48)).frame(width: 72, height: 72)
            Circle().stroke(Color.white.opacity(0.11), lineWidth: 1).frame(width: 58, height: 58)
            Circle()
                .fill(active ? cyan : Color(red: 0.22, green: 0.235, blue: 0.25))
                .frame(width: 43, height: 43)
                .overlay(Circle().stroke(Color.white.opacity(0.16)))
                .offset(x: offset.x * 10, y: -offset.y * 10)
        }
    }
}

private struct FaceButtons: View {
    let pressed: Set<String>
    private let cyan = Color(red: 0.25, green: 0.91, blue: 0.82)

    var body: some View {
        ZStack {
            button("X").offset(y: -33)
            button("B").offset(x: -33)
            button("A").offset(x: 33)
            button("Y").offset(y: 33)
        }
        .frame(width: 100, height: 100)
    }

    private func button(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(pressed.contains(label) ? .black : .white.opacity(0.72))
            .frame(width: 29, height: 29)
            .background(pressed.contains(label) ? cyan : Color.black.opacity(0.48))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.13)))
    }
}

private struct DPadView: View {
    let pressed: Set<String>
    private let cyan = Color(red: 0.25, green: 0.91, blue: 0.82)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.52)).frame(width: 31, height: 85)
            RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.52)).frame(width: 85, height: 31)
            arrow("↑", rotation: 0).offset(y: -27)
            arrow("→", rotation: 90).offset(x: 27)
            arrow("↓", rotation: 180).offset(y: 27)
            arrow("←", rotation: -90).offset(x: -27)
        }
        .frame(width: 90, height: 90)
    }

    private func arrow(_ key: String, rotation: Double) -> some View {
        Image(systemName: "triangle.fill")
            .font(.system(size: 8))
            .foregroundStyle(pressed.contains(key) ? cyan : .white.opacity(0.30))
            .rotationEffect(.degrees(rotation))
    }
}

