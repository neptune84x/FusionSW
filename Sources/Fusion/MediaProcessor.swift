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
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (-1, error.localizedDescription)
        }
    }
    
    func cleanItalics(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "\\N", with: "\n").replacingOccurrences(of: "\\\\N", with: "\n")
        t = t.replacingOccurrences(of: "{\\i1}", with: "").replacingOccurrences(of: "{\\i0}", with: "")
        let regex = try? NSRegularExpression(pattern: "\\{[^\\}]*\\}")
        t = regex?.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: "") ?? t
        return "<i>\(t.trimmingCharacters(in: .whitespacesAndNewlines))</i>"
    }

    func assToSrt(assPath: URL, srtPath: URL) {
        guard let content = try? String(contentsOf: assPath, encoding: .utf8) else {
            runCommand(getBinPath("ffmpeg"), args: ["-y", "-i", assPath.path, srtPath.path])
            return
        }
        let lines = content.components(separatedBy: .newlines)
        var out = ""; var n = 1
        for line in lines where line.hasPrefix("Dialogue:") {
            let parts = line.components(separatedBy: ",")
            if parts.count < 10 { continue }
            let s_t = parts[1].replacingOccurrences(of: ".", with: ",") + "0"
            let e_t = parts[2].replacingOccurrences(of: ".", with: ",") + "0"
            var txt = parts[9...].joined(separator: ",").trimmingCharacters(in: .whitespaces)
            
            if parts[3].lowercased().contains("italic") || txt.contains("{\\i1}") {
                txt = cleanItalics(txt)
            } else {
                txt = txt.replacingOccurrences(of: "\\N", with: "\n")
                let regex = try? NSRegularExpression(pattern: "\\{[^\\}]*\\}")
                txt = regex?.stringByReplacingMatches(in: txt, range: NSRange(txt.startIndex..., in: txt), withTemplate: "").trimmingCharacters(in: .whitespaces) ?? txt
            }
            if !txt.isEmpty {
                out += "\(n)\n0\(s_t.dropLast()) --> 0\(e_t.dropLast())\n\(txt)\n\n"
                n += 1
            }
        }
        try? out.write(to: srtPath, atomically: true, encoding: .utf8)
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
        
        let (_, probeStr) = runCommand(ffprobe, args: ["-v", "quiet", "-print_format", "json", "-show_streams", "-show_chapters", inputURL.path])
        guard let probeData = probeStr.data(using: .utf8),
              let info = try? JSONSerialization.jsonObject(with: probeData) as? [String: Any] else { return }
        
        let streams = info["streams"] as? [[String: Any]] ?? []
        let chapters = info["chapters"] as? [[String: Any]] ?? []
        let hasAudio = streams.contains { ($0["codec_type"] as? String) == "audio" }
        let isHevc = streams.contains { ($0["codec_type"] as? String) == "video" && ($0["codec_name"] as? String) == "hevc" }
        let intSubs = streams.filter { ($0["codec_type"] as? String) == "subtitle" }
        
        let lMap = ["tr":"tur","en":"eng","ru":"rus","jp":"jpn","de":"ger","fr":"fra","es":"spa","it":"ita"]
        var cleaned: [[String: String]] = []
        
        for (i, sub) in intSubs.enumerated() {
            let tags = sub["tags"] as? [String: Any] ?? [:]
            let lang = tags["language"] as? String ?? "und"
            let mappedLang = lMap[lang] ?? lang
            let codec = sub["codec_name"] as? String ?? ""
            let index = sub["index"] as? Int ?? 0
            
            if outputFormat == "mp4" {
                let p = tmpDir.appendingPathComponent("int_\(i).srt")
                runCommand(ffmpeg, args: ["-y", "-i", inputURL.path, "-map", "0:\(index)", "-f", "srt", p.path])
                if let attr = try? fm.attributesOfItem(atPath: p.path), (attr[.size] as? Int64 ?? 0) > 0 {
                    let vp = p.path.replacingOccurrences(of: ".srt", with: ".vtt")
                    if let c = try? String(contentsOf: p, encoding: .utf8) {
                        try? ("WEBVTT\n\n" + c.replacingOccurrences(of: ",", with: ".")).write(toFile: vp, atomically: true, encoding: .utf8)
                        cleaned.append(["path": vp, "lang": mappedLang, "codec": "vtt"])
                    }
                }
            } else {
                if !convertSrt && (codec == "ass" || codec == "ssa") {
                    let p = tmpDir.appendingPathComponent("int_\(i).ass")
                    runCommand(ffmpeg, args: ["-y", "-i", inputURL.path, "-map", "0:\(index)", p.path])
                    if let attr = try? fm.attributesOfItem(atPath: p.path), (attr[.size] as? Int64 ?? 0) > 0 {
                        cleaned.append(["path": p.path, "lang": mappedLang, "codec": "ass"])
                    }
                } else {
                    let p = tmpDir.appendingPathComponent("int_\(i).srt")
                    runCommand(ffmpeg, args: ["-y", "-i", inputURL.path, "-map", "0:\(index)", "-f", "srt", p.path])
                    if let attr = try? fm.attributesOfItem(atPath: p.path), (attr[.size] as? Int64 ?? 0) > 0 {
                        cleaned.append(["path": p.path, "lang": mappedLang, "codec": "srt"])
                    }
                }
            }
        }
        
        if loadExtSubs {
            if let files = try? fm.contentsOfDirectory(atPath: baseDir.path) {
                let extFiles = files.filter { $0.hasPrefix(baseName) && ($0.lowercased().hasSuffix(".srt") || $0.lowercased().hasSuffix(".ass")) && $0 != inputURL.lastPathComponent }
                for fp in extFiles.sorted() {
                    let fullPath = baseDir.appendingPathComponent(fp)
                    let isAss = fp.lowercased().hasSuffix(".ass")
                    var lang = "und"
                    if let range = fp.range(of: "\\.([a-z]{2,3})\\.(srt|ass)$", options: .regularExpression) {
                        lang = String(fp[range]).components(separatedBy: ".")[1]
                    }
                    let mappedLang = lMap[lang] ?? lang
                    
                    if outputFormat == "mp4" {
                        let p = tmpDir.appendingPathComponent("ext_\(cleaned.count).srt")
                        if isAss { assToSrt(assPath: fullPath, srtPath: p) } else { try? fm.copyItem(at: fullPath, to: p) }
                        if let attr = try? fm.attributesOfItem(atPath: p.path), (attr[.size] as? Int64 ?? 0) > 0 {
                            let vp = p.path.replacingOccurrences(of: ".srt", with: ".vtt")
                            if let c = try? String(contentsOf: p, encoding: .utf8) {
                                try? ("WEBVTT\n\n" + c.replacingOccurrences(of: ",", with: ".")).write(toFile: vp, atomically: true, encoding: .utf8)
                                cleaned.append(["path": vp, "lang": mappedLang, "codec": "vtt"])
                            }
                        }
                    } else {
                        if isAss && !convertSrt {
                            let p = tmpDir.appendingPathComponent("ext_\(cleaned.count).ass")
                            try? fm.copyItem(at: fullPath, to: p)
                            cleaned.append(["path": p.path, "lang": mappedLang, "codec": "ass"])
                        } else {
                            let p = tmpDir.appendingPathComponent("ext_\(cleaned.count).srt")
                            if isAss { assToSrt(assPath: fullPath, srtPath: p) } else { try? fm.copyItem(at: fullPath, to: p) }
                            if let attr = try? fm.attributesOfItem(atPath: p.path), (attr[.size] as? Int64 ?? 0) > 0 {
                                cleaned.append(["path": p.path, "lang": mappedLang, "codec": "srt"])
                            }
                        }
                    }
                }
            }
        }
        
        let hasAss = cleaned.contains { $0["codec"] == "ass" }
        
        if outputFormat == "mp4" {
            let tmpMp4 = tmpDir.appendingPathComponent("video_pure.mp4").path
            var cmd = ["-y", "-i", inputURL.path, "-map", "0:v:0"]
            if hasAudio { cmd.append(contentsOf: ["-map", "0:a?"]) }
            cmd.append(contentsOf: ["-c", "copy", "-sn", "-map_metadata", "-1", "-movflags", "+faststart"])
            if isHevc { cmd.append(contentsOf: ["-tag:v", "hvc1"]) }
            cmd.append(tmpMp4)
            runCommand(ffmpeg, args: cmd)
            
            var box = ["-brand", "mp42", "-ab", "isom", "-new", "-tight", "-inter", "500"]
            box.append(contentsOf: ["-add", "\(tmpMp4)#video:forcesync:name="])
            if hasAudio { box.append(contentsOf: ["-add", "\(tmpMp4)#audio:name="]) }
            
            for (i, c) in cleaned.enumerated() {
                let dis = i > 0 ? ":disable" : ""
                box.append(contentsOf: ["-add", "\(c["path"]!):lang=\(c["lang"]!):group=2:name=\(dis)"])
            }
            if !chapters.isEmpty {
                let chapF = tmpDir.appendingPathComponent("chapters.txt").path
                var chapTxt = ""
                for c in chapters {
                    let s = Double(c["start_time"] as? String ?? "0") ?? 0
                    let t = (c["tags"] as? [String: Any])?["title"] as? String ?? "Chapter \(c["id"] ?? 0)"
                    let h = Int(s / 3600); let m = Int(s.truncatingRemainder(dividingBy: 3600) / 60); let sec = s.truncatingRemainder(dividingBy: 60)
                    chapTxt += String(format: "%02d:%02d:%06.3f %@\n", h, m, sec, t)
                }
                try? chapTxt.write(toFile: chapF, atomically: true, encoding: .utf8)
                box.append(contentsOf: ["-chap", chapF])
            }
            box.append(contentsOf: ["-ipod", outFile])
            runCommand(mp4box, args: box)
            
        } else {
            var fontList: [[String: String]] = []
            if hasAss && !convertSrt {
                let attStreams = streams.filter { ($0["codec_type"] as? String) == "attachment" }
                if !attStreams.isEmpty {
                    let fontDir = tmpDir.appendingPathComponent("fonts")
                    try? fm.createDirectory(at: fontDir, withIntermediateDirectories: true, attributes: nil)
                    runCommand(ffmpeg, args: ["-dump_attachment:t", "", "-i", inputURL.path, "-t", "0", "-f", "null", "-"], cwd: fontDir)
                    
                    for s in attStreams {
                        let tags = s["tags"] as? [String: Any] ?? [:]
                        let fname = tags["filename"] as? String ?? ""
                        let mtype = tags["mimetype"] as? String ?? "application/x-truetype-font"
                        if !fname.isEmpty {
                            let fpath = fontDir.appendingPathComponent(fname).path
                            if let attr = try? fm.attributesOfItem(atPath: fpath), (attr[.size] as? Int64 ?? 0) > 0 {
                                fontList.append(["path": fpath, "filename": fname, "mimetype": mtype])
                            }
                        }
                    }
                }
            }
            
            let tmpMkv = tmpDir.appendingPathComponent("stage1.mkv").path
            var cmd1 = ["-y", "-i", inputURL.path]
            for c in cleaned { cmd1.append(contentsOf: ["-i", c["path"]!]) }
            cmd1.append(contentsOf: ["-map", "0:v:0", "-map", "0:a?"])
            for (i, c) in cleaned.enumerated() {
                cmd1.append(contentsOf: ["-map", "\(i+1):0"])
                let codec = c["codec"] == "ass" ? "copy" : "subrip"
                cmd1.append(contentsOf: ["-c:s:\(i)", codec])
                cmd1.append(contentsOf: ["-metadata:s:s:\(i)", "language=\(c["lang"]!)"])
            }
            cmd1.append(contentsOf: ["-c:v", "copy", "-c:a", "copy", "-map_metadata", "-1", "-map_chapters", "-1", tmpMkv])
            runCommand(ffmpeg, args: cmd1)
            
            var cmd2 = ["-y", "-i", tmpMkv, "-i", inputURL.path, "-map", "0", "-c", "copy", "-map_metadata:g", "-1", "-map_chapters", "1"]
            for (idx, font) in fontList.enumerated() {
                cmd2.append(contentsOf: ["-attach", font["path"]!])
                cmd2.append(contentsOf: ["-metadata:s:t:\(idx)", "mimetype=\(font["mimetype"]!)"])
                cmd2.append(contentsOf: ["-metadata:s:t:\(idx)", "filename=\(font["filename"]!)"])
            }
            cmd2.append(outFile)
            runCommand(ffmpeg, args: cmd2)
        }
        
        try? fm.removeItem(at: tmpDir)
    }
}
