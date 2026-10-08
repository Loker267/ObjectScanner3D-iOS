import SwiftUI
import SceneKit
import QuickLook

public struct SceneKitView: UIViewRepresentable {
    public let modelURL: URL
    public var isWireframe: Bool = false
    public var zoomScale: Float = 1.0
    public var resetID: UUID = UUID()
    
    public init(modelURL: URL, isWireframe: Bool = false, zoomScale: Float = 1.0, resetID: UUID = UUID()) {
        self.modelURL = modelURL
        self.isWireframe = isWireframe
        self.zoomScale = zoomScale
        self.resetID = resetID
    }
    
    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = loadScene(from: modelURL)
        scnView.scene = scene
        
        // Включаем нативное интерактивное управление камерой пальцами
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor.systemBackground
        
        // Устанавливаем плавный режим вращения
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        
        // Освещение сцены
        setupLighting(in: scene)
        applyWireframe(scene: scene, wireframe: isWireframe)
        
        context.coordinator.baseNode = scene.rootNode
        return scnView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {
        guard let scene = uiView.scene else { return }
        
        applyWireframe(scene: scene, wireframe: isWireframe)
        
        // Масштабирование через кнопки зума
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.25
        for child in scene.rootNode.childNodes where child.light == nil {
            child.scale = SCNVector3(zoomScale, zoomScale, zoomScale)
        }
        SCNTransaction.commit()
        
        // Сброс положения по требованию
        if context.coordinator.lastResetID != resetID {
            context.coordinator.lastResetID = resetID
            uiView.defaultCameraController.stopInertia()
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.4
            for child in scene.rootNode.childNodes where child.light == nil {
                child.eulerAngles = SCNVector3(0, 0, 0)
            }
            SCNTransaction.commit()
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator {
        var baseNode: SCNNode?
        var lastResetID: UUID = UUID()
    }
    
    private func loadScene(from url: URL) -> SCNScene {
        if url.pathExtension.lowercased() == "ply",
           let coloredNode = ColoredPointCloudBuilder.createColoredSCNNode(from: url) {
            let scene = SCNScene()
            scene.rootNode.addChildNode(coloredNode)
            centerSceneGeometry(scene: scene)
            return scene
        }
        
        if let scene = try? SCNScene(url: url, options: [
            .checkConsistency: true,
            .flattenScene: false
        ]) {
            centerSceneGeometry(scene: scene)
            return scene
        }
        
        // Запасная сцена при ошибке чтения
        let fallback = SCNScene()
        let box = SCNBox(width: 0.25, height: 0.25, length: 0.25, chamferRadius: 0.03)
        box.firstMaterial?.diffuse.contents = UIColor.systemBlue
        let node = SCNNode(geometry: box)
        fallback.rootNode.addChildNode(node)
        return fallback
    }
    
    private func setupLighting(in scene: SCNScene) {
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 800
        ambientLight.color = UIColor.white
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 1500
        keyLight.castsShadow = true
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.position = SCNVector3(1, 2, 2)
        keyNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyNode)
        
        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 800
        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.position = SCNVector3(-2, 1, -2)
        fillNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillNode)
    }
    
    private func centerSceneGeometry(scene: SCNScene) {
        let box = scene.rootNode.boundingBox
        let centerX = (box.min.x + box.max.x) / 2.0
        let centerY = (box.min.y + box.max.y) / 2.0
        let centerZ = (box.min.z + box.max.z) / 2.0
        
        for child in scene.rootNode.childNodes {
            child.position = SCNVector3(
                child.position.x - centerX,
                child.position.y - centerY,
                child.position.z - centerZ
            )
        }
    }
    
    private func applyWireframe(scene: SCNScene, wireframe: Bool) {
        scene.rootNode.enumerateChildNodes { node, _ in
            if let materials = node.geometry?.materials {
                for mat in materials {
                    mat.fillMode = wireframe ? .lines : .fill
                }
            }
        }
    }
}
