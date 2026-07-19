import AppKit
import SceneKit
import SwiftUI

struct Controller3DView: NSViewRepresentable {
    let pressed: Set<String>
    let leftStick: CGPoint
    let rightStick: CGPoint
    let leftTrigger: Float
    let rightTrigger: Float

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.makeScene()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        context.coordinator.update(
            pressed: pressed,
            leftStick: leftStick,
            rightStick: rightStick,
            leftTrigger: leftTrigger,
            rightTrigger: rightTrigger
        )
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.update(
            pressed: pressed,
            leftStick: leftStick,
            rightStick: rightStick,
            leftTrigger: leftTrigger,
            rightTrigger: rightTrigger
        )
    }

    final class Coordinator {
        private let modelRoot = SCNNode()
        private var controlNodes: [String: SCNNode] = [:]
        private let cyan = NSColor(red: 0.25, green: 0.91, blue: 0.82, alpha: 1)
        private let amber = NSColor(red: 1.0, green: 0.67, blue: 0.22, alpha: 1)
        private let buttonBlack = NSColor(red: 0.055, green: 0.06, blue: 0.068, alpha: 1)

        func makeScene() -> SCNScene {
            let scene = SCNScene()
            scene.rootNode.addChildNode(modelRoot)
            // Nintendo's published envelope is 152 × 106 × 60 mm. The stronger
            // pitch and deeper rear shell make that thickness visible instead of
            // presenting the controller as a flat front plate.
            modelRoot.eulerAngles = SCNVector3(-0.18, -0.045, 0)
            modelRoot.position = SCNVector3(0, -0.03, 0)

            addShell()
            addFaceControls()
            addCenterControls()
            addTriggers()
            addLighting(to: scene)
            addCamera(to: scene)
            return scene
        }

        func update(
            pressed: Set<String>,
            leftStick: CGPoint,
            rightStick: CGPoint,
            leftTrigger: Float,
            rightTrigger: Float
        ) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.07

            for (name, node) in controlNodes {
                let active = pressed.contains(name)
                let color = (name == "ZL" || name == "ZR") ? amber : cyan
                node.geometry?.firstMaterial?.diffuse.contents = active ? color : buttonBlack
                node.geometry?.firstMaterial?.emission.contents = active ? color.withAlphaComponent(0.52) : NSColor.black
            }

            moveStick("LEFT_STICK", origin: SCNVector3(-1.48, 0.48, 0.58), value: leftStick)
            moveStick("RIGHT_STICK", origin: SCNVector3(0.95, -0.62, 0.58), value: rightStick)
            controlNodes["ZL"]?.position.z = -0.32 - CGFloat(leftTrigger) * 0.10
            controlNodes["ZR"]?.position.z = -0.32 - CGFloat(rightTrigger) * 0.10

            SCNTransaction.commit()
        }

        private func addShell() {
            let rearMaterial = material(
                diffuse: NSColor(red: 0.035, green: 0.039, blue: 0.046, alpha: 1),
                roughness: 0.62,
                metalness: 0.14
            )
            let faceMaterial = material(
                diffuse: NSColor(red: 0.115, green: 0.125, blue: 0.14, alpha: 1),
                roughness: 0.35,
                metalness: 0.22
            )
            let gripMaterial = material(
                diffuse: NSColor(red: 0.055, green: 0.06, blue: 0.07, alpha: 1),
                roughness: 0.82,
                metalness: 0.04
            )

            let leftGrip = capsule(radius: 0.59, height: 2.55, material: gripMaterial)
            leftGrip.position = SCNVector3(-1.72, -0.52, -0.42)
            leftGrip.eulerAngles = SCNVector3(0.04, 0, -0.23)
            leftGrip.scale.z = 1.16
            modelRoot.addChildNode(leftGrip)

            let rightGrip = capsule(radius: 0.59, height: 2.55, material: gripMaterial)
            rightGrip.position = SCNVector3(1.72, -0.52, -0.42)
            rightGrip.eulerAngles = SCNVector3(0.04, 0, 0.23)
            rightGrip.scale.z = 1.16
            modelRoot.addChildNode(rightGrip)

            let rear = extrudedShell(scale: 1.0, depth: 0.72, chamfer: 0.24, material: rearMaterial)
            rear.position.z = -0.58
            modelRoot.addChildNode(rear)

            let face = extrudedShell(scale: 0.94, depth: 0.20, chamfer: 0.14, material: faceMaterial)
            face.position.z = 0.22
            modelRoot.addChildNode(face)

            let centerPlate = SCNNode(geometry: SCNBox(width: 1.34, height: 1.28, length: 0.12, chamferRadius: 0.26))
            centerPlate.geometry?.firstMaterial = material(
                diffuse: NSColor(red: 0.075, green: 0.082, blue: 0.092, alpha: 1),
                roughness: 0.30,
                metalness: 0.36
            )
            centerPlate.position = SCNVector3(0, 0.05, 0.43)
            modelRoot.addChildNode(centerPlate)

            let usbPort = SCNNode(geometry: SCNBox(width: 0.48, height: 0.13, length: 0.12, chamferRadius: 0.05))
            usbPort.geometry?.firstMaterial = material(diffuse: .black, roughness: 0.75, metalness: 0.18)
            usbPort.position = SCNVector3(0, 1.46, -0.52)
            modelRoot.addChildNode(usbPort)

            for x in [-0.18, -0.06, 0.06, 0.18] as [Float] {
                let led = SCNNode(geometry: SCNSphere(radius: 0.027))
                led.geometry?.firstMaterial = material(diffuse: cyan.withAlphaComponent(0.65), roughness: 0.2, metalness: 0.1, emission: cyan.withAlphaComponent(0.30))
                led.position = SCNVector3(x, -0.50, 0.56)
                modelRoot.addChildNode(led)
            }
        }

        private func addFaceControls() {
            addStick(name: "LEFT_STICK", buttonName: "L3", position: SCNVector3(-1.48, 0.48, 0.58))
            addDPad(position: SCNVector3(-1.30, -0.63, 0.59))
            addStick(name: "RIGHT_STICK", buttonName: "R3", position: SCNVector3(0.95, -0.62, 0.58))

            // Nintendo layout: X top, Y left, A right, B bottom.
            addRoundButton("X", position: SCNVector3(1.55, 0.82, 0.61), radius: 0.245)
            addRoundButton("Y", position: SCNVector3(1.14, 0.43, 0.61), radius: 0.245)
            addRoundButton("A", position: SCNVector3(1.96, 0.43, 0.61), radius: 0.245)
            addRoundButton("B", position: SCNVector3(1.55, 0.04, 0.61), radius: 0.245)
        }

        private func addCenterControls() {
            addSymbolButton("−", position: SCNVector3(-0.56, 0.78, 0.57), width: 0.34, height: 0.13)
            addSymbolButton("+", position: SCNVector3(0.56, 0.78, 0.57), width: 0.34, height: 0.13)
            addRoundButton("HOME", position: SCNVector3(0.48, -0.16, 0.57), radius: 0.19, height: 0.11, label: "⌂")
            addSymbolButton("CAPTURE", position: SCNVector3(-0.48, -0.16, 0.57), width: 0.29, height: 0.29, label: "□")

        }

        private func addTriggers() {
            addTrigger("ZL", position: SCNVector3(-1.76, 1.27, -0.32))
            addTrigger("ZR", position: SCNVector3(1.76, 1.27, -0.32))

            let leftShoulder = SCNNode(geometry: SCNBox(width: 0.92, height: 0.20, length: 0.36, chamferRadius: 0.10))
            leftShoulder.geometry?.firstMaterial = material(diffuse: buttonBlack, roughness: 0.45, metalness: 0.12)
            leftShoulder.position = SCNVector3(-0.90, 1.35, -0.34)
            modelRoot.addChildNode(leftShoulder)
            controlNodes["L"] = leftShoulder

            let rightShoulder = SCNNode(geometry: SCNBox(width: 0.92, height: 0.20, length: 0.36, chamferRadius: 0.10))
            rightShoulder.geometry?.firstMaterial = material(diffuse: buttonBlack, roughness: 0.45, metalness: 0.12)
            rightShoulder.position = SCNVector3(0.90, 1.35, -0.34)
            modelRoot.addChildNode(rightShoulder)
            controlNodes["R"] = rightShoulder
        }

        private func addRoundButton(
            _ name: String,
            position: SCNVector3,
            radius: CGFloat,
            height: CGFloat = 0.16,
            label: String? = nil
        ) {
            let geometry = SCNCylinder(radius: radius, height: height)
            geometry.radialSegmentCount = 48
            geometry.firstMaterial = material(diffuse: buttonBlack, roughness: 0.30, metalness: 0.18)
            let node = SCNNode(geometry: geometry)
            node.eulerAngles.x = .pi / 2
            node.position = position
            modelRoot.addChildNode(node)
            controlNodes[name] = node

            let text = textNode(label ?? name, color: NSColor.white.withAlphaComponent(0.72), fontSize: 66)
            text.scale = SCNVector3(0.0024, 0.0024, 0.0024)
            text.position = SCNVector3(position.x, position.y, position.z + height / 2 + 0.012)
            modelRoot.addChildNode(text)
        }

        private func addSymbolButton(
            _ name: String,
            position: SCNVector3,
            width: CGFloat,
            height: CGFloat,
            label: String? = nil
        ) {
            let geometry = SCNBox(width: width, height: height, length: 0.11, chamferRadius: min(width, height) * 0.22)
            geometry.firstMaterial = material(diffuse: buttonBlack, roughness: 0.32, metalness: 0.14)
            let node = SCNNode(geometry: geometry)
            node.position = position
            modelRoot.addChildNode(node)
            controlNodes[name] = node

            let text = textNode(label ?? name, color: NSColor.white.withAlphaComponent(0.72), fontSize: 64)
            text.scale = SCNVector3(0.0022, 0.0022, 0.0022)
            text.position = SCNVector3(position.x, position.y, position.z + 0.065)
            modelRoot.addChildNode(text)
        }

        private func addStick(name: String, buttonName: String, position: SCNVector3) {
            let container = SCNNode()
            container.name = name
            container.position = position

            let well = SCNNode(geometry: SCNCylinder(radius: 0.48, height: 0.13))
            well.geometry?.firstMaterial = material(diffuse: NSColor.black.withAlphaComponent(0.82), roughness: 0.70, metalness: 0.05)
            well.eulerAngles.x = .pi / 2
            container.addChildNode(well)

            let stem = SCNNode(geometry: SCNCylinder(radius: 0.19, height: 0.26))
            stem.geometry?.firstMaterial = material(diffuse: buttonBlack, roughness: 0.62, metalness: 0.04)
            stem.eulerAngles.x = .pi / 2
            stem.position.z = 0.14
            container.addChildNode(stem)

            let cap = SCNNode(geometry: SCNCylinder(radius: 0.35, height: 0.13))
            cap.geometry?.firstMaterial = material(diffuse: buttonBlack, roughness: 0.88, metalness: 0.02)
            cap.eulerAngles.x = .pi / 2
            cap.position.z = 0.29
            container.addChildNode(cap)
            controlNodes[buttonName] = cap

            modelRoot.addChildNode(container)
            controlNodes[name] = container
        }

        private func addDPad(position: SCNVector3) {
            let parent = SCNNode()
            parent.position = position
            let vertical = SCNNode(geometry: SCNBox(width: 0.29, height: 1.00, length: 0.15, chamferRadius: 0.06))
            let horizontal = SCNNode(geometry: SCNBox(width: 1.00, height: 0.29, length: 0.15, chamferRadius: 0.06))
            for node in [vertical, horizontal] {
                node.geometry?.firstMaterial = material(diffuse: buttonBlack, roughness: 0.62, metalness: 0.08)
                parent.addChildNode(node)
            }
            modelRoot.addChildNode(parent)

            let directions: [(String, SCNVector3)] = [
                ("↑", SCNVector3(0, 0.34, 0.09)), ("↓", SCNVector3(0, -0.34, 0.09)),
                ("←", SCNVector3(-0.34, 0, 0.09)), ("→", SCNVector3(0.34, 0, 0.09))
            ]
            for (name, localPosition) in directions {
                let zone = SCNNode(geometry: SCNBox(width: 0.27, height: 0.27, length: 0.04, chamferRadius: 0.025))
                zone.geometry?.firstMaterial = material(diffuse: buttonBlack, roughness: 0.62, metalness: 0.08)
                zone.position = SCNVector3(position.x + localPosition.x, position.y + localPosition.y, position.z + localPosition.z)
                modelRoot.addChildNode(zone)
                controlNodes[name] = zone
            }
        }

        private func addTrigger(_ name: String, position: SCNVector3) {
            let node = SCNNode(geometry: SCNBox(width: 1.20, height: 0.38, length: 0.58, chamferRadius: 0.16))
            node.geometry?.firstMaterial = material(diffuse: buttonBlack, roughness: 0.38, metalness: 0.16)
            node.position = position
            modelRoot.addChildNode(node)
            controlNodes[name] = node

            let label = textNode(name, color: NSColor.white.withAlphaComponent(0.55), fontSize: 64)
            label.scale = SCNVector3(0.0025, 0.0025, 0.0025)
            label.position = SCNVector3(position.x, position.y - 0.04, position.z + 0.31)
            modelRoot.addChildNode(label)
        }

        private func moveStick(_ name: String, origin: SCNVector3, value: CGPoint) {
            guard let node = controlNodes[name] else { return }
            let x = origin.x + value.x * 0.12
            let y = origin.y + value.y * 0.12
            node.position = SCNVector3(x, y, origin.z)
        }

        private func extrudedShell(scale: CGFloat, depth: CGFloat, chamfer: CGFloat, material: SCNMaterial) -> SCNNode {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: -1.66 * scale, y: 1.32 * scale))
            path.curve(to: NSPoint(x: -2.42 * scale, y: 0.78 * scale), controlPoint1: NSPoint(x: -2.16 * scale, y: 1.28 * scale), controlPoint2: NSPoint(x: -2.36 * scale, y: 1.05 * scale))
            path.curve(to: NSPoint(x: -2.10 * scale, y: -1.02 * scale), controlPoint1: NSPoint(x: -2.62 * scale, y: 0.08 * scale), controlPoint2: NSPoint(x: -2.55 * scale, y: -0.72 * scale))
            path.curve(to: NSPoint(x: -1.38 * scale, y: -0.58 * scale), controlPoint1: NSPoint(x: -1.82 * scale, y: -1.18 * scale), controlPoint2: NSPoint(x: -1.62 * scale, y: -0.72 * scale))
            path.curve(to: NSPoint(x: 1.38 * scale, y: -0.58 * scale), controlPoint1: NSPoint(x: -0.62 * scale, y: -0.82 * scale), controlPoint2: NSPoint(x: 0.62 * scale, y: -0.82 * scale))
            path.curve(to: NSPoint(x: 2.10 * scale, y: -1.02 * scale), controlPoint1: NSPoint(x: 1.62 * scale, y: -0.72 * scale), controlPoint2: NSPoint(x: 1.82 * scale, y: -1.18 * scale))
            path.curve(to: NSPoint(x: 2.42 * scale, y: 0.78 * scale), controlPoint1: NSPoint(x: 2.55 * scale, y: -0.72 * scale), controlPoint2: NSPoint(x: 2.62 * scale, y: 0.08 * scale))
            path.curve(to: NSPoint(x: 1.66 * scale, y: 1.32 * scale), controlPoint1: NSPoint(x: 2.36 * scale, y: 1.05 * scale), controlPoint2: NSPoint(x: 2.16 * scale, y: 1.28 * scale))
            path.curve(to: NSPoint(x: -1.66 * scale, y: 1.32 * scale), controlPoint1: NSPoint(x: 0.75 * scale, y: 1.48 * scale), controlPoint2: NSPoint(x: -0.75 * scale, y: 1.48 * scale))
            path.close()

            let geometry = SCNShape(path: path, extrusionDepth: depth)
            geometry.chamferRadius = chamfer
            geometry.chamferMode = .both
            geometry.firstMaterial = material
            return SCNNode(geometry: geometry)
        }

        private func capsule(radius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
            let geometry = SCNCapsule(capRadius: radius, height: height)
            geometry.radialSegmentCount = 64
            geometry.capSegmentCount = 24
            geometry.firstMaterial = material
            return SCNNode(geometry: geometry)
        }

        private func textNode(_ string: String, color: NSColor, fontSize: CGFloat) -> SCNNode {
            let geometry = SCNText(string: string, extrusionDepth: 0.25)
            geometry.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
            geometry.flatness = 0.15
            geometry.firstMaterial = material(diffuse: color, roughness: 0.35, metalness: 0.05, emission: color.withAlphaComponent(0.08))
            let node = SCNNode(geometry: geometry)
            let bounds = geometry.boundingBox
            node.pivot = SCNMatrix4MakeTranslation(
                (bounds.min.x + bounds.max.x) / 2,
                (bounds.min.y + bounds.max.y) / 2,
                0
            )
            return node
        }

        private func material(
            diffuse: NSColor,
            roughness: CGFloat,
            metalness: CGFloat,
            emission: NSColor = .black
        ) -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = diffuse
            material.roughness.contents = roughness
            material.metalness.contents = metalness
            material.emission.contents = emission
            return material
        }

        private func addLighting(to scene: SCNScene) {
            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .area
            key.light?.color = NSColor(red: 0.72, green: 0.86, blue: 1.0, alpha: 1)
            key.light?.intensity = 980
            key.light?.areaType = .rectangle
            key.light?.areaExtents = SIMD3<Float>(4, 4, 0)
            key.position = SCNVector3(-3.5, 4.5, 5.5)
            key.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(key)

            let rim = SCNNode()
            rim.light = SCNLight()
            rim.light?.type = .omni
            rim.light?.color = NSColor(white: 0.82, alpha: 1)
            rim.light?.intensity = 180
            rim.position = SCNVector3(4.2, -1.4, 3.2)
            scene.rootNode.addChildNode(rim)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .ambient
            fill.light?.color = NSColor(white: 0.22, alpha: 1)
            fill.light?.intensity = 280
            scene.rootNode.addChildNode(fill)
        }

        private func addCamera(to scene: SCNScene) {
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.fieldOfView = 32
            camera.camera?.zNear = 0.1
            camera.camera?.zFar = 100
            camera.position = SCNVector3(0, 0.18, 9.0)
            camera.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(camera)
        }
    }
}
