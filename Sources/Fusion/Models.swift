import Foundation

enum JobStatus: Equatable {
    case waiting, working, done, failed
}

struct QueueItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var status: JobStatus = .waiting

    var filename: String { url.lastPathComponent }
}
