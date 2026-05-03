import SwiftUI

@main
struct FusionApp: App {
    @StateObject private var queueManager = QueueManager()

    var body: some Scene {
        WindowGroup("Queue") {
            ContentView()
                .environmentObject(queueManager)
                .frame(
                    minWidth:   380, idealWidth: 440, maxWidth: 800,
                    minHeight:  200, idealHeight: 420
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
                Button("Remove Completed Items") { queueManager.removeCompleted() }
                Divider()
                Button("Reveal in Finder") { queueManager.revealInFinder() }
                    .keyboardShortcut("r", modifiers: .command)
            }
            CommandMenu("Queue") {
                Button("Start") { queueManager.startProcessing() }
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}
