import Foundation
import ARKit
import UIKit
import Combine

public class ARCaptureManager: NSObject, ObservableObject, ARSessionDelegate {
    public let session = ARSession()
    
    // Published свойства для UI
    @Published public var isScanning = false
    @Published public var capturedCount = 0
    @Published public var statusMessage = "Наведите на предмет и нажмите «Старт»"
    @Published public var trackingQualityText = "Ожидание"
    @Published public var currentPosition: SIMD3<Float> = .zero
    @Published public var lastSavedImage: UIImage?
    @Published public var currentSessionFolder: URL?
    @Published public var lastReconstructedModelURL: URL?
    
    // Настройки умного автоспуска (6DoF триггеры)
    public var autoTriggerEnabled = true
    public var minDistanceDelta: Float = 0.10 // 10 см перемещения камеры
    public var minAngleDelta: Float = 0.22    // ~12.6 градусов поворота
    
    private var lastCapturedTransform: simd_float4x4?
    private var lastCaptureTime: TimeInterval = 0
    private let minCaptureInterval: TimeInterval = 0.35 // Задержка между кадрами (защита от спама)
    
    private var poses: [CameraPose] = []
    private var pointCloudAccumulator: [SIMD3<Float>] = []
    private var ciContext = CIContext()
    private let colorCloudBuilder = ColoredPointCloudBuilder()
    
    override public init() {
        super.init()
        session.delegate = self
    }
    
    public func startSession() {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.isAutoFocusEnabled = true
        
        // Включаем обнаружение поверхностей для привязки центра объекта
        config.planeDetection = [.horizontal, .vertical]
        
        createNewSessionFolder()
        poses.removeAll()
        pointCloudAccumulator.removeAll()
        colorCloudBuilder.clear()
        capturedCount = 0
        lastCapturedTransform = nil
        isScanning = true
        
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        statusMessage = "Медленно обходите предмет по кругу"
    }
    
    public func pauseSession() {
        isScanning = false
        session.pause()
        statusMessage = "Сканирование приостановлено"
    }
    
    public func triggerManualCapture() {
        guard let currentFrame = session.currentFrame else { return }
        captureFrame(currentFrame, forced: true)
    }
    
    // MARK: - ARSessionDelegate
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let cam = frame.camera
        let pos = cam.transform.columns.3
        
        DispatchQueue.main.async {
            self.currentPosition = SIMD3<Float>(pos.x, pos.y, pos.z)
            self.updateTrackingQuality(state: cam.trackingState)
        }
        
        guard isScanning else { return }
        
        // Сбор облака опорных 3D-точек (VIO Feature Points)
        if let points = frame.rawFeaturePoints?.points {
            pointCloudAccumulator.append(contentsOf: points)
        }
        
