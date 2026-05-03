import Foundation

struct MediaProcessor {
    let inputURL: URL

    // UserDefaults'ı init anında oku (thread-safe)
    private let outputFormat: String
    private let convertSrt: Bool
    private let loadExtSubs: Bool

    init(inputURL: URL) {
        self.inputURL    = inputURL
        self.outputFormat = UserDefaults.standard.string(forKey: "output_format") ?? "mkv"
        self.convertSrt   = UserDefaults.standard.bool(forKey: "convert_srt")
        self.loadExtSubs  = UserDefaults.standard.bool(forKey: "load_ext_subs")
    }

    private func getBinPath(_ name: String) -> String {
        Bundle.main.url(forResource: name, withExtension: nil)?.path ?? "/usr/local/bin/\(name)"
    }

    @discardableResult
    private func runCommand(_ launchPath: String, args: [String], cwd: URL? = nil) -> (Int32, String) {
        let task = Process()
        task.launchPath = launchPath
        task.arguments  = args
        if let cwd = cwd { task.currentDirectoryURL = cwd }

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (-1, error.localizedDescription)
        }
    }

    private func fileHasContent(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0) ?? 0 > 0
    }

    // MARK: – Ana işlem (Bool: başarı/başarısız)
    func run() async -> Bool {
        let fm       = FileManager.default
        let baseDir  = inputURL.deletingLastPathComponent()
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let tmpDir   = baseDir.appendingPathComponent("\(baseName).fusiontemp")

        try? fm.removeItem(at: tmpDir)
        guard (try? fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)) != nil else { return false }

        let ffmpeg  = getBinPath("ffmpeg")
        let ffprobe = getBinPath("ffprobe")
        let mp4box  = getBinPath("mp4box")
        let ext     = outputFormat == "mp4" ? "mp4" : "mkv"
        let outFile = baseDir.appendingPathComponent("\(baseName)_Fusion.\(ext)").path

        // ── Probe ─────────────────────────────────────────────────────────────
        let (_, probeStr) = runCommand(ffprobe, args: [
            "-v", "quiet", "-print_format", "json",
            "-show_streams", "-show_chapters", inputURL.path
        ])
        guard
            let probeData = probeStr.data(using: .utf8),
            let info      = try? JSONSerialization.jsonObject(with: probeData) as? [String: Any]
        else { try? fm.removeItem(at: tmpDir); return false }

        let streams  = info["streams"]  as? [[String: Any]] ?? []
        let chapters = info["chapters"] as? [[String: Any]] ?? []

        // ── Stream sınıflandırma ───────────────────────────────────────────────
        let audioStreams = streams.filter { ($0["codec_type"] as? String) == "audio" }
        let isHevc      = streams.contains {
            ($0["codec_type"] as? String) == "video" && ($0["codec_name"] as? String) == "hevc"
        }
        let intSubs = streams.filter { ($0["codec_type"] as? String) == "subtitle" }

        // ── Dil haritası ──────────────────────────────────────────────────────
        let lMap: [String: String] = [
            "tr":"tur","en":"eng","ru":"rus","jp":"jpn",
            "de":"ger","fr":"fra","es":"spa","it":"ita",
            "zh":"zho","ko":"kor","ja":"jpn","ar":"ara","pt":"por"
        ]
        func mapped(_ raw: String) -> String { lMap[raw] ?? raw }

        // ── Altyazı hazırlama ──────────────────────────────────────────────────
        var cleaned: [[String: String]] = []

        for (i, sub) in intSubs.enumerated() {
            let tags  = sub["tags"] as? [String: Any] ?? [:]
            let lang  = ((tags["language"] ?? tags["LANGUAGE"]) as? String) ?? "und"
            let codec = sub["codec_name"] as? String ?? ""
            let index = sub["index"]      as? Int    ?? 0

            if outputFormat == "mp4" {
                let p = tmpDir.appendingPathComponent("int_\(i).srt")
                runCommand(ffmpeg, args: ["-y","-i",inputURL.path,"-map","0:\(index)","-f","srt",p.path])
                if fileHasContent(p), let c = try? String(contentsOf: p, encoding: .utf8) {
                    let vp = p.deletingPathExtension().appendingPathExtension("vtt").path
                    try? ("WEBVTT\n\n" + c.replacingOccurrences(of: ",", with: "."))
                        .write(toFile: vp, atomically: true, encoding: .utf8)
                    cleaned.append(["path": vp, "lang": mapped(lang), "codec": "vtt"])
                }
            } else {
                if !convertSrt && (codec == "ass" || codec == "ssa") {
                    let p = tmpDir.appendingPathComponent("int_\(i).ass")
                    runCommand(ffmpeg, args: ["-y","-i",inputURL.path,"-map","0:\(index)",p.path])
                    if fileHasContent(p) { cleaned.append(["path":p.path,"lang":mapped(lang),"codec":"ass"]) }
                } else {
                    let p = tmpDir.appendingPathComponent("int_\(i).srt")
                    runCommand(ffmpeg, args: ["-y","-i",inputURL.path,"-map","0:\(index)","-f","srt",p.path])
                    if fileHasContent(p) { cleaned.append(["path":p.path,"lang":mapped(lang),"codec":"srt"]) }
                }
            }
        }

        // Dış altyazılar
        if loadExtSubs, let files = try? fm.contentsOfDirectory(atPath: baseDir.path) {
            let extFiles = files.filter {
                $0.hasPrefix(baseName) &&
                ($0.lowercased().hasSuffix(".srt") || $0.lowercased().hasSuffix(".ass")) &&
                $0 != inputURL.lastPathComponent
            }.sorted()

            for fp in extFiles {
                let fullPath = baseDir.appendingPathComponent(fp)
                let isAss   = fp.lowercased().hasSuffix(".ass")
                var lang    = "und"
                if let r = fp.range(of: "\\.([a-z]{2,3})\\.(srt|ass)$", options: .regularExpression) {
                    lang = String(fp[r]).components(separatedBy: ".")[1]
                }

                if outputFormat == "mp4" {
                    let p = tmpDir.appendingPathComponent("ext_\(cleaned.count).srt")
                    if isAss { runCommand(ffmpeg, args: ["-y","-i",fullPath.path,"-f","srt",p.path]) }
                    else      { try? fm.copyItem(at: fullPath, to: p) }
                    if fileHasContent(p), let c = try? String(contentsOf: p, encoding: .utf8) {
                        let vp = p.deletingPathExtension().appendingPathExtension("vtt").path
                        try? ("WEBVTT\n\n" + c.replacingOccurrences(of: ",", with: "."))
                            .write(toFile: vp, atomically: true, encoding: .utf8)
                        cleaned.append(["path": vp, "lang": mapped(lang), "codec": "vtt"])
                    }
                } else {
                    if isAss && !convertSrt {
                        let p = tmpDir.appendingPathComponent("ext_\(cleaned.count).ass")
                        try? fm.copyItem(at: fullPath, to: p)
                        cleaned.append(["path":p.path,"lang":mapped(lang),"codec":"ass"])
                    } else {
                        let p = tmpDir.appendingPathComponent("ext_\(cleaned.count).srt")
                        if isAss { runCommand(ffmpeg, args: ["-y","-i",fullPath.path,"-f","srt",p.path]) }
                        else      { try? fm.copyItem(at: fullPath, to: p) }
                        if fileHasContent(p) { cleaned.append(["path":p.path,"lang":mapped(lang),"codec":"srt"]) }
                    }
                }
            }
        }

        let hasAss = cleaned.contains { $0["codec"] == "ass" }

        // ══════════════════════════════════════════════════════════════════════
        // MP4 ÇIKIŞI
        // ══════════════════════════════════════════════════════════════════════
        if outputFormat == "mp4" {
            let tmpMp4 = tmpDir.appendingPathComponent("video_pure.mp4").path

            // 1) ffmpeg: video + TÜM ses izlerini ayrı ayrı map et
            var cmd: [String] = ["-y", "-i", inputURL.path, "-map", "0:v:0"]
            for i in 0..<audioStreams.count {
                cmd += ["-map", "0:a:\(i)"]
            }
            cmd += [
                "-c", "copy", "-sn",
                "-map_metadata", "-1",
                "-map_metadata:s:v", "0:s:v",
                "-map_metadata:s:a", "0:s:a",
                "-movflags", "+faststart",
                "-strict", "unofficial"
            ]
            if isHevc { cmd += ["-tag:v", "hvc1"] }
            cmd.append(tmpMp4)
            let (ffStatus, _) = runCommand(ffmpeg, args: cmd)
            guard ffStatus == 0 else { try? fm.removeItem(at: tmpDir); return false }

            // 2) mp4box: video track
            var box: [String] = ["-brand","mp42","-ab","isom","-new","-tight","-inter","500"]
            box += ["-add", "\(tmpMp4)#video:forcesync:name="]

            // 3) mp4box: ses izleri — mp4box'ta track numarası 1'den başlar
            //    mp4box #audio:N sözdizimi: N = dosyadaki sıra (1-based)
            //    Ancak tmpMp4'te video track #1, sonraki her ses #2, #3... olacak
            //    Bu yüzden audio track'leri ayrı ayrı çıkarıp ekleyelim
            for (i, aStream) in audioStreams.enumerated() {
                let tags  = aStream["tags"] as? [String: Any] ?? [:]
                let lang  = ((tags["language"] ?? tags["LANGUAGE"]) as? String) ?? "und"
                // tmpMp4'te: track 1=video, track 2=audio#0, track 3=audio#1 ...
                let trackNum = i + 2
                box += ["-add", "\(tmpMp4)#trackID=\(trackNum):lang=\(mapped(lang)):name="]
            }

            // 4) mp4box: altyazılar
            for (i, c) in cleaned.enumerated() {
                let dis = i > 0 ? ":disable" : ""
                box += ["-add", "\(c["path"]!):lang=\(c["lang"]!):group=2:name=\(dis)"]
            }

            // 5) Bölümler
            if !chapters.isEmpty {
                let chapF = tmpDir.appendingPathComponent("chapters.txt").path
                var chapTxt = ""
                for c in chapters {
                    let s   = Double(c["start_time"] as? String ?? "0") ?? 0
                    let t   = (c["tags"] as? [String: Any])?["title"] as? String ?? "Chapter"
                    let h   = Int(s / 3600)
                    let m   = Int(s.truncatingRemainder(dividingBy: 3600) / 60)
                    let sec = s.truncatingRemainder(dividingBy: 60)
                    chapTxt += String(format: "%02d:%02d:%06.3f %@\n", h, m, sec, t)
                }
                try? chapTxt.write(toFile: chapF, atomically: true, encoding: .utf8)
                box += ["-chap", chapF]
            }
            box += ["-ipod", outFile]

            let (boxStatus, _) = runCommand(mp4box, args: box)
            try? fm.removeItem(at: tmpDir)
            return boxStatus == 0

        // ══════════════════════════════════════════════════════════════════════
        // MKV ÇIKIŞI
        // ══════════════════════════════════════════════════════════════════════
        } else {
            // Font çıkarma (ASS varsa)
            var fontList: [[String: String]] = []
            if hasAss && !convertSrt {
                let attStreams = streams.filter { ($0["codec_type"] as? String) == "attachment" }
                if !attStreams.isEmpty {
                    let fontDir = tmpDir.appendingPathComponent("fonts")
                    try? fm.createDirectory(at: fontDir, withIntermediateDirectories: true)
                    runCommand(ffmpeg, args: [
                        "-dump_attachment:t","","-i",inputURL.path,
                        "-t","0","-f","null","-"
                    ], cwd: fontDir)
                    for s in attStreams {
                        let tags  = s["tags"]  as? [String: Any] ?? [:]
                        let fname = tags["filename"] as? String ?? ""
                        let mtype = tags["mimetype"] as? String ?? "application/x-truetype-font"
                        guard !fname.isEmpty else { continue }
                        let fpath = fontDir.appendingPathComponent(fname).path
                        if (try? fm.attributesOfItem(atPath: fpath)[.size] as? Int64 ?? 0) ?? 0 > 0 {
                            fontList.append(["path":fpath,"filename":fname,"mimetype":mtype])
                        }
                    }
                }
            }

            let tmpMkv = tmpDir.appendingPathComponent("stage1.mkv").path

            // Aşama 1: video + TÜM ses + altyazılar
            var cmd1: [String] = ["-y", "-i", inputURL.path]
            for c in cleaned { cmd1 += ["-i", c["path"]!] }

            cmd1 += ["-map", "0:v:0"]
            for i in 0..<audioStreams.count {
                cmd1 += ["-map", "0:a:\(i)"]
            }
            for i in 0..<cleaned.count {
                cmd1 += ["-map", "\(i+1):0"]
            }

            // Codec ayarları
            cmd1 += ["-c:v","copy","-c:a","copy"]

            for (i, c) in cleaned.enumerated() {
                let codec = c["codec"] == "ass" ? "copy" : "subrip"
                cmd1 += ["-c:s:\(i)", codec]
                cmd1 += ["-metadata:s:s:\(i)", "language=\(c["lang"]!)"]
            }
            for (i, aStream) in audioStreams.enumerated() {
                let tags = aStream["tags"] as? [String: Any] ?? [:]
                let lang = ((tags["language"] ?? tags["LANGUAGE"]) as? String) ?? "und"
                cmd1 += ["-metadata:s:a:\(i)", "language=\(mapped(lang))"]
            }

            cmd1 += [
                "-map_metadata","-1",
                "-map_metadata:s:v","0:s:v",
                "-map_metadata:s:a","0:s:a",
                "-map_chapters","-1",
                "-strict","unofficial",
                tmpMkv
            ]
            let (s1, _) = runCommand(ffmpeg, args: cmd1)
            guard s1 == 0 else { try? fm.removeItem(at: tmpDir); return false }

            // Aşama 2: Bölümleri kaynak dosyadan al
            var cmd2: [String] = [
                "-y","-i",tmpMkv,"-i",inputURL.path,
                "-map","0","-c","copy",
                "-map_metadata:g","-1",
                "-map_chapters","1"
            ]
            for (idx, font) in fontList.enumerated() {
                cmd2 += ["-attach", font["path"]!]
                cmd2 += ["-metadata:s:t:\(idx)", "mimetype=\(font["mimetype"]!)"]
                cmd2 += ["-metadata:s:t:\(idx)", "filename=\(font["filename"]!)"]
            }
            cmd2.append(outFile)
            let (s2, _) = runCommand(ffmpeg, args: cmd2)
            try? fm.removeItem(at: tmpDir)
            return s2 == 0
        }
    }
}
