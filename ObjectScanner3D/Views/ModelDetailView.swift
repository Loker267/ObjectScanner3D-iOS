import SwiftUI
import QuickLook

public struct ModelDetailView: View {
    public let modelURL: URL
    
    @State private var isWireframe = false
    @State private var zoomScale: Float = 1.0
    @State private var resetID = UUID()
    @State private var showARQuickLook = false
    @State private var isSharingFile = false
    @State private var fileSizeString = ""
    
    public init(modelURL: URL) {
        self.modelURL = modelURL
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Окно интерактивного 3D просмотра
            ZStack(alignment: .topTrailing) {
                SceneKitView(
                    modelURL: modelURL,
                    isWireframe: isWireframe,
                    zoomScale: zoomScale,
                    resetID: resetID
                )
                .edgesIgnoringSafeArea(.top)
                
                // Верхняя подсказка по жестам
                VStack {
                    HStack {
                        Label("👆 1 палец — 360° • 🤏 2 пальца — зум", systemImage: "hand.draw")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.leading, 12)
                    
                    Spacer()
                }
                
                // Правая плавающая панель управления (Зум, Режимы, Сброс)
                VStack(spacing: 12) {
                    // Переключатель Сетка / Текстура
                    Button(action: {
                        withAnimation { isWireframe.toggle() }
                    }) {
                        Image(systemName: isWireframe ? "cube.fill" : "square.split.diagonal.2x2")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                    
                    // Зум +
                    Button(action: {
                        withAnimation {
                            zoomScale = min(zoomScale + 0.3, 4.0)
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                    
                    // Зум -
                    Button(action: {
                        withAnimation {
                            zoomScale = max(zoomScale - 0.3, 0.4)
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                    
                    // Сбросить камеру и масштаб
                    Button(action: {
                        withAnimation {
                            zoomScale = 1.0
                            resetID = UUID()
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.top, 12)
                .padding(.trailing, 12)
            }
            
            // Нижняя панель действий
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(modelURL.deletingPathExtension().lastPathComponent)
                            .font(.headline)
                            .lineLimit(1)
                        Text("3D Mesh • \(modelURL.pathExtension.uppercased()) • \(fileSizeString) • Масштаб: \(String(format: "%.1fx", zoomScale))")
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
                    Button(action: {
                        isSharingFile = true
                    }) {
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
        .sheet(isPresented: $isSharingFile) {
            ActivityShareSheet(items: [modelURL])
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

// Универсальный диалог «Поделиться» (UIActivityViewController)
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