        // Автоматический 6DoF триггер
        if autoTriggerEnabled {
            let now = frame.timestamp
            guard (now - lastCaptureTime) >= minCaptureInterval else { return }
            
            if let last = lastCapturedTransform {
                let dist = simd_distance(cam.transform.columns.3, last.columns.3)
                let angle = angleBetween(m1: last, m2: cam.transform)
                
                if dist >= minDistanceDelta || angle >= minAngleDelta {
                    captureFrame(frame, forced: false)
                }
            } else {
                // Первый опорный кадр
                captureFrame(frame, forced: false)
            }
        }
    }
    
    private func captureFrame(_ frame: ARFrame, forced: Bool) {
        guard let folder = currentSessionFolder else { return }
        
        lastCaptureTime = frame.timestamp
        lastCapturedTransform = frame.camera.transform
        
        let index = capturedCount + 1
        let fileName = String(format: "frame_%04d.jpg", index)
        let fileURL = folder.appendingPathComponent(fileName)
        
        let pixelBuffer = frame.capturedImage
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Конвертация буфера камеры в JPEG
        autoreleasepool {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            // Поворачиваем изображение согласно ориентации экрана
            let oriented = ciImage.oriented(.right)
            if let cgImage = ciContext.createCGImage(oriented, from: oriented.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                if let jpegData = uiImage.jpegData(compressionQuality: 0.88) {
                    try? jpegData.write(to: fileURL)
                }
                self.colorCloudBuilder.ingestFrame(frame: frame, image: uiImage)
                DispatchQueue.main.async {
                    self.lastSavedImage = uiImage
                }
            }
        }
        
        // Сохраняем 6DoF позу
        let pose = CameraPose(
            fileName: fileName,
            timestamp: frame.timestamp,
            transform: frame.camera.transform,
            intrinsics: frame.camera.intrinsics,
            width: width,
            height: height
        )
        poses.append(pose)
        
        DispatchQueue.main.async {
            self.capturedCount = index
            self.statusMessage = "Захвачено: \(index) ракурсов"
        }
    }
    
    // Экспорт манифеста и облака точек
    public func finishAndExportManifest() -> URL? {
        guard let folder = currentSessionFolder else { return nil }
        
        // 1. Сохраняем стандартный transforms.json (для NeRF / 3D Gaussian Splatting / COLMAP)
        if let first = poses.first {
            let flX = first.intrinsics[0][0]
            let flY = first.intrinsics[1][1]
            let cx = first.intrinsics[0][2]
            let cy = first.intrinsics[1][2]
            
            let frameItems = poses.map {
                ScanDatasetManifest.FrameItem(filePath: "./\($0.fileName)", transformMatrix: $0.transformMatrix)
            }
            
            let manifest = ScanDatasetManifest(
                cameraModel: "OPENCV",
                flX: flX,
                flY: flY,
                cx: cx,
                cy: cy,
                w: first.imageWidth,
                h: first.imageHeight,
                frames: frameItems
            )
            
            let jsonURL = folder.appendingPathComponent("transforms.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(manifest) {
                try? data.write(to: jsonURL)
            }
        }
        
        // 2. Экспортируем собранное цветное VIO-облако точек в стандартный .ply
        let plyURL = folder.appendingPathComponent("reconstructed_color_model.ply")
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let globalPly = docs.appendingPathComponent("\(folder.lastPathComponent).ply")
        colorCloudBuilder.exportColoredPLY(to: plyURL)
        colorCloudBuilder.exportColoredPLY(to: globalPly)
        
        // 3. Создаем также цветную 3D OBJ модель
        let objURL = folder.appendingPathComponent("reconstructed_mesh.obj")
        let globalObj = docs.appendingPathComponent("\(folder.lastPathComponent).obj")
        colorCloudBuilder.exportColoredOBJ(to: objURL)
        colorCloudBuilder.exportColoredOBJ(to: globalObj)
        
        DispatchQueue.main.async {
            self.lastReconstructedModelURL = globalPly
        }
        
        return folder
    }
    
    private func exportSparsePointCloudPLY(to url: URL) {
        guard !pointCloudAccumulator.isEmpty else { return }
        var header = "ply\nformat ascii 1.0\nelement vertex \(pointCloudAccumulator.count)\n"
        header += "property float x\nproperty float y\nproperty float z\nend_header\n"
        
        var body = ""
        for p in pointCloudAccumulator {
            body += "\(p.x) \(p.y) \(p.z)\n"
        }
        
        let full = header + body
        try? full.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func createNewSessionFolder() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let folderName = "Scan_\(formatter.string(from: Date()))"
        let folder = docs.appendingPathComponent(folderName)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.currentSessionFolder = folder
    }
    
    private func angleBetween(m1: simd_float4x4, m2: simd_float4x4) -> Float {
        let q1 = simd_quatf(m1)
        let q2 = simd_quatf(m2)
        let dot = simd_clamp(simd_dot(q1, q2), -1.0, 1.0)
        return abs(acos(dot)) * 2.0
    }
    
    private func updateTrackingQuality(state: ARCamera.TrackingState) {
        switch state {
        case .normal:
            self.trackingQualityText = "Отлично"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                self.trackingQualityText = "Слишком быстро"
            case .insufficientFeatures:
                self.trackingQualityText = "Мало текстур"
            case .initializing:
                self.trackingQualityText = "Калибровка..."
            case .relocalizing:
                self.trackingQualityText = "Поиск позиции..."
            @unknown default:
                self.trackingQualityText = "Ограничено"
            }
        case .notAvailable:
            self.trackingQualityText = "Недоступно"
        }
    }
}
