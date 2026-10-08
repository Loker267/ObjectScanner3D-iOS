import Foundation
import ARKit
import SceneKit
import UIKit

public struct Colored3DPoint {
    public let position: SIMD3<Float>
    public let r: Float // 0.0 ... 1.0
    public let g: Float // 0.0 ... 1.0
    public let b: Float // 0.0 ... 1.0
}

public class ColoredPointCloudBuilder {
    private var voxelMap: [String: Colored3DPoint] = [:]
    private let voxelResolution: Float = 0.006 // 6 мм воксельная сетка для плотности
    
    public init() {}
    
    public func clear() {
        voxelMap.removeAll()
    }
    
    public var count: Int {
        return voxelMap.count
    }
    
    /// Захватывает 3D-точки из текущего кадра ARKit и считывает их реальный RGB-цвет с камеры
    public func ingestFrame(frame: ARFrame, image: UIImage) {
        guard let featurePoints = frame.rawFeaturePoints?.points, !featurePoints.isEmpty else { return }
        guard let cgImage = image.cgImage else { return }
        
        let imgWidth = cgImage.width
        let imgHeight = cgImage.height
        
        // Создаем контекст для быстрого чтения пикселей
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * imgWidth
        var rawData = [UInt8](repeating: 0, count: bytesPerRow * imgHeight)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: &rawData,
            width: imgWidth,
            height: imgHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
        
        let viewSize = CGSize(width: imgWidth, height: imgHeight)
        
        for p in featurePoints {
            // Проецируем 3D координаты в экранные пиксели камеры
            let projected = frame.camera.projectPoint(p, orientation: .portrait, viewportSize: viewSize)
            
            let px = Int(projected.x)
            let py = Int(projected.y)
            
            guard px >= 0 && px < imgWidth && py >= 0 && py < imgHeight else { continue }
            
            let byteIndex = (py * bytesPerRow) + (px * bytesPerPixel)
            let red = Float(rawData[byteIndex]) / 255.0
            let green = Float(rawData[byteIndex + 1]) / 255.0
            let blue = Float(rawData[byteIndex + 2]) / 255.0
            
            // Вокселизация для создания плотной структуры без дублей
            let vx = Int(floor(p.x / voxelResolution))
            let vy = Int(floor(p.y / voxelResolution))
            let vz = Int(floor(p.z / voxelResolution))
            let key = "\(vx)_\(vy)_\(vz)"
            
            if voxelMap[key] == nil {
                voxelMap[key] = Colored3DPoint(position: p, r: red, g: green, b: blue)
            }
        }
    }
    
    /// Экспорт в стандартный цветной PLY с RGB для каждой вершины
    public func exportColoredPLY(to url: URL) {
        let points = Array(voxelMap.values)
        guard !points.isEmpty else { return }
        
        // Центрируем точки относительно центра масс
        let centroid = points.reduce(SIMD3<Float>.zero) { $0 + $1.position } / Float(points.count)
        
        var header = "ply\nformat ascii 1.0\nelement vertex \(points.count)\n"
        header += "property float x\nproperty float y\nproperty float z\n"
        header += "property uchar red\nproperty uchar green\nproperty uchar blue\n"
        header += "end_header\n"
        
        var body = ""
        body.reserveCapacity(points.count * 45)
        
        for pt in points {
            let centered = pt.position - centroid
            let rByte = Int(clamping: Int(pt.r * 255.0))
            let gByte = Int(clamping: Int(pt.g * 255.0))
            let bByte = Int(clamping: Int(pt.b * 255.0))
            body += String(format: "%.5f %.5f %.5f %d %d %d\n", centered.x, centered.y, centered.z, rByte, gByte, bByte)
        }
        
        let full = header + body
        try? full.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Экспорт в стандартный цветной OBJ с RGB для каждой вершины (v x y z r g b)
    public func exportColoredOBJ(to url: URL) {
        let points = Array(voxelMap.values)
        guard !points.isEmpty else { return }
        
        let centroid = points.reduce(SIMD3<Float>.zero) { $0 + $1.position } / Float(points.count)
        
        var objText = "# ObjectScanner3D Real Colored 3D Mesh\n"
        objText += "# Vertices count: \(points.count)\n\n"
        
        for pt in points {
            let centered = pt.position - centroid
            objText += String(format: "v %.5f %.5f %.5f %.3f %.3f %.3f\n",
                              centered.x, centered.y, centered.z, pt.r, pt.g, pt.b)
        }
        
        // Создаем триангуляцию ближайших соседей для плотного отображения
        let n = points.count
        let maxEdge: Float = 0.08
        var triangles: [(Int, Int, Int)] = []
        
        let sampledIndices = stride(from: 0, to: n, by: max(1, n / 1200))
        let sampleList = Array(sampledIndices)
        
        for i in sampleList {
            var neighbors: [(idx: Int, dist: Float)] = []
            for j in sampleList where i != j {
                let d = simd_distance(points[i].position, points[j].position)
                if d <= maxEdge {
                    neighbors.append((idx: j, dist: d))
                }
            }
            neighbors.sort { $0.dist < $1.dist }
            let nearest = neighbors.prefix(3)
            if nearest.count >= 2 {
                triangles.append((i + 1, nearest[0].idx + 1, nearest[1].idx + 1))
            }
        }
        
        objText += "\n# Triangles\n"
        for t in triangles {
            objText += "f \(t.0) \(t.1) \(t.2)\n"
        }
        
        objText += "\n# Point elements\n"
        for i in 1...points.count {
            objText += "p \(i)\n"
        }
        
        try? objText.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Создает нативную цветную геометрию SceneKit напрямую из памяти
    public static func createColoredSCNNode(from plyURL: URL) -> SCNNode? {
        guard let content = try? String(contentsOf: plyURL, encoding: .utf8) else { return nil }
        
        var vertices: [SCNVector3] = []
        var colors: [SIMD4<Float>] = []
        
        var inHeader = true
        let lines = content.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if inHeader {
                if trimmed == "end_header" {
                    inHeader = false
                }
                continue
            }
            
            let parts = trimmed.components(separatedBy: " ")
            if parts.count >= 6,
               let x = Float(parts[0]), let y = Float(parts[1]), let z = Float(parts[2]),
               let r = Float(parts[3]), let g = Float(parts[4]), let b = Float(parts[5]) {
                vertices.append(SCNVector3(x, y, z))
                colors.append(SIMD4<Float>(r / 255.0, g / 255.0, b / 255.0, 1.0))
            }
        }
        
        guard !vertices.isEmpty else { return nil }
        
        let positionSource = SCNGeometrySource(vertices: vertices)
        
        var colorBytes = [Float]()
        colorBytes.reserveCapacity(colors.count * 4)
        for c in colors {
            colorBytes.append(c.x)
            colorBytes.append(c.y)
            colorBytes.append(c.z)
            colorBytes.append(c.w)
        }
        
        let colorData = colorBytes.withUnsafeBufferPointer { Data(buffer: $0) }
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        
        var indices = [Int32]()
        indices.reserveCapacity(vertices.count)
        for i in 0..<vertices.count {
            indices.append(Int32(i))
        }
        
        let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: vertices.count,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        element.pointSize = 10.0
        element.minimumPointScreenSpaceRadius = 4.0
        element.maximumPointScreenSpaceRadius = 24.0
        
        let geometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.isDoubleSided = true
        geometry.materials = [material]
        
        return SCNNode(geometry: geometry)
    }
}
