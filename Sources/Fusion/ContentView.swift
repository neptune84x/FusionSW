import SwiftUI

struct ContentView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Queue")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                
                ToolbarButton(icon: "play.fill", label: "Start") {
                    queueManager.startProcessing()
                }
                ToolbarButton(icon: "gearshape.fill", label: "Settings") {
                    showingSettings.toggle()
                }
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    SettingsView()
                }
                ToolbarButton(icon: "plus.circle.fill", label: "Add Item") {
                    queueManager.openFiles()
                }
            }
            .padding(.horizontal, 16).frame(height: 60)
            .background(Color(NSColor.windowBackgroundColor))
            Divider()
            
            // Queue List
            List(selection: $queueManager.selection) {
                ForEach(queueManager.items) { item in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(statusColor(for: item.status))
                            .frame(width: 10, height: 10)
                        Text(item.filename).font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.vertical, 4).tag(item.id)
                }
            }
            .listStyle(.inset)
            Divider()
            
            // Footer
            HStack {
                Text("\(queueManager.items.count) item(s) in queue.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                ProgressView(value: queueManager.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 130)
            }
            .padding(.horizontal, 16).frame(height: 30)
            .background(Color(NSColor.controlBackgroundColor))
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

struct ToolbarButton: View {
    let icon: String, label: String, action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16))
                Text(label).font(.system(size: 10))
            }
            .frame(width: 60, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        .padding().frame(width: 250)
    }
}
