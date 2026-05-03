import SwiftUI

struct ContentView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // Boş alan için arka plan tıklama alanı — context menu burada
            Color.clear
                .contentShape(Rectangle())
                .contextMenu { emptyAreaMenu }

            List(selection: $queueManager.selection) {
                ForEach(queueManager.items) { item in
                    ItemRow(item: item)
                        .tag(item.id)
                        .contextMenu { itemContextMenu(for: item) }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { queueManager.startProcessing() }) {
                    Label("Start", systemImage: "play.fill")
                }
                .help("Start processing queue")
                .disabled(queueManager.isProcessing ||
                          !queueManager.items.contains(where: { $0.status == .waiting }))

                Button(action: { showingSettings.toggle() }) {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings")
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    SettingsView()
                }

                Button(action: { queueManager.openFiles() }) {
                    Label("Add Item", systemImage: "doc.badge.plus")
                }
                .help("Add files to queue")
            }
        }
        .safeAreaInset(edge: .bottom) {
            StatusBar(
                count: queueManager.items.count,
                isProcessing: queueManager.isProcessing,
                progress: queueManager.progress
            )
        }
    }

    // MARK: – Boş alana tıklayınca çıkan menü
    @ViewBuilder
    private var emptyAreaMenu: some View {
        Button("Reveal in Finder") { queueManager.revealSelected() }
            .disabled(!queueManager.hasSelection)

        Divider()

        Button("Remove from queue") { queueManager.removeSelected() }
            .disabled(!queueManager.hasSelection)

        Button("Remove completed items") { queueManager.removeCompleted() }
            .disabled(!queueManager.hasCompleted)
    }

    // MARK: – Item üzerine sağ tıklayınca çıkan menü
    @ViewBuilder
    private func itemContextMenu(for item: QueueItem) -> some View {
        Button("Reveal in Finder") {
            if queueManager.selection.contains(item.id) {
                queueManager.revealSelected()
            } else {
                queueManager.revealItem(item)
            }
        }

        Divider()

        Button("Remove from queue") {
            if queueManager.selection.contains(item.id) {
                queueManager.removeSelected()
            } else {
                queueManager.removeSingle(id: item.id)
            }
        }

        Button("Remove completed items") { queueManager.removeCompleted() }
            .disabled(!queueManager.hasCompleted)
    }
}

// MARK: – Satır görünümü
struct ItemRow: View {
    let item: QueueItem

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            Text(item.filename)
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .waiting:
            Image(systemName: "circle")
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .font(.system(size: 13))
                .frame(width: 16, height: 16)
        case .working:
            // Küçük dönen NSProgressIndicator (spinning style)
            SpinnerView()
                .frame(width: 16, height: 16)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 13))
                .frame(width: 16, height: 16)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 13))
                .frame(width: 16, height: 16)
        }
    }
}

// MARK: – Native NSProgressIndicator spinner (satır içi)
struct SpinnerView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSProgressIndicator {
        let v = NSProgressIndicator()
        v.style = .spinning
        v.controlSize = .small
        v.isIndeterminate = true
        v.startAnimation(nil)
        return v
    }
    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {}
}

// MARK: – Alt status bar
// Subler birebir: "N item(s) in queue" solda, macOS native linear progress bar sağda
struct StatusBar: View {
    let count: Int
    let isProcessing: Bool
    let progress: Double

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Text(count == 1 ? "1 item in queue" : "\(count) items in queue")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                if isProcessing || (progress > 0 && progress < 1) {
                    // macOS native linear progress indicator — yazısız, rakamsız
                    LinearProgressView(value: progress)
                        .frame(width: 100, height: 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

// MARK: – Native NSProgressIndicator (linear, determinate)
struct LinearProgressView: NSViewRepresentable {
    let value: Double // 0.0 – 1.0

    func makeNSView(context: Context) -> NSProgressIndicator {
        let v = NSProgressIndicator()
        v.style = .bar
        v.isIndeterminate = false
        v.minValue = 0
        v.maxValue = 1
        v.doubleValue = value
        v.controlSize = .small
        return v
    }

    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {
        // Animate the change
        nsView.animator().doubleValue = value
    }
}

// MARK: – Settings popover
struct SettingsView: View {
    @AppStorage("output_format") var outputFormat: String = "mkv"
    @AppStorage("convert_srt")   var convertSrt:   Bool   = true
    @AppStorage("load_ext_subs") var loadExtSubs:  Bool   = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("File Type")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Picker("", selection: $outputFormat) {
                Text("MKV").tag("mkv")
                Text("MP4").tag("mp4")
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

            Text("Subtitles")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Toggle("Load external subtitles", isOn: $loadExtSubs)

            if outputFormat == "mkv" {
                Toggle("Convert subtitles to SRT", isOn: $convertSrt)
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}
