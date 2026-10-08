import SwiftUI
import UniformTypeIdentifiers

public struct ModelsGalleryView: View {
    @State private var models: [URL] = []
    @State private var isImporting = false
    @State private var showingInfo = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                if models.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                        
                        Text("3D Модели пока отсутствуют")
                            .font(.headline)
                        
                        Text("Вы можете выполнить сканирование предмета во вкладке «Сканер» или импортировать файл .obj / .usdz с компьютера.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: generateSampleModel) {
                            Label("Создать тестовую 3D модель", systemImage: "sparkles")
                                .font(.subheadline.bold())
                                .padding()
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(models, id: \.self) { url in
                        NavigationLink(destination: ModelDetailView(modelURL: url)) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.blue.opacity(0.12))
                                        .frame(width: 50, height: 50)
                                    Image(systemName: "cube.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text("\(url.pathExtension.uppercased()) • \(formattedDate(for: url))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteModel)
                }
            }
            .navigationTitle("3D Объекты")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isImporting = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear(perform: reloadModels)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    importFiles(urls: urls)
                case .failure(let error):
                    print("Import error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func reloadModels() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let contents = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.contentModificationDateKey]) {
            let filtered = contents.filter {
                ["usdz", "obj", "scn", "dae", "ply"].contains($0.pathExtension.lowercased())
            }
            models = filtered.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 > date2
            }
        }
    }
    
    private func deleteModel(at offsets: IndexSet) {
        for index in offsets {
            let target = models[index]
            try? FileManager.default.removeItem(at: target)
        }
        models.remove(atOffsets: offsets)
    }
    
    private func importFiles(urls: [URL]) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let dest = docs.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dest)
        }
        reloadModels()
    }
    
    private func generateSampleModel() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("Demo_Pyramid.obj")
        
        let pyramidObj = """
        # Demo 3D Pyramid
        v 0.0 0.3 0.0
        v -0.2 -0.2 0.2
        v 0.2 -0.2 0.2
        v 0.2 -0.2 -0.2
        v -0.2 -0.2 -0.2
        f 1 2 3
        f 1 3 4
        f 1 4 5
        f 1 5 2
        f 5 4 3 2
        """
        try? pyramidObj.write(to: dest, atomically: true, encoding: .utf8)
        reloadModels()
    }
    
    private func formattedDate(for url: URL) -> String {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attrs[.modificationDate] as? Date {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
        return ""
    }
}
