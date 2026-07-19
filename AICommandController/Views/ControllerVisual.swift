import SwiftUI

struct ControllerVisual: View {
    let pressed: Set<String>
    let leftStick: CGPoint
    let rightStick: CGPoint
    let leftTrigger: Float
    let rightTrigger: Float

    var body: some View {
        ZStack(alignment: .bottom) {
            Controller3DView(
                pressed: pressed,
                leftStick: leftStick,
                rightStick: rightStick,
                leftTrigger: leftTrigger,
                rightTrigger: rightTrigger
            )

            HStack(spacing: 10) {
                Image(systemName: "rotate.3d")
                Text("拖动旋转 · 双指缩放 · 实时输入")
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.48))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(.black.opacity(0.34))
            .clipShape(Capsule())
            .padding(.bottom, 8)
        }
        .frame(width: 530, height: 390)
    }
}
