import Foundation

public struct PlaylistItem: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let url: URL
    public var title: String
    public var durationMs: Int64
    public var artist: String?
    public var album: String?
    public var resolution: String?
    public var fileSizeBytes: Int64?
    public var lastPositionSeconds: Double?
    public let dateAdded: Date
    public var isNetworkStream: Bool
    public var group: String?
    public var logoURL: String?
    public var options: [String]
    
    public init(
        id: UUID = UUID(),
        url: URL,
        title: String? = nil,
        durationMs: Int64 = 0,
        artist: String? = nil,
        album: String? = nil,
        resolution: String? = nil,
        fileSizeBytes: Int64? = nil,
        lastPositionSeconds: Double? = nil,
        dateAdded: Date = Date(),
        isNetworkStream: Bool = false,
        group: String? = nil,
        logoURL: String? = nil,
        options: [String] = []
    ) {
        self.id = id
        self.url = url
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.durationMs = durationMs
        self.artist = artist
        self.album = album
        self.resolution = resolution
        self.fileSizeBytes = fileSizeBytes
        self.lastPositionSeconds = lastPositionSeconds
        self.dateAdded = dateAdded
        self.isNetworkStream = isNetworkStream || url.scheme == "http" || url.scheme == "https" || url.scheme == "rtsp" || url.scheme == "rtmp" || url.scheme == "udp"
        self.group = group
        self.logoURL = logoURL
        self.options = options
    }
    
    public var formattedDuration: String {
        guard durationMs > 0 else { return "--:--" }
        let totalSeconds = Int(durationMs / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    public var formattedFileSize: String {
        guard let bytes = fileSizeBytes, bytes > 0 else { return "Unknown size" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
