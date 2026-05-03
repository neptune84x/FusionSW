import SwiftUI

struct ContentView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Subler Tarzı Üst Panel (Header)
            HStack(spacing: 0) {
                Spacer()
                SublerActionButton(icon: "play.fill", label: "Start") {
                    queueManager.startProcessing()
                }
                SublerActionButton(icon: "gearshape", label: "Settings") {
                    showingSettings.toggle()
                }
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    SettingsView()
                }
                SublerActionButton(icon: "doc.badge.plus", label: "Add Item") {
                    queueManager.openFiles()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Dosya Listesi
            List(selection: $queueManager.selection) {
                ForEach(queueManager.items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: statusIcon(for: item.status))
                            .foregroundColor(statusColor(for: item.status))
                            .font(.system(size: 14, weight: .bold))
                        
                        Text(item.filename)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.secondary.opacity(0.6))
                            .font(.system(size: 12))
                    }
                    .padding(.vertical, 2)
                    .tag(item.id)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            
            // Subler Tarzı Alt Panel (Status & Progress)
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Text("\(queueManager.items.count) item in queue")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    Spacer()
                    // İlerleme çubuğu her zaman yerinde durur
                    ProgressView(value: queueManager.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                        .scaleEffect(x: 1, y: 0.5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.windowBackgroundColor))
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
        case .waiting: return .secondary.opacity(0.3)
        case .working: return .orange
        case .done: return .green
        }
    }
}

// Subler ikon+metin butonu
struct SublerActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10))
            }
            .frame(width: 55, height: 45)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.headline)
            Divider()
            Picker("Format", selection: $outputFormat) {
                Text("MKV").tag("mkv")
                Text("MP4").tag("mp4")
            }
            .pickerStyle(.segmented)
            
            Toggle("Convert Subtitles to SRT", isOn: $convertSrt)
            Toggle("Load External Subtitles", isOn: $loadExtSubs)
        }
        .padding()
        .frame(width: 220)
    }
}
