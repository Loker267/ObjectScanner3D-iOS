import Foundation

public struct ScanSession: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let date: Date
    public let folderURL: URL
    public var photoCount: Int
    public var hasResultModel: Bool
    public var modelURL: URL?
    
    public init(id: String = UUID().uuidString,
                title: String,
                date: Date = Date(),
                folderURL: URL,
                photoCount: Int = 0,
                hasResultModel: Bool = false,
                modelURL: URL? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.folderURL = folderURL
        self.photoCount = photoCount
        self.hasResultModel = hasResultModel
        self.modelURL = modelURL
    }
}
