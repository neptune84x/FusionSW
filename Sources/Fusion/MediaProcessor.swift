import Foundation

struct MediaProcessor {
    let inputURL: URL
    let outputFormat = UserDefaults.standard.string(forKey: "output_format") ?? "mkv"
    let convertSrt = UserDefaults.standard.bool(forKey: "convert_srt")
    let loadExtSubs = UserDefaults.standard.bool(forKey: "load_ext_subs")
    
    func getBinPath(_ name: String) -> String {
        return Bundle.main.url(forResource: name, withExtension: nil)?.path ?? "/usr/local/bin/\(name)"
    }
    
    @discardableResult
    func runCommand(_ launchPath: String, args: [String], cwd: URL? = nil) -> (Int32, String) {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = args
        if let cwd = cwd { task.currentDirectoryURL = cwd }
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    func run() async {
        let fm = FileManager.default
        let baseDir = inputURL.deletingLastPathComponent()
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let tmpDir = baseDir.appendingPathComponent("\(baseName).fusiontemp")
        
        try? fm.removeItem(at: tmpDir)
        try? fm.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
        
        let ffmpeg = getBinPath("ffmpeg")
        let ffprobe = getBinPath("ffprobe")
        let mp4box = getBinPath("mp4box")
        let ext = outputFormat == "mp4" ? "mp4" : "mkv"
        let outFile = baseDir.appendingPathComponent("\(baseName)_Fusion.\(ext)").path
        
        let (_, probeStr) = runCommand(ffprobe, args: ["-v", "quiet", "-print_format", "json", "-show_streams", inputURL.path])
        guard let probeData = probeStr.data(using: .utf8),
              let info = try? JSONSerialization.jsonObject(with: probeData) as? [String: Any],
              let streams = info["streams"] as? [[String: Any]] else { return }
        
        let audioStreams = streams.filter { ($0["codec_type"] as? String) == "audio" }
        let subtitleStreams = streams.filter { ($0["codec_type"] as? String) == "subtitle" }
        let isHevc = streams.contains { ($0["codec_type"] as? String) == "video" && ($0["codec_name"] as? String) == "hevc" }
        
        let lMap = ["tr":"tur","en":"eng","ru":"rus","jp":"jpn","de":"ger","fr":"fra","es":"spa","it":"ita"]
        var processedSubs: [[String: String]] = []
        
        // Altyazı İşleme (İtalik temizleme kaldırıldı, FFmpeg hallediyor)
        for (i, sub) in subtitleStreams.enumerated() {
            let tags = sub["tags"] as? [String: Any] ?? [:]
            let lang = (tags["language"] as? String) ?? "und"
            let index = sub["index"] as? Int ?? 0
            let p = tmpDir.appendingPathComponent("sub_\(i).srt")
            
            runCommand(ffmpeg, args: ["-y", "-i", inputURL.path, "-map", "0:\(index)", "-f", "srt", p.path])
            
            if outputFormat == "mp4" {
                let vp = p.path.replacingOccurrences(of: ".srt", with: ".vtt")
                if let c = try? String(contentsOf: p, encoding: .utf8) {
                    try? ("WEBVTT\n\n" + c.replacingOccurrences(of: ",", with: ".")).write(toFile: vp, atomically: true, encoding: .utf8)
                    processedSubs.append(["path": vp, "lang": lMap[lang] ?? lang])
                }
            } else {
                processedSubs.append(["path": p.path, "lang": lMap[lang] ?? lang])
            }
        }
        
        if outputFormat == "mp4" {
            // Video ve tüm sesleri ayırırken Dolby Vision ve Dil Kodlarını koru
            let tmpMp4 = tmpDir.appendingPathComponent("temp.mp4").path
            var ffArgs = ["-y", "-i", inputURL.path, "-map", "0:v:0"]
            
            // Tüm ses izlerini tek tek map'le (Karışıklığı önler)
            for i in 0..<audioStreams.count {
                ffArgs.append(contentsOf: ["-map", "0:a:\(i)"])
            }
            
            ffArgs.append(contentsOf: ["-c", "copy", "-map_metadata", "0", "-movflags", "+faststart", "-strict", "unofficial"])
            if isHevc { ffArgs.append(contentsOf: ["-tag:v", "hvc1"]) }
            ffArgs.append(tmpMp4)
            runCommand(ffmpeg, args: ffArgs)
            
            // MP4Box ile paketle
            var box = ["-brand", "mp42", "-new", "-add", "\(tmpMp4)#video:name="]
            
            // Sesleri dilleriyle ekle
            for (i, a) in audioStreams.enumerated() {
                let tags = a["tags"] as? [String: Any] ?? [:]
                let lang = lMap[(tags["language"] as? String) ?? "und"] ?? "und"
                box.append(contentsOf: ["-add", "\(tmpMp4)#audio:trackID=\(i+2):lang=\(lang):name="])
            }
            
            for sub in processedSubs {
                box.append(contentsOf: ["-add", "\(sub["path"]!):lang=\(sub["lang"]!):group=2"])
            }
            box.append(contentsOf: ["-ipod", outFile])
            runCommand(mp4box, args: box)
            
        } else {
            // MKV Çıktısı
            var mkvArgs = ["-y", "-i", inputURL.path]
            for s in processedSubs { mkvArgs.append(contentsOf: ["-i", s["path"]!]) }
            
            mkvArgs.append(contentsOf: ["-map", "0:v:0", "-map", "0:a?"])
            for i in 0..<processedSubs.count {
                mkvArgs.append(contentsOf: ["-map", "\(i+1):0", "-c:s:\(i)", "subrip"])
                mkvArgs.append(contentsOf: ["-metadata:s:s:\(i)", "language=\(processedSubs[i]["lang"]!)"])
            }
            mkvArgs.append(contentsOf: ["-c:v", "copy", "-c:a", "copy", "-map_metadata", "0", "-strict", "unofficial", outFile])
            runCommand(ffmpeg, args: mkvArgs)
        }
        try? fm.removeItem(at: tmpDir)
    }
}
