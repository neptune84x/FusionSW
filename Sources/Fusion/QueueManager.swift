import Foundation
import SwiftUI
import UniformTypeIdentifiers

class QueueManager: ObservableObject {
    @Published var items: [QueueItem] = []
    @Published var selection = Set<UUID>()
    @Published var progress: Double = 0.0
    private var isProcessing = false
    
    func openFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .video, .audiovisualContent]
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !items.contains(where: { $0.url == url }) {
                    items.append(QueueItem(url: url))
                }
            }
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, _) in
                if let data = urlData as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        if !self.items.contains(where: { $0.url == url }) {
                            self.items.append(QueueItem(url: url))
                        }
                    }
                }
            }
        }
        return true
    }
    
    func removeSelected() {
        items.removeAll { selection.contains($0.id) }
        selection.removeAll()
    }
    func removeCompleted() { items.removeAll { $0.status == .done } }
    
    func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true; progress = 0.0
        Task { await processNext() }
    }
    
    @MainActor
    private func processNext() async {
        guard let index = items.firstIndex(where: { $0.status == .waiting }) else {
            isProcessing = false; return
        }
        
        items[index].status = .working
        let url = items[index].url
        
        // İşlemi arka planda (Task.detached) çalıştır
        await Task.detached {
            let processor = MediaProcessor(inputURL: url)
            await processor.run()
        }.value
        
        items[index].status = .done
        let doneCount = items.filter { $0.status == .done }.count
        progress = items.isEmpty ? 0 : Double(doneCount) / Double(items.count)
        
        await processNext()
    }
}
