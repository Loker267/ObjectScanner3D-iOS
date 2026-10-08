import SwiftUI
import QuickLook

public struct ModelDetailView: View {
    public let modelURL: URL
    
    @State private var isWireframe = false
    @State private var showARQuickLook = false
    @State private var fileSizeString = ""
    
    public init(modelURL: URL) {
        self.modelURL = modelURL
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Окно интерактивного 3D просмотра
            ZStack(alignment: .topTrailing) {
                SceneKitView(modelURL: modelURL, isWireframe: isWireframe)
                    .edgesIgnoringSafeArea(.top)
                
                // Переключатель режима сетки (Wireframe)
                Button(action: {
                    withAnimation { isWireframe.toggle() }
                }) {
                    Label(
                        isWireframe ? "Текстура" : "Сетка",
                        systemImage: isWireframe ? "cube.fill" : "square.split.diagonal.2x2"
                    )
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
                .padding()
            }
            
            // Нижняя панель действий
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(modelURL.deletingPathExtension().lastPathComponent)
                            .font(.headline)
                            .lineLimit(1)
                        Text("Формат: \(modelURL.pathExtension.uppercased()) • \(fileSizeString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                HStack(spacing: 14) {
                    // Кнопка AR: Поставить в комнате
                    Button(action: {
                        showARQuickLook = true
                    }) {
                        Label("Посмотреть в AR", systemImage: "arkit")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    // Кнопка поделиться 3D файлом
                    ShareLink(item: modelURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 50)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle("3D Модель")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateFileSize()
        }
        .sheet(isPresented: $showARQuickLook) {
            QuickLookARController(url: modelURL)
        }
    }
    
    private func calculateFileSize() {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: modelURL.path),
           let size = attrs[.size] as? Int64 {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useMB, .useKB]
            bcf.countStyle = .file
            fileSizeString = bcf.string(fromByteCount: size)
        }
    }
}

// Контроллер Apple Quick Look для AR-размещения в комнате
struct QuickLookARController: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
    }
}
