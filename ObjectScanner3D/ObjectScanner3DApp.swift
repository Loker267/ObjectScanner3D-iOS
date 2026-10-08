import SwiftUI

@main
struct ObjectScanner3DApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                // 1. Вкладка умного 6DoF сканера
                CaptureView()
                    .tabItem {
                        Label("Сканер 6DoF", systemImage: "camera.viewfinder")
                    }
                
                // 2. Вкладка 3D Галереи и Просмотрщика
                ModelsGalleryView()
                    .tabItem {
                        Label("3D Объекты", systemImage: "cube.fill")
                    }
            }
            .accentColor(.blue)
        }
    }
}
