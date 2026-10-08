import Foundation
import simd

// Модель для сохранения 6DoF положения камеры (NeRF / Gaussian Splatting совместимый формат)
public struct CameraPose: Codable {
    public let fileName: String
    public let timestamp: Double
    public let position: [Float]         // [x, y, z] в метрах в реальном мире
    public let transformMatrix: [[Float]] // 4x4 матрица 6DoF (положение и ориентация)
    public let intrinsics: [[Float]]      // 3x3 матрица калибровки камеры
    public let imageWidth: Int
    public let imageHeight: Int
    
    public init(fileName: String,
                timestamp: Double,
                transform: simd_float4x4,
                intrinsics: simd_float3x3,
                width: Int,
                height: Int) {
        self.fileName = fileName
        self.timestamp = timestamp
        self.imageWidth = width
        self.imageHeight = height
        
        let pos = transform.columns.3
        self.position = [pos.x, pos.y, pos.z]
        
        // Преобразуем 4x4 simd в массив строк
        self.transformMatrix = [
            [transform.columns.0.x, transform.columns.1.x, transform.columns.2.x, transform.columns.3.x],
            [transform.columns.0.y, transform.columns.1.y, transform.columns.2.y, transform.columns.3.y],
            [transform.columns.0.z, transform.columns.1.z, transform.columns.2.z, transform.columns.3.z],
            [transform.columns.0.w, transform.columns.1.w, transform.columns.2.w, transform.columns.3.w]
        ]
        
        // Преобразуем 3x3 simd
        self.intrinsics = [
            [intrinsics.columns.0.x, intrinsics.columns.1.x, intrinsics.columns.2.x],
            [intrinsics.columns.0.y, intrinsics.columns.1.y, intrinsics.columns.2.y],
            [intrinsics.columns.0.z, intrinsics.columns.1.z, intrinsics.columns.2.z]
        ]
    }
}

// Корневой формат метаданных датасета для 3DGS / NeRF / COLMAP
public struct ScanDatasetManifest: Codable {
    public let cameraModel: String
    public let flX: Float
    public let flY: Float
    public let cx: Float
    public let cy: Float
    public let w: Int
    public let h: Int
    public let frames: [FrameItem]
    
    public struct FrameItem: Codable {
        public let filePath: String
        public let transformMatrix: [[Float]]
        
        enum CodingKeys: String, CodingKey {
            case filePath = "file_path"
            case transformMatrix = "transform_matrix"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case cameraModel = "camera_model"
        case flX = "fl_x"
        case flY = "fl_y"
        case cx = "cx"
        case cy = "cy"
        case w = "w"
        case h = "h"
        case frames = "frames"
    }
}
