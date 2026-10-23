import Foundation
import SwiftUI
import AppKit
import AVFoundation

public enum LibraryCategory: String, CaseIterable, Identifiable {
    case home = "Home"
    case videos = "Videos"
    case music = "Music"
    case playlists = "Playlists"
    case history = "History"
    case favorites = "Favorites"
    case streams = "Streams"
    case folders = "Folders"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .videos: return "play.rectangle.fill"
        case .music: return "music.note"
        case .playlists: return "list.bullet.rectangle.portrait.fill"
        case .history: return "clock.arrow.circlepath"
        case .favorites: return "heart.fill"
        case .streams: return "network"
        case .folders: return "folder.fill"
        }
    }
}

public enum LibrarySortOption: String, CaseIterable, Identifiable {
    case dateAdded = "Recently Added"
    case titleAZ = "Name (A-Z)"
    case duration = "Duration"
    case fileSize = "File Size"
    
    public var id: String { rawValue }
}

public enum LibraryFilterOption: String, CaseIterable, Identifiable {
    case all = "All"
    case fourK = "4K Ultra HD"
    case tenEighty = "1080p Full HD"
    case shortVideos = "Short (< 5 min)"
    case longVideos = "Long (> 20 min)"
    case unwatched = "Unwatched"
    
    public var id: String { rawValue }
}

public class MediaLibraryManager: ObservableObject {
    public static let shared = MediaLibraryManager()
    
    @Published public var items: [MediaLibraryItem] = []
    @Published public var watchedFolders: [URL] = []
    @Published public var selectedCategory: LibraryCategory = .home
    @Published public var selectedFolder: URL? = nil
    @Published public var searchQuery: String = ""
    @Published public var sortOption: LibrarySortOption = .dateAdded
    @Published public var filterOption: LibraryFilterOption = .all
    @Published public var isScanning: Bool = false
    @Published public var scanProgressText: String = ""
    @Published public var isGridView: Bool = true
    @Published public var gridCardWidth: CGFloat = 280 // 220 to 360
    
    // In-memory thumbnail cache
    private let memoryThumbnailCache = NSCache<NSString, NSImage>()
    
    private let thumbnailsDir: URL
    private let storageDir: URL
    private let libraryItemsURL: URL
    private let foldersURL: URL
    
    private let fileQueue = DispatchQueue(label: "org.icecream.medialibrary.scanner", qos: .userInitiated)
    private let thumbQueue = DispatchQueue(label: "org.icecream.medialibrary.thumbnails", qos: .utility)
    
