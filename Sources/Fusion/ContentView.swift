import SwiftUI

struct ContentView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var showingSettings = false

    var body: some View {
        List(selection: $queueManager.selection) {
            ForEach(queueManager.items) { item in
                HStack(spacing: 8) {
                    Image(systemName: statusIcon(for: item.status))
                        .foregroundColor(statusColor(for: item.status))
                        .font(.system(size: 13))
                        .frame(width: 16)
                    Text(item.filename)
                        .font(.system(size: 13))
                    Spacer()
                    if item.status == .working {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.vertical, 3)
                .tag(item.id)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { queueManager.startProcessing() }) {
                    Image(systemName: "play.fill")
                }
                .help("Start")
                .disabled(queueManager.isProcessing || queueManager.items.filter { $0.status == .waiting }.isEmpty)

                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    SettingsView()
                }

                Button(action: { queueManager.openFiles() }) {
                    Image(systemName: "doc.badge.plus")
                }
                .help("Add Item")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    if queueManager.isProcessing || (queueManager.progress > 0 && queueManager.progress < 1) {
                        ProgressView(value: queueManager.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 120)
                        Text("\(Int(queueManager.progress * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 32)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }

    var statusText: String {
        let total = queueManager.items.count
        let done = queueManager.items.filter { $0.status == .done }.count
        if queueManager.isProcessing {
            return "\(done)/\(total) item işleniyor…"
        }
        return "\(total) item\(total == 1 ? "" : "s") in queue"
    }

    func statusIcon(for status: JobStatus) -> String {
        switch status {
        case .waiting: return "circle"
        case .working: return "arrow.clockwise.circle.fill"
        case .done: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    func statusColor(for status: JobStatus) -> Color {
        switch status {
        case .waiting: return Color(NSColor.tertiaryLabelColor)
        case .working: return .orange
        case .done: return .green
        case .failed: return .red
        }
    }
}

struct SettingsView: View {
    @AppStorage("output_format") var outputFormat: String = "mkv"
    @AppStorage("convert_srt") var convertSrt: Bool = true
    @AppStorage("load_ext_subs") var loadExtSubs: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Output Format")
                .font(.headline)
            Picker("", selection: $outputFormat) {
                Text("MKV").tag("mkv")
                Text("MP4").tag("mp4")
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if outputFormat == "mkv" {
                Toggle("Convert subtitles to SRT", isOn: $convertSrt)
            }

            Divider()

            Text("Subtitles")
                .font(.headline)
            Toggle("Load external subtitles", isOn: $loadExtSubs)
        }
        .padding(16)
        .frame(width: 260)
    }
}
