import SwiftUI

struct ContentView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var showingSettings = false

    var body: some View {
        List(selection: $queueManager.selection) {
            ForEach(queueManager.items) { item in
                ItemRow(item: item)
                    .tag(item.id)
                    .contextMenu {
                        // Seçili item varsa
                        if queueManager.selection.contains(item.id) || queueManager.selection.isEmpty {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }
                            Divider()
                            Button("Remove from queue") {
                                if queueManager.selection.contains(item.id) {
                                    queueManager.removeSelected()
                                } else {
                                    queueManager.removeSingle(id: item.id)
                                }
                            }
                        }
                        Button("Remove completed items") {
                            queueManager.removeCompleted()
                        }
                        .disabled(!queueManager.items.contains(where: { $0.status == .done || $0.status == .failed }))
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .toolbar {
            // Subler gibi: simge üstte, metin altta — label kullan
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
                .help("Queue settings")
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
}

// MARK: – Satır görünümü
struct ItemRow: View {
    let item: QueueItem

    var body: some View {
        HStack(spacing: 8) {
            statusView
            Text(item.filename)
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .waiting:
            Image(systemName: "circle")
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .font(.system(size: 13))
                .frame(width: 16)
        case .working:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.55)
                .frame(width: 16, height: 16)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 13))
                .frame(width: 16)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 13))
                .frame(width: 16)
        }
    }
}

// MARK: – Alt status bar (Subler birebir: N item in queue | spinner)
struct StatusBar: View {
    let count: Int
    let isProcessing: Bool
    let progress: Double

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Text(count == 1 ? "1 item in queue" : "\(count) items in queue")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                if isProcessing {
                    // Subler'da sadece küçük dönen simge var, metin yok
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

// MARK: – Ayarlar popover (Subler'a benzer düzen)
struct SettingsView: View {
    @AppStorage("output_format") var outputFormat: String = "mkv"
    @AppStorage("convert_srt")   var convertSrt:   Bool   = true
    @AppStorage("load_ext_subs") var loadExtSubs:  Bool   = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Başlık satırı
            Text("Settings")
                .font(.headline)
                .padding(.bottom, 12)

            Group {
                Text("File Type")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Picker("", selection: $outputFormat) {
                    Text("MKV").tag("mkv")
                    Text("MP4").tag("mp4")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.bottom, 10)

                Divider().padding(.bottom, 10)

                Text("Subtitles")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Toggle("Load external subtitles", isOn: $loadExtSubs)
                    .padding(.top, 4)

                if outputFormat == "mkv" {
                    Toggle("Convert subtitles to SRT", isOn: $convertSrt)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
