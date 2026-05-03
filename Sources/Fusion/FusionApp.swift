import SwiftUI

@main
struct FusionApp: App {
    @StateObject private var queueManager = QueueManager()

    var body: some Scene {
        WindowGroup("Queue") {
            ContentView()
                .environmentObject(queueManager)
                // Subler pencere boyutu: yaklaşık 480x500, minimum 380x250
                .frame(
                    minWidth:    380, idealWidth:  480, maxWidth:  900,
                    minHeight:   250, idealHeight: 500
                )
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    queueManager.handleDrop(providers: providers)
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add to Queue…") { queueManager.openFiles() }
                    .keyboardShortcut("o", modifiers: .command)
                Divider()
                Button("Remove Selected") { queueManager.removeSelected() }
                    .keyboardShortcut(.delete, modifiers: [])
                    .disabled(!queueManager.hasSelection)
                Button("Remove Completed Items") { queueManager.removeCompleted() }
                    .disabled(!queueManager.hasCompleted)
                Divider()
                Button("Reveal in Finder") { queueManager.revealSelected() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(!queueManager.hasSelection)
            }
            CommandMenu("Queue") {
                Button("Start") { queueManager.startProcessing() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(queueManager.isProcessing)
            }
        }
    }
}
