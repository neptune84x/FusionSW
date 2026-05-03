import SwiftUI

@main
struct FusionApp: App {
    @StateObject private var queueManager = QueueManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(queueManager)
                // Subler'ın tipik dikey ve dar Queue pencere boyutu
                .frame(minWidth: 420, maxWidth: 550, minHeight: 450, maxHeight: 900)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    queueManager.handleDrop(providers: providers)
                }
        }
        .windowStyle(.automatic)
        // Toolbar'ı tamamen kaldırıyoruz, içeriği ContentView içinde özel çizeceğiz
        .windowToolbarStyle(.unified(showsTitle: false)) 
    }
}
