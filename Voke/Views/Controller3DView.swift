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

            moveStick("LEFT_STICK", origin: SCNVector3(-1.36, 0.52, 0.49), value: leftStick)
            moveStick("RIGHT_STICK", origin: SCNVector3(0.72, -0.26, 0.49), value: rightStick)
            controlNodes["ZL"]?.position.z = -0.30 - CGFloat(leftTrigger) * 0.10
            controlNodes["ZR"]?.position.z = -0.30 - CGFloat(rightTrigger) * 0.10

            SCNTransaction.commit()
        }

        private func addShell() {
            let rearMaterial = material(
                diffuse: NSColor(red: 0.035, green: 0.039, blue: 0.046, alpha: 1),
                roughness: 0.62,
                metalness: 0.14
            )
            let faceMaterial = material(
                diffuse: NSColor(red: 0.155, green: 0.16, blue: 0.17, alpha: 1),
                roughness: 0.48,
                metalness: 0.12
            )
            let gripMaterial = material(
                diffuse: NSColor(red: 0.055, green: 0.06, blue: 0.07, alpha: 1),
                roughness: 0.82,
                metalness: 0.04
            )

            let rear = extrudedSilhouette(scale: 1.0, depth: 0.66, chamfer: 0.18, material: rearMaterial)
            rear.position.z = -0.48
            modelRoot.addChildNode(rear)
            addIntegratedGrip(left: true, material: rearMaterial, z: -0.20)
            addIntegratedGrip(left: false, material: rearMaterial, z: -0.20)

            let face = extrudedSilhouette(scale: 0.975, depth: 0.14, chamfer: 0.10, material: faceMaterial)
            face.position.z = 0.20
            modelRoot.addChildNode(face)
            addIntegratedGrip(left: true, material: gripMaterial, z: -0.01)
            addIntegratedGrip(left: false, material: gripMaterial, z: -0.01)

            addGripSeam(left: true, material: gripMaterial)
            addGripSeam(left: false, material: gripMaterial)

            let usbPort = SCNNode(geometry: SCNBox(width: 0.48, height: 0.13, length: 0.12, chamferRadius: 0.05))
            usbPort.geometry?.firstMaterial = material(diffuse: .black, roughness: 0.75, metalness: 0.18)
            usbPort.position = SCNVector3(0, 1.46, -0.52)
            modelRoot.addChildNode(usbPort)

        }

        private func addFaceControls() {
            addStick(name: "LEFT_STICK", buttonName: "L3", position: SCNVector3(-1.36, 0.52, 0.49))
            addDPad(position: SCNVector3(-1.18, -0.28, 0.50))
            addStick(name: "RIGHT_STICK", buttonName: "R3", position: SCNVector3(0.72, -0.26, 0.49))

            // Nintendo layout: X top, Y left, A right, B bottom.
            addRoundButton("X", position: SCNVector3(1.50, 0.72, 0.51), radius: 0.225)
            addRoundButton("Y", position: SCNVector3(1.16, 0.39, 0.51), radius: 0.225)
            addRoundButton("A", position: SCNVector3(1.84, 0.39, 0.51), radius: 0.225)
            addRoundButton("B", position: SCNVector3(1.50, 0.06, 0.51), radius: 0.225)
        }

        private func addCenterControls() {
            addSymbolButton("−", position: SCNVector3(-0.58, 0.79, 0.50), width: 0.31, height: 0.12)
            addSymbolButton("+", position: SCNVector3(0.55, 0.79, 0.50), width: 0.31, height: 0.12)
            addRoundButton("HOME", position: SCNVector3(0.36, 0.34, 0.50), radius: 0.16, height: 0.10, label: "⌂")
            addSymbolButton("CAPTURE", position: SCNVector3(-0.40, 0.34, 0.50), width: 0.25, height: 0.25, label: "□")

        }

        private func addTriggers() {
            addTrigger("ZL", position: SCNVector3(-1.62, 1.24, -0.30))
            addTrigger("ZR", position: SCNVector3(1.62, 1.24, -0.30))

            let leftShoulder = SCNNode(geometry: SCNBox(width: 0.92, height: 0.20, length: 0.36, chamferRadius: 0.10))
            leftShoulder.geometry?.firstMaterial = material(diffuse: buttonBlack, roughness: 0.45, metalness: 0.12)
            leftShoulder.position = SCNVector3(-0.92, 1.30, -0.30)
            modelRoot.addChildNode(leftShoulder)
            controlNodes["L"] = leftShoulder

            let rightShoulder = SCNNode(geometry: SCNBox(width: 0.92, height: 0.20, length: 0.36, chamferRadius: 0.10))
            rightShoulder.geometry?.firstMaterial = material(diffuse: buttonBlack, roughness: 0.45, metalness: 0.12)
            rightShoulder.position = SCNVector3(0.92, 1.30, -0.30)
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
            let node = SCNNode(geometry: SCNBox(width: 0.82, height: 0.22, length: 0.40, chamferRadius: 0.11))
            node.geometry?.firstMaterial = material(diffuse: buttonBlack, roughness: 0.38, metalness: 0.16)
            node.position = position
            modelRoot.addChildNode(node)
            controlNodes[name] = node

        }

        private func moveStick(_ name: String, origin: SCNVector3, value: CGPoint) {
            guard let node = controlNodes[name] else { return }
            let x = origin.x + value.x * 0.12
            let y = origin.y + value.y * 0.12
            node.position = SCNVector3(x, y, origin.z)
        }

        private func extrudedSilhouette(scale: CGFloat, depth: CGFloat, chamfer: CGFloat, material: SCNMaterial) -> SCNNode {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: -1.38 * scale, y: 1.24 * scale))
            path.curve(to: NSPoint(x: -2.14 * scale, y: 0.92 * scale), controlPoint1: NSPoint(x: -1.78 * scale, y: 1.27 * scale), controlPoint2: NSPoint(x: -2.00 * scale, y: 1.14 * scale))
            path.curve(to: NSPoint(x: -2.16 * scale, y: -0.50 * scale), controlPoint1: NSPoint(x: -2.38 * scale, y: 0.50 * scale), controlPoint2: NSPoint(x: -2.36 * scale, y: -0.18 * scale))
            path.curve(to: NSPoint(x: -1.08 * scale, y: -0.58 * scale), controlPoint1: NSPoint(x: -1.82 * scale, y: -0.62 * scale), controlPoint2: NSPoint(x: -1.38 * scale, y: -0.60 * scale))
            path.curve(to: NSPoint(x: 1.08 * scale, y: -0.58 * scale), controlPoint1: NSPoint(x: -0.55 * scale, y: -0.52 * scale), controlPoint2: NSPoint(x: 0.55 * scale, y: -0.52 * scale))
            path.curve(to: NSPoint(x: 2.16 * scale, y: -0.50 * scale), controlPoint1: NSPoint(x: 1.38 * scale, y: -0.60 * scale), controlPoint2: NSPoint(x: 1.82 * scale, y: -0.62 * scale))
            path.curve(to: NSPoint(x: 2.14 * scale, y: 0.92 * scale), controlPoint1: NSPoint(x: 2.40 * scale, y: -0.16 * scale), controlPoint2: NSPoint(x: 2.42 * scale, y: 0.46 * scale))
            path.curve(to: NSPoint(x: 1.38 * scale, y: 1.24 * scale), controlPoint1: NSPoint(x: 2.00 * scale, y: 1.14 * scale), controlPoint2: NSPoint(x: 1.78 * scale, y: 1.27 * scale))
            path.curve(to: NSPoint(x: -1.38 * scale, y: 1.24 * scale), controlPoint1: NSPoint(x: 0.62 * scale, y: 1.35 * scale), controlPoint2: NSPoint(x: -0.62 * scale, y: 1.35 * scale))
            path.close()

            let geometry = SCNShape(path: path, extrusionDepth: depth)
            geometry.chamferRadius = chamfer
            geometry.chamferMode = .both
            geometry.firstMaterial = material
            return SCNNode(geometry: geometry)
        }

        private func addIntegratedGrip(left: Bool, material: SCNMaterial, z: CGFloat) {
            let grip = capsule(radius: 0.61, height: 2.45, material: material)
            grip.position = SCNVector3(left ? -1.72 : 1.72, -0.54, z)
            grip.eulerAngles.z = left ? -0.17 : 0.17
            grip.scale.z = 0.76
            modelRoot.addChildNode(grip)
        }

        private func addGripSeam(left: Bool, material: SCNMaterial) {
            let seam = SCNNode(geometry: SCNBox(width: 1.02, height: 0.022, length: 0.022, chamferRadius: 0.007))
            seam.geometry?.firstMaterial = material
            seam.position = SCNVector3(left ? -1.66 : 1.66, -0.20, 0.39)
            seam.eulerAngles.z = left ? -0.56 : 0.56
            modelRoot.addChildNode(seam)
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
