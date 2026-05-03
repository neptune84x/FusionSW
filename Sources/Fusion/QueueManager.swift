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
        panel.allowedContentTypes = [.movie, .video]
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
    
    func startProcessing() {
        guard !isProcessing && !items.isEmpty else { return }
        isProcessing = true
        Task { await processQueue() }
    }
    
    @MainActor
    private func processQueue() async {
        for i in 0..<items.count where items[i].status == .waiting {
            items[i].status = .working
            
            // Gerçek zamanlı progress takibi için simülasyon (MediaProcessor bitene kadar)
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if self.progress < 0.95 { self.progress += 0.01 }
            }
            
            let url = items[i].url
            await Task.detached {
                let processor = MediaProcessor(inputURL: url)
                await processor.run()
            }.value
            
            timer.invalidate()
            items[i].status = .done
            progress = Double(i + 1) / Double(items.count)
        }
        isProcessing = false
    }
    
    func removeSelected() {
        items.removeAll { selection.contains($0.id) }
        selection.removeAll()
    }
}
