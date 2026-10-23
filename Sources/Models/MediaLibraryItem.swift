import Foundation
import SwiftUI
import AppKit

public enum MediaType: String, Codable {
    case video = "Video"
    case audio = "Audio"
}

// MARK: - Supported Media Formats (Comprehensive LibVLC format catalog)
public struct SupportedMediaFormats {
    // Video Containers & Codecs: all requested + extended formats
    public static let videoExtensions: Set<String> = [
        "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v",
        "mpeg", "mpg", "m2v", "ts", "mts", "m2ts", "vob", "3gp",
        "3g2", "ogv", "divx", "rm", "rmvb", "asf", "dv", "yuv",
        "mpv", "mxf", "f4v", "h264", "h265", "hevc", "vlc", "iso",
        "wtv", "drc", "roq", "nsv"
    ]
    
    // Audio Containers & Codecs
    public static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "alac", "wav", "aiff", "aif",
        "ogg", "oga", "opus", "wma", "ac3", "dts", "mka", "ape",
        "mid", "midi", "ra", "ram", "voc"
    ]
    
    // Subtitle Formats
    public static let subtitleExtensions: Set<String> = [
        "srt", "vtt", "ass", "ssa", "sub", "smi", "idx"
    ]
    
    // All playable media formats
    public static let allMediaExtensions: Set<String> = videoExtensions.union(audioExtensions)
    
    public static func isAudio(extension ext: String) -> Bool {
        audioExtensions.contains(ext.lowercased())
    }
    
    public static func isVideo(extension ext: String) -> Bool {
        videoExtensions.contains(ext.lowercased())
    }
    
    public static func isSupported(extension ext: String) -> Bool {
        allMediaExtensions.contains(ext.lowercased())
    }
}

public struct MediaLibraryItem: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let url: URL
    public var title: String
    public var durationMs: Int64
    public var fileSizeBytes: Int64?
    public var resolutionBadge: String
    public var mediaType: MediaType
    public var dateAdded: Date
    public var isFavorite: Bool
    public var watchedProgress: Double // 0.0 to 1.0
    public var thumbnailFileName: String?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        durationMs: Int64 = 0,
        fileSizeBytes: Int64? = nil,
        resolutionBadge: String = "HD",
        mediaType: MediaType = .video,
        dateAdded: Date = Date(),
        isFavorite: Bool = false,
        watchedProgress: Double = 0.0,
        thumbnailFileName: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.durationMs = durationMs
        self.fileSizeBytes = fileSizeBytes
        self.resolutionBadge = resolutionBadge
        self.mediaType = mediaType
        self.dateAdded = dateAdded
        self.isFavorite = isFavorite
        self.watchedProgress = watchedProgress
        self.thumbnailFileName = thumbnailFileName
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
    
    public var fileExtension: String {
        url.pathExtension.uppercased()
    }
}
