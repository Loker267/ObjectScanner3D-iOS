import SwiftUI
import SceneKit
import QuickLook

public struct SceneKitView: UIViewRepresentable {
    public let modelURL: URL
    public var isWireframe: Bool = false
    
    public init(modelURL: URL, isWireframe: Bool = false) {
        self.modelURL = modelURL
        self.isWireframe = isWireframe
    }
    
    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = loadScene(from: modelURL)
        scnView.scene = scene
        
        // Включаем нативное интерактивное управление камерой пальцами
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor.systemBackground
        
        // Добавляем профессиональное трехточечное освещение
        setupLighting(in: scene)
        
        applyWireframe(scene: scene, wireframe: isWireframe)
        
        return scnView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {
        if let scene = uiView.scene {
            applyWireframe(scene: scene, wireframe: isWireframe)
        }
    }
    
    private func loadScene(from url: URL) -> SCNScene {
        if let scene = try? SCNScene(url: url, options: [
            .checkConsistency: true,
            .flattenScene: false
        ]) {
            // Центрируем геометрию в (0,0,0)
            centerSceneGeometry(scene: scene)
            return scene
        }
        
        // Запасная сцена, если файл еще формируется
        let fallback = SCNScene()
        let box = SCNBox(width: 0.3, height: 0.3, length: 0.3, chamferRadius: 0.03)
        box.firstMaterial?.diffuse.contents = UIColor.systemBlue
        let node = SCNNode(geometry: box)
        fallback.rootNode.addChildNode(node)
        return fallback
    }
    
    private func setupLighting(in scene: SCNScene) {
        // Фоновый мягкий свет
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 800
        ambientLight.color = UIColor.white
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // Направленный рисующий свет
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 1500
        keyLight.castsShadow = true
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.position = SCNVector3(1, 2, 2)
        keyNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyNode)
        
        // Заполняющий контурный свет
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
        var minVec = SCNVector3Zero
        var maxVec = SCNVector3Zero
        scene.rootNode.getBoundingBoxMin(&minVec, max: &maxVec)
        
        let centerX = (minVec.x + maxVec.x) / 2.0
        let centerY = (minVec.y + maxVec.y) / 2.0
        let centerZ = (minVec.z + maxVec.z) / 2.0
        
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
