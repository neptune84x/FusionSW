import SwiftUI

@main
struct FusionApp: App {
    @StateObject private var queueManager = QueueManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(queueManager)
                .frame(minWidth: 380, idealWidth: 420, maxWidth: 700,
                       minHeight: 250, idealHeight: 450)
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
                Button("Clear Completed") { queueManager.removeCompleted() }
            }
            CommandMenu("Queue") {
                Button("Start") { queueManager.startProcessing() }
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}