    public init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.storageDir = appSupport.appendingPathComponent("IceCreamPlayer", isDirectory: true)
        try? fileManager.createDirectory(at: storageDir, withIntermediateDirectories: true)
        
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.thumbnailsDir = caches.appendingPathComponent("IceCreamPlayer/Thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
        
        self.libraryItemsURL = storageDir.appendingPathComponent("media_library.json")
        self.foldersURL = storageDir.appendingPathComponent("watched_folders.json")
        
        loadSavedData()
        
        // Auto-add standard Mac media folders (Downloads, Movies, Music, Desktop)
        let candidateFolders: [URL?] = [
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .musicDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
        ]
        
        for candidate in candidateFolders {
            if let folder = candidate, fileManager.fileExists(atPath: folder.path), !watchedFolders.contains(folder) {
                watchedFolders.append(folder)
            }
        }
        
        // Initial scan in background
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.scanAllWatchedFolders()
        }
    }
    
    // MARK: - Filtered & Sorted Items
    
    public var filteredItems: [MediaLibraryItem] {
        var result = items
        
        // Category filtering
        switch selectedCategory {
        case .home:
            break
        case .videos:
            result = result.filter { $0.mediaType == .video }
        case .music:
            result = result.filter { $0.mediaType == .audio }
        case .playlists:
            // Match items in current playlist
            let playlistUrls = Set(PlaylistManager.shared.items.map { $0.url })
            result = result.filter { playlistUrls.contains($0.url) }
        case .history:
            let historyUrls = Set(PlaylistManager.shared.historyItems.map { $0.url })
            result = result.filter { historyUrls.contains($0.url) }
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .streams:
            result = [] // Streams handled by StreamManager in view
        case .folders:
            if let folder = selectedFolder {
                result = result.filter { $0.url.path.hasPrefix(folder.path) }
            }
        }
        
        // Search query
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.fileExtension.lowercased().contains(query) ||
                $0.resolutionBadge.lowercased().contains(query)
            }
        }
        
        // Filter option
        switch filterOption {
        case .all:
            break
        case .fourK:
            result = result.filter { $0.resolutionBadge.contains("4K") }
        case .tenEighty:
            result = result.filter { $0.resolutionBadge.contains("1080p") }
        case .shortVideos:
            result = result.filter { $0.durationMs > 0 && $0.durationMs < 300_000 }
        case .longVideos:
            result = result.filter { $0.durationMs >= 1_200_000 }
        case .unwatched:
            result = result.filter { $0.watchedProgress < 0.05 }
        }
        
        // Sort option
        switch sortOption {
        case .dateAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .titleAZ:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .duration:
            result.sort { $0.durationMs > $1.durationMs }
        case .fileSize:
            result.sort { ($0.fileSizeBytes ?? 0) > ($1.fileSizeBytes ?? 0) }
        }
        
        return result
    }
    
    // MARK: - Folders & Scanning
    
    public func addFolder(url: URL) {
        guard !watchedFolders.contains(url) else { return }
        watchedFolders.append(url)
        saveWatchedFolders()
        scanFolder(url)
    }
    
    public func removeFolder(url: URL) {
        watchedFolders.removeAll { $0 == url }
        items.removeAll { $0.url.path.hasPrefix(url.path) }
        saveWatchedFolders()
        saveItems()
    }
    
    public func promptAddFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder containing movies or music for your Ice-Cream Player library:"
        panel.prompt = "Add to Library"
        
        if panel.runModal() == .OK, let url = panel.url {
            addFolder(url: url)
        }
    }
    
    public func promptGrantMacAccess() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.message = "Choose your user home directory to discover and index all video and audio files across your Mac:"
        panel.prompt = "Scan Entire Mac"
        
        if panel.runModal() == .OK, let url = panel.url {
            addFolder(url: url)
        }
    }
    
    public func promptImportFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audiovisualContent, .movie, .audio]
        panel.allowsOtherFileTypes = true
        panel.message = "Select media files to import into Ice-Cream Player:"
        panel.prompt = "Import"
        
        if panel.runModal() == .OK {
            importFiles(urls: panel.urls)
        }
    }
    
    public func importFiles(urls: [URL]) {
        fileQueue.async { [weak self] in
            guard let self = self else { return }
            var newItems: [MediaLibraryItem] = []
            for url in urls {
                if let item = self.inspectMediaFile(at: url) {
                    newItems.append(item)
                }
            }
            
            DispatchQueue.main.async {
                for item in newItems {
                    if let idx = self.items.firstIndex(where: { $0.url == item.url }) {
                        self.items[idx] = item
                    } else {
                        self.items.insert(item, at: 0)
                    }
                }
                self.saveItems()
                
                // Asynchronously generate thumbnails
                for item in newItems {
                    self.generateThumbnailIfNeeded(for: item)
                }
            }
        }
    }
    
    public func scanAllWatchedFolders() {
        guard !isScanning else { return }
        isScanning = true
        scanProgressText = "Scanning media folders..."
        
        fileQueue.async { [weak self] in
            guard let self = self else { return }
            var discovered: [MediaLibraryItem] = []
            
            for folder in self.watchedFolders {
                let found = self.crawlFolder(folder)
                discovered.append(contentsOf: found)
            }
            
            DispatchQueue.main.async {
                self.mergeDiscoveredItems(discovered)
                self.isScanning = false
                self.scanProgressText = ""
            }
        }
    }
    
    public func scanFolder(_ folder: URL) {
        fileQueue.async { [weak self] in
            guard let self = self else { return }
            let found = self.crawlFolder(folder)
            DispatchQueue.main.async {
                self.mergeDiscoveredItems(found)
            }
        }
    }
    
    private func crawlFolder(_ folder: URL) -> [MediaLibraryItem] {
        var results: [MediaLibraryItem] = []
        let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let path = fileURL.path
            // Skip noisy developer caches or OS system directories
            if path.contains("/Library/") || path.contains("/node_modules/") || path.contains("/.git/") || path.contains("/DerivedData/") || path.contains("/.Trash/") {
                continue
            }
            
            let ext = fileURL.pathExtension.lowercased()
            if SupportedMediaFormats.isSupported(extension: ext) {
                if let item = inspectMediaFile(at: fileURL) {
                    results.append(item)
                }
            }
        }
        return results
    }
    
    private func inspectMediaFile(at url: URL) -> MediaLibraryItem? {
        let ext = url.pathExtension.lowercased()
        let isAudio = SupportedMediaFormats.isAudio(extension: ext)
        let mediaType: MediaType = isAudio ? .audio : .video
        
        var size: Int64? = nil
        var modDate = Date()
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            size = attrs[.size] as? Int64
            if let d = attrs[.modificationDate] as? Date {
                modDate = d
            }
        }
        
        // Fast title
        let title = url.deletingPathExtension().lastPathComponent
        
        // Resolution and duration heuristics
        var resolutionBadge = isAudio ? "AUDIO" : "HD"
        let lowerPath = url.path.lowercased()
        if lowerPath.contains("4k") || lowerPath.contains("2160p") || lowerPath.contains("uhd") {
            resolutionBadge = "4K UHD"
        } else if lowerPath.contains("1080p") || lowerPath.contains("fhd") {
            resolutionBadge = "1080p"
        } else if lowerPath.contains("720p") {
            resolutionBadge = "720p"
        } else if isAudio {
            resolutionBadge = url.pathExtension.uppercased()
        }
        
        var durationMs: Int64 = 0
        
        // Quick probe using AVURLAsset without blocking
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        if !seconds.isNaN && seconds > 0 {
            durationMs = Int64(seconds * 1000)
            
            // Check video track resolution
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                let naturalSize = videoTrack.naturalSize
                let maxDimension = max(naturalSize.width, naturalSize.height)
                if maxDimension >= 3800 {
                    resolutionBadge = "4K UHD"
                } else if maxDimension >= 1900 {
                    resolutionBadge = "1080p"
                } else if maxDimension >= 1200 {
                    resolutionBadge = "720p"
                } else {
                    resolutionBadge = "SD"
                }
            }
        }
        
        let thumbName = "\(url.path.hashValue).jpg"
        
        return MediaLibraryItem(
            url: url,
            title: title,
            durationMs: durationMs,
            fileSizeBytes: size,
            resolutionBadge: resolutionBadge,
            mediaType: mediaType,
            dateAdded: modDate,
            isFavorite: false,
            watchedProgress: 0.0,
            thumbnailFileName: thumbName
        )
    }
    
    private func mergeDiscoveredItems(_ discovered: [MediaLibraryItem]) {
        for newItem in discovered {
            if let idx = items.firstIndex(where: { $0.url == newItem.url }) {
                // Preserve user progress & favorite status
                var existing = items[idx]
                if existing.durationMs == 0 && newItem.durationMs > 0 {
                    existing.durationMs = newItem.durationMs
                }
                existing.resolutionBadge = newItem.resolutionBadge
                items[idx] = existing
            } else {
                items.append(newItem)
                generateThumbnailIfNeeded(for: newItem)
            }
        }
        saveItems()
    }
    
    // MARK: - Thumbnail Generation & Caching
    
    public func getThumbnail(for item: MediaLibraryItem) -> NSImage? {
        let key = NSString(string: item.url.path)
        if let cached = memoryThumbnailCache.object(forKey: key) {
            return cached
        }
        
        // Check disk cache
        if let thumbName = item.thumbnailFileName {
            let diskURL = thumbnailsDir.appendingPathComponent(thumbName)
            if let diskImage = NSImage(contentsOf: diskURL) {
                memoryThumbnailCache.setObject(diskImage, forKey: key)
                return diskImage
            }
        }
        
        // Trigger async generator
        generateThumbnailIfNeeded(for: item)
        return nil
    }
    
    public func generateThumbnailIfNeeded(for item: MediaLibraryItem) {
        guard item.mediaType == .video else { return }
        
        let key = NSString(string: item.url.path)
        if memoryThumbnailCache.object(forKey: key) != nil { return }
        
        let thumbName = item.thumbnailFileName ?? "\(item.url.path.hashValue).jpg"
        let diskURL = thumbnailsDir.appendingPathComponent(thumbName)
        
        if FileManager.default.fileExists(atPath: diskURL.path) {
            if let diskImg = NSImage(contentsOf: diskURL) {
                memoryThumbnailCache.setObject(diskImg, forKey: key)
                return
            }
        }
        
        thumbQueue.async { [weak self] in
            guard let self = self else { return }
            let asset = AVAsset(url: item.url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 480, height: 270)
            
            // Capture at 10% of duration or 2 seconds
            let targetSec = min(5.0, max(1.0, CMTimeGetSeconds(asset.duration) * 0.1))
            let time = CMTime(seconds: targetSec, preferredTimescale: 600)
            
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                
                // Cache to memory
                self.memoryThumbnailCache.setObject(nsImage, forKey: key)
                
                // Cache to disk as JPEG
                if let tiff = nsImage.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                    try? jpegData.write(to: diskURL)
                }
                
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    // MARK: - Favorites & Watched Progress
    
    public func toggleFavorite(item: MediaLibraryItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isFavorite.toggle()
            saveItems()
        }
    }
    
    public func updateProgress(for url: URL, progress: Double) {
        if let idx = items.firstIndex(where: { $0.url == url }) {
            items[idx].watchedProgress = max(0.0, min(1.0, progress))
            saveItems()
        }
    }
    
    // MARK: - Persistence
    
    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: libraryItemsURL)
        }
    }
    
    private func saveWatchedFolders() {
        let paths = watchedFolders.map { $0.path }
        if let data = try? JSONEncoder().encode(paths) {
            try? data.write(to: foldersURL)
        }
    }
    
    private func loadSavedData() {
        if let data = try? Data(contentsOf: libraryItemsURL),
           let list = try? JSONDecoder().decode([MediaLibraryItem].self, from: data) {
            self.items = list
        }
        
        if let data = try? Data(contentsOf: foldersURL),
           let paths = try? JSONDecoder().decode([String].self, from: data) {
            self.watchedFolders = paths.map { URL(fileURLWithPath: $0) }
        }
    }
}
