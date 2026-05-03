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
                // Subler benzeri dar ve dikey pencere boyutu
                .frame(minWidth: 400, idealWidth: 450, minHeight: 300, idealHeight: 500)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    queueManager.handleDrop(providers: providers)
                }
        }
        // Native macOS title bar ve toolbar görünümü
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
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
