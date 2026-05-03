import SwiftUI

@main
struct FusionApp: App {
    @StateObject private var queueManager = QueueManager()

    var body: some Scene {
        WindowGroup("Queue") { // Pencere başlığı Subler gibi "Queue"
            ContentView()
                .environmentObject(queueManager)
                // Subler'ın standart dar-dikey pencere boyutu
                .frame(minWidth: 350, maxWidth: 500, minHeight: 450, maxHeight: 800)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    queueManager.handleDrop(providers: providers)
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: false)) // Başlığı gizle, sadece butonlar
    }
}
