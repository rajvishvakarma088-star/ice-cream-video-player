import Foundation

public struct BookmarkItem: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let mediaURL: URL
    public var title: String
    public let timeMs: Int64
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        mediaURL: URL,
        title: String,
        timeMs: Int64,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.mediaURL = mediaURL
        self.title = title
        self.timeMs = timeMs
        self.createdAt = createdAt
    }
    
    public var formattedTimestamp: String {
        let totalSeconds = Int(timeMs / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
