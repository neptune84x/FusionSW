import SwiftUI

struct ContentView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var showingSettings = false

    var body: some View {
        List(selection: $queueManager.selection) {
            ForEach(queueManager.items) { item in
                HStack(spacing: 10) {
                    Image(systemName: statusIcon(for: item.status))
                        .foregroundColor(statusColor(for: item.status))
                        .font(.system(size: 14))
                    Text(item.filename)
                        .font(.system(size: 13))
                    Spacer()
                }
                .padding(.vertical, 4)
                .tag(item.id)
            }
        }
        // Subler'daki gibi ardışık renkli satırlar
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { queueManager.startProcessing() }) {
                    Label("Start", systemImage: "play.fill")
                }
                Button(action: { showingSettings.toggle() }) {
                    Label("Settings", systemImage: "gearshape")
                }
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    SettingsView()
                }
                Button(action: { queueManager.openFiles() }) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("\(queueManager.items.count) item(s) in queue")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                if queueManager.progress > 0 && queueManager.progress < 1 {
                    ProgressView(value: queueManager.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                        .scaleEffect(x: 1, y: 0.8, anchor: .center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .top)
        }
    }
    
    func statusIcon(for status: JobStatus) -> String {
        switch status {
        case .waiting: return "circle"
        case .working: return "play.circle.fill"
        case .done: return "checkmark.circle.fill"
        }
    }

    func statusColor(for status: JobStatus) -> Color {
        switch status {
        case .waiting: return Color.gray.opacity(0.5)
        case .working: return Color.orange
        case .done: return Color.green
        }
    }
}

struct SettingsView: View {
    @AppStorage("output_format") var outputFormat: String = "mkv"
    @AppStorage("convert_srt") var convertSrt: Bool = true
    @AppStorage("load_ext_subs") var loadExtSubs: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Output Format:").font(.headline)
            Picker("", selection: $outputFormat) {
                Text("mkv").tag("mkv")
                Text("mp4").tag("mp4")
            }
            .pickerStyle(.segmented)
            
            if outputFormat == "mkv" {
                Toggle("Convert subtitles to SRT", isOn: $convertSrt)
            }
            Divider()
            Text("Subtitles:").font(.headline)
            Toggle("Load external subtitles", isOn: $loadExtSubs)
        }
        .padding()
        .frame(width: 250)
    }
}
