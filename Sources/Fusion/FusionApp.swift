import SwiftUI

@main
struct FusionApp: App {
    @StateObject private var queueManager = QueueManager()
    @AppStorage("output_format") var outputFormat: String = "mkv"
    @AppStorage("convert_srt") var convertSrt: Bool = true
    @AppStorage("load_ext_subs") var loadExtSubs: Bool = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(queueManager)
                .frame(minWidth: 480, idealWidth: 560, minHeight: 300, idealHeight: 420)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    queueManager.handleDrop(providers: providers)
                }
        }
        .windowStyle(.hiddenTitleBar)
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
