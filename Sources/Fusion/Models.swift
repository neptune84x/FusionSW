import Foundation

enum JobStatus {
    case waiting, working, done
}

struct QueueItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var status: JobStatus = .waiting
    var filename: String { url.lastPathComponent }
}
