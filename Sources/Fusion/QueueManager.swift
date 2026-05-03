import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class QueueManager: ObservableObject {
    @Published var items: [QueueItem] = []
    @Published var selection = Set<UUID>()
    @Published var progress: Double = 0.0
    @Published var isProcessing = false

    // MARK: – File picking
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

    // MARK: – Drag & drop
    nonisolated func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                if let d = data as? Data, let url = URL(dataRepresentation: d, relativeTo: nil) {
                    Task { @MainActor in
                        if !self.items.contains(where: { $0.url == url }) {
                            self.items.append(QueueItem(url: url))
                        }
                    }
                }
            }
        }
        return true
    }

    // MARK: – Queue operations
    func removeSelected() {
        items.removeAll { selection.contains($0.id) }
        selection.removeAll()
        recalcProgress()
    }

    func removeSingle(id: UUID) {
        items.removeAll { $0.id == id }
        selection.remove(id)
        recalcProgress()
    }

    func removeCompleted() {
        items.removeAll { $0.status == .done || $0.status == .failed }
        recalcProgress()
    }

    func revealInFinder() {
        guard let id = selection.first,
              let item = items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    // MARK: – Processing
    func startProcessing() {
        guard !isProcessing else { return }
        guard items.contains(where: { $0.status == .waiting }) else { return }
        isProcessing = true
        recalcProgress()
        Task { await processNext() }
    }

    private func processNext() async {
        guard let index = items.firstIndex(where: { $0.status == .waiting }) else {
            isProcessing = false
            recalcProgress()
            return
        }

        items[index].status = .working
        let url = items[index].url
        recalcProgress()

        // Arka planda çalıştır, UI donmasın
        let success: Bool = await Task.detached(priority: .userInitiated) {
            let p = MediaProcessor(inputURL: url)
            return await p.run()
        }.value

        items[index].status = success ? .done : .failed
        recalcProgress()

        await processNext()
    }

    private func recalcProgress() {
        let total = items.count
        guard total > 0 else { progress = 0; return }
        let finished = items.filter { $0.status == .done || $0.status == .failed }.count
        progress = Double(finished) / Double(total)
    }
}
