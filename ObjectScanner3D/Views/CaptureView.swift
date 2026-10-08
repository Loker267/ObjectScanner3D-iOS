import SwiftUI
import ARKit

struct ARCameraViewContainer: UIViewRepresentable {
    let session: ARSession
    
    func makeUIView(context: Context) -> ARSCNView {
        let scnView = ARSCNView(frame: .zero)
        scnView.session = session
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling4X
        return scnView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

public struct CaptureView: View {
    @StateObject private var captureManager = ARCaptureManager()
    
    @State private var isSharingSession = false
    @State private var exportedFolderURL: URL?
    @State private var showExportSuccess = false
    
    let haptic = UIImpactFeedbackGenerator(style: .medium)
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 1. Полноэкранный видоискатель ARKit
            ARCameraViewContainer(session: captureManager.session)
                .edgesIgnoringSafeArea(.all)
            
            // 2. Верхний HUD: Статус 6DoF и координаты
            VStack {
                HStack {
                    // Бейдж качества 6DoF
                    HStack(spacing: 6) {
                        Circle()
                            .fill(trackingQualityColor)
                            .frame(width: 10, height: 10)
                        Text("6DoF: \(captureManager.trackingQualityText)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    // Координаты камеры в пространстве (X, Y, Z)
                    Text(String(format: "X: %.2f Y: %.2f Z: %.2f",
                                captureManager.currentPosition.x,
                                captureManager.currentPosition.y,
                                captureManager.currentPosition.z))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 48)
                
                // Главная подсказка пользователю
                Text(captureManager.statusMessage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(20)
                    .padding(.top, 4)
                
                Spacer()
                
                // 3. Нижняя панель управления
                VStack(spacing: 16) {
                    // Переключатель автозахвата
                    HStack {
                        Toggle(isOn: $captureManager.autoTriggerEnabled) {
                            Text("Умный автоспуск (6DoF)")
                                .font(.footnote.bold())
                                .foregroundColor(.white)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .frame(maxWidth: 220)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
                    
                    // Кнопки управления съемкой
                    HStack(spacing: 24) {
                        // Превью последнего кадра
                        Group {
                            if let img = captureManager.lastSavedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 54, height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 54, height: 54)
                            }
                        }
                        
                        // Главная кнопка Старт / Пауза
                        Button(action: {
                            haptic.impactOccurred()
                            if captureManager.isScanning {
                                captureManager.pauseSession()
                            } else {
                                captureManager.startSession()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 76, height: 76)
                                
                                Circle()
                                    .fill(captureManager.isScanning ? Color.red : Color.green)
                                    .frame(width: 62, height: 62)
                                
                                Image(systemName: captureManager.isScanning ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Кнопка ручного кадра (если нужно дофоткать сложный ракурс)
                        Button(action: {
                            haptic.impactOccurred()
                            captureManager.triggerManualCapture()
                        }) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 54, height: 54)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Circle())
                        }
                        .disabled(!captureManager.isScanning)
                        .opacity(captureManager.isScanning ? 1.0 : 0.4)
                    }
                    
                    // Кнопка «Завершить и сгенерировать 3D»
                    if captureManager.capturedCount > 0 {
                        Button(action: finishScan) {
                            HStack {
                                Image(systemName: "cube.box.fill")
                                Text("Завершить скан (\(captureManager.capturedCount) кадров)")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $isSharingSession) {
            if let folder = exportedFolderURL {
                ScanExportSheet(folderURL: folder, count: captureManager.capturedCount)
            }
        }
    }
    
    private var trackingQualityColor: Color {
        switch captureManager.trackingQualityText {
        case "Отлично": return .green
        case "Слишком быстро", "Мало текстур": return .orange
        default: return .yellow
        }
    }
    
    private func finishScan() {
        haptic.impactOccurred()
        captureManager.pauseSession()
        exportedFolderURL = captureManager.finishAndExportManifest()
        isSharingSession = true
    }
}

// Экран успешного экспорта сессии
struct ScanExportSheet: View {
    let folderURL: URL
    let count: Int
    @Environment(\.dismiss) private var dismiss
    @State private var isSharingFolder = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                Text("Сканирование завершено!")
                    .font(.title2.bold())
                
                Text("Захвачено \(count) ракурсов с точными 6DoF-матрицами камеры. Метаданные сохранены в transforms.json.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    // Поделиться папкой датасета
                    Button(action: {
                        isSharingFolder = true
                    }) {
                        Label("Поделиться датасетом (AirDrop / ПК)", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isSharingFolder) {
                ActivityShareSheet(items: [folderURL])
            }
        }
    }
}

