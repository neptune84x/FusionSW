import SwiftUI

struct ContentView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Subler Tarzı Üst Panel
            HStack(spacing: 0) {
                Spacer()
                SublerButton(icon: "play.fill", label: "Start") {
                    queueManager.startProcessing()
                }
                SublerButton(icon: "gearshape", label: "Settings") {
                    showingSettings.toggle()
                }
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    SettingsView()
                }
                SublerButton(icon: "doc.badge.plus", label: "Add Item") {
                    queueManager.openFiles()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Subler Tarzı Liste
            List(selection: $queueManager.selection) {
                ForEach(queueManager.items) { item in
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon(for: item.status))
                            .foregroundColor(statusColor(for: item.status))
                            .font(.system(size: 14, weight: .bold))
                        
                        Text(item.filename)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Küçük bilgi ikonu (Subler'daki gibi)
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .padding(.vertical, 2)
                    .tag(item.id)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            
            // Alt Bilgi Barı ve Progress
            VStack(spacing: 4) {
                Divider()
                HStack {
                    Text("\(queueManager.items.count) item in queue")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    Spacer()
                    // Progress her zaman görünür, işlem yoksa %0
                    ProgressView(value: queueManager.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                        .scaleEffect(x: 1, y: 0.5)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .padding(.top, 4)
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
        case .waiting: return .secondary.opacity(0.4)
        case .working: return .orange
        case .done: return .green
        }
    }
}

// Subler'ın ikon altı metin tasarımlı butonu
struct SublerButton: View {
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
            
            if outputFormat == "mkv" {
                Toggle("Convert ASS to SRT", isOn: $convertSrt)
            }
            Toggle("Load External Subs", isOn: $loadExtSubs)
        }
        .padding()
        .frame(width: 220)
    }
}
