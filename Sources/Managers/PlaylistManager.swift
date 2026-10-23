import Foundation
import Combine

public enum RepeatMode: String, CaseIterable, Codable {
    case off = "Off"
    case repeatOne = "Repeat One"
    case repeatAll = "Repeat All"
}

public class PlaylistManager: ObservableObject {
    public static let shared = PlaylistManager()
    
    @Published public var items: [PlaylistItem] = []
    @Published public var currentIndex: Int? = nil
    @Published public var repeatMode: RepeatMode = .off
    @Published public var isShuffle: Bool = false
    
    // History & Bookmarks
    @Published public var historyItems: [PlaylistItem] = []
    @Published public var bookmarks: [BookmarkItem] = []
    
    // Resume Prompt state
    @Published public var resumePromptItem: PlaylistItem? = nil
    @Published public var resumePromptTimeMs: Int64 = 0
    
    private let player = VLCPlayerEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let playlistStorageURL: URL
    private let historyStorageURL: URL
    private let bookmarksStorageURL: URL
    private let resumePositionsURL: URL
    
    private var resumePositions: [String: Int64] = [:] // File URL string -> timestamp ms
    
    public var currentItem: PlaylistItem? {
        guard let idx = currentIndex, idx >= 0 && idx < items.count else { return nil }
        return items[idx]
    }
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDir = appSupport.appendingPathComponent("VLCPlayerApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        self.playlistStorageURL = appDir.appendingPathComponent("playlist.json")
        self.historyStorageURL = appDir.appendingPathComponent("history.json")
        self.bookmarksStorageURL = appDir.appendingPathComponent("bookmarks.json")
        self.resumePositionsURL = appDir.appendingPathComponent("resume_positions.json")
        
        loadAll()
        observePlayer()
    }
    
    // IPTV / Stream Loading State
    @Published public var isM3ULoading: Bool = false
    @Published public var m3uLoadingStatus: String = ""
    @Published public var availableGroups: [String] = []
    
    public func updateAvailableGroups() {
        let groups = Array(Set(items.compactMap { $0.group?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        self.availableGroups = groups
    }
    
    // Auto-skip state for offline channels
    private var consecutiveErrors: Int = 0
    private var isAutoSkipping: Bool = false
    
    // MARK: - Playback Coordination
    
    private func observePlayer() {
        player.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                if state == .ended {
                    self.handleItemEnded()
                } else if state == .error {
                    self.handleItemError()
                } else if state == .playing {
                    self.consecutiveErrors = 0
                    self.isAutoSkipping = false
                    if let current = self.currentItem {
                        if self.player.durationMs > 0 && current.durationMs != self.player.durationMs {
                            if let idx = self.currentIndex {
                                self.items[idx].durationMs = self.player.durationMs
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
            
        // Periodically store resume position
        player.$currentTimeMs
            .throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] time in
                guard let self = self, let current = self.currentItem, time > 3000 else { return }
                self.recordResumePosition(url: current.url, timeMs: time)
            }
            .store(in: &cancellables)
    }
    
    private func handleItemEnded() {
        switch repeatMode {
        case .repeatOne:
            if let idx = currentIndex {
                play(index: idx)
            }
        case .repeatAll:
            playNext(wrapAround: true)
        case .off:
            if let idx = currentIndex, idx < items.count - 1 {
                playNext(wrapAround: false)
            }
        }
    }
    
    private func handleItemError() {
        // If playing in a multi-channel IPTV playlist, automatically try next channel (like VLC Desktop)
        guard items.count > 1, !isAutoSkipping else { return }
        consecutiveErrors += 1
        if consecutiveErrors <= 5 {
            isAutoSkipping = true
            let deadTitle = currentItem?.title ?? "Channel"
            let nextIndex = ((currentIndex ?? 0) + 1) % items.count
            let nextTitle = items[nextIndex].title
            player.showStatusToast("⚠️ \(deadTitle) offline. Switching to \(nextTitle)...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self = self else { return }
                self.isAutoSkipping = false
                self.play(index: nextIndex)
            }
        } else {
            consecutiveErrors = 0
            player.showStatusToast("Please pick a channel from the Channel List")
        }
    }
    
    public func play(index: Int) {
        guard index >= 0 && index < items.count else { return }
        self.currentIndex = index
        let item = items[index]
        
        // Add to history
        recordHistory(item: item)
        
        // Check for saved resume position
        let savedPosition = resumePositions[item.url.absoluteString] ?? 0
        if savedPosition > 10000 && (item.durationMs == 0 || savedPosition < item.durationMs - 5000) {
            // Prompt resume
            self.resumePromptItem = item
            self.resumePromptTimeMs = savedPosition
            player.loadAndPlay(url: item.url, title: item.title, startTimeMs: 0, options: item.options)
        } else {
            player.loadAndPlay(url: item.url, title: item.title, startTimeMs: 0, options: item.options)
        }
    }
    
    public func confirmResume() {
        if let _ = resumePromptItem {
            player.seek(toMs: resumePromptTimeMs)
        }
        self.resumePromptItem = nil
    }
    
    public func dismissResume() {
        self.resumePromptItem = nil
    }
    
    public func play(item: PlaylistItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            play(index: idx)
        } else {
            items.append(item)
            play(index: items.count - 1)
            savePlaylist()
        }
    }
    
    // MARK: - M3U / IPTV Playlist Parser
    
    public func isM3U(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "m3u" || ext == "m3u8" {
            let str = url.absoluteString.lowercased()
            return ext == "m3u" || str.contains("iptv") || str.contains("playlist.m3u") || str.contains("channels")
        }
        return false
    }
    
    private func extractAttribute(from line: String, key: String) -> String? {
        guard let keyRange = line.range(of: "\(key)=\"") else { return nil }
        let rest = line[keyRange.upperBound...]
        guard let endQuote = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<endQuote])
    }
    
    public func parseM3UContent(_ text: String, baseURL: URL? = nil) -> [PlaylistItem] {
        var result: [PlaylistItem] = []
        var currentTitle: String? = nil
        var currentGroup: String? = nil
        var currentLogo: String? = nil
        var currentOptions: [String] = []
        
        let lines = text.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            
            if line.hasPrefix("#EXTINF:") {
                // e.g. #EXTINF:-1 tvg-id="..." tvg-logo="..." group-title="Movies",00s Replay
                currentGroup = extractAttribute(from: line, key: "group-title")
                currentLogo = extractAttribute(from: line, key: "tvg-logo")
                
                if let ua = extractAttribute(from: line, key: "http-user-agent") {
                    currentOptions.append(":http-user-agent=\(ua)")
                }
                if let ref = extractAttribute(from: line, key: "http-referrer") {
                    currentOptions.append(":http-referrer=\(ref)")
                }
                
                if let commaIdx = line.lastIndex(of: ",") {
                    let channelName = String(line[line.index(after: commaIdx)...]).trimmingCharacters(in: .whitespaces)
                    if !channelName.isEmpty {
                        currentTitle = channelName
                    }
                }
            } else if line.hasPrefix("#EXTVLCOPT:") {
                let opt = String(line.dropFirst(11)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !opt.isEmpty {
                    currentOptions.append(":\(opt)")
                }
            } else if !line.hasPrefix("#") {
                // Channel stream URL
                var streamURLString = line
                if !streamURLString.contains("://"), let base = baseURL {
                    if let resolved = URL(string: streamURLString, relativeTo: base) {
                        streamURLString = resolved.absoluteString
                    }
                }
                
                if let streamURL = URL(string: streamURLString) {
                    let title = currentTitle ?? streamURL.deletingPathExtension().lastPathComponent
                    let item = PlaylistItem(
                        url: streamURL,
                        title: title,
                        group: currentGroup,
                        logoURL: currentLogo,
                        options: currentOptions
                    )
                    result.append(item)
                }
                
                currentTitle = nil
                currentGroup = nil
                currentLogo = nil
                currentOptions = []
            }
        }
        return result
    }
    
    public func loadM3UPlaylist(url: URL, completion: ((Bool, Int) -> Void)? = nil) {
        self.isM3ULoading = true
        self.m3uLoadingStatus = "Loading IPTV channel list..."
        
        if url.isFileURL {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                if let text = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .ascii)) {
                    let parsed = self.parseM3UContent(text, baseURL: url)
                    if !parsed.isEmpty {
                        DispatchQueue.main.async {
                            self.items = parsed
                            self.isM3ULoading = false
                            self.m3uLoadingStatus = "Loaded \(parsed.count) channels"
                            self.savePlaylist()
                            self.play(index: 0)
                            self.player.showStatusToast("Loaded IPTV Playlist: \(parsed.count) channels")
                            completion?(true, parsed.count)
                        }
                        return
                    }
                }
                DispatchQueue.main.async {
                    self.isM3ULoading = false
                    completion?(false, 0)
                }
            }
            return
        }
        
        // Remote M3U stream (e.g. https://iptv-org.github.io/iptv/index.m3u)
        self.m3uLoadingStatus = "Downloading IPTV master index (11,000+ channels)..."
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard let data = data,
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                DispatchQueue.main.async {
                    self.isM3ULoading = false
                    self.m3uLoadingStatus = "Failed to download IPTV channels"
                    completion?(false, 0)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.m3uLoadingStatus = "Parsing channels and categories..."
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let parsed = self.parseM3UContent(text, baseURL: url)
                guard !parsed.isEmpty else {
                    DispatchQueue.main.async {
                        self.isM3ULoading = false
                        self.m3uLoadingStatus = "No channels found in M3U file"
                        completion?(false, 0)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.items = parsed
                    self.updateAvailableGroups()
                    self.isM3ULoading = false
                    self.m3uLoadingStatus = "Ready (\(parsed.count) channels)"
                    self.savePlaylistAsync()
                    self.play(index: 0)
                    self.player.showStatusToast("Loaded IPTV Playlist (\(parsed.count) channels)")
                    completion?(true, parsed.count)
                }
            }
        }.resume()
    }
    
    private func savePlaylistAsync() {
        let itemsToSave = self.items
        let url = self.playlistStorageURL
        DispatchQueue.global(qos: .utility).async {
            // Save up to first 1000 items in persistent JSON to keep startup instantaneous
            let subset = Array(itemsToSave.prefix(1000))
            if let data = try? JSONEncoder().encode(subset) {
                try? data.write(to: url)
            }
        }
    }
    
    public func playImmediately(url: URL, title: String? = nil) {
        if isM3U(url: url) {
            loadM3UPlaylist(url: url) { [weak self] success, count in
                if !success {
                    self?.playSingleURL(url: url, title: title)
                }
            }
            return
        }
        playSingleURL(url: url, title: title)
    }
    
    private func playSingleURL(url: URL, title: String? = nil) {
        if let idx = items.firstIndex(where: { $0.url == url }) {
            play(index: idx)
        } else {
            let item = PlaylistItem(
                url: url,
                title: title ?? url.deletingPathExtension().lastPathComponent
            )
            items.insert(item, at: 0)
            play(index: 0)
            savePlaylist()
        }
    }
    
    public func playNext(wrapAround: Bool = true) {
        guard !items.isEmpty else { return }
        
        if isShuffle {
            let nextIdx = Int.random(in: 0..<items.count)
            play(index: nextIdx)
            return
        }
        
        let nextIdx = (currentIndex ?? -1) + 1
        if nextIdx < items.count {
            play(index: nextIdx)
        } else if wrapAround {
            play(index: 0)
        }
    }
    
    public func playPrevious() {
        guard !items.isEmpty else { return }
        
        // If current position is > 3 seconds, restart current track
        if player.currentTimeMs > 3000 {
            player.seek(toMs: 0)
            return
        }
        
        let prevIdx = (currentIndex ?? 0) - 1
        if prevIdx >= 0 {
            play(index: prevIdx)
        } else {
            play(index: items.count - 1)
        }
    }
    
    // MARK: - Queue Management
    
    public func add(urls: [URL]) {
        var newItems: [PlaylistItem] = []
        for url in urls {
            if isDirectory(url: url) {
                newItems.append(contentsOf: scanDirectory(url: url))
            } else {
                newItems.append(createPlaylistItem(for: url))
            }
        }
        
        guard !newItems.isEmpty else { return }
        let shouldAutoPlay = items.isEmpty
        items.append(contentsOf: newItems)
        savePlaylist()
        
        if shouldAutoPlay {
            play(index: 0)
        }
    }
    
    public func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        if let curr = currentIndex {
            if items.isEmpty {
                currentIndex = nil
                player.stop()
            } else if curr >= items.count {
                currentIndex = items.count - 1
            }
        }
        savePlaylist()
    }
    
    public func remove(item: PlaylistItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            remove(at: IndexSet(integer: idx))
        }
    }
    
    public func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        savePlaylist()
    }
    
    public func clear() {
        items.removeAll()
        currentIndex = nil
        player.stop()
        savePlaylist()
    }
    
    public func toggleShuffle() {
        isShuffle.toggle()
    }
    
    public func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .repeatAll
        case .repeatAll: repeatMode = .repeatOne
        case .repeatOne: repeatMode = .off
        }
    }
    
    // MARK: - Bookmarks
    
    public func addBookmark(title: String? = nil) {
        guard let current = currentItem else { return }
        let time = player.currentTimeMs
        let defaultTitle = "\(current.title) at \(formatTime(time))"
        let bookmark = BookmarkItem(mediaURL: current.url, title: title ?? defaultTitle, timeMs: time)
        bookmarks.insert(bookmark, at: 0)
        saveBookmarks()
    }
    
    public func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        saveBookmarks()
    }
    
    public func jumpToBookmark(_ bookmark: BookmarkItem) {
        if let current = currentItem, current.url == bookmark.mediaURL {
            player.seek(toMs: bookmark.timeMs)
        } else {
            // Find in playlist or load
            if let idx = items.firstIndex(where: { $0.url == bookmark.mediaURL }) {
                play(index: idx)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.player.seek(toMs: bookmark.timeMs)
                }
            } else {
                let item = createPlaylistItem(for: bookmark.mediaURL)
                items.append(item)
                play(index: items.count - 1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.player.seek(toMs: bookmark.timeMs)
                }
            }
        }
    }
    
    // MARK: - Helpers & File Scanning
    
    private func isDirectory(url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    private func scanDirectory(url: URL) -> [PlaylistItem] {
        var results: [PlaylistItem] = []
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if SupportedMediaFormats.isSupported(extension: ext) {
                results.append(createPlaylistItem(for: fileURL))
            }
        }
        return results
    }
    
    private func createPlaylistItem(for url: URL) -> PlaylistItem {
        var fileSize: Int64? = nil
        if url.isFileURL, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        }
        return PlaylistItem(
            url: url,
            title: url.deletingPathExtension().lastPathComponent,
            fileSizeBytes: fileSize
        )
    }
    
    private func recordHistory(item: PlaylistItem) {
        historyItems.removeAll { $0.url == item.url }
        historyItems.insert(item, at: 0)
        if historyItems.count > 50 {
            historyItems.removeLast()
        }
        saveHistory()
    }
    
    public func clearHistory() {
        historyItems.removeAll()
        saveHistory()
    }
    
    private func recordResumePosition(url: URL, timeMs: Int64) {
        resumePositions[url.absoluteString] = timeMs
        saveResumePositions()
    }
    
    private func formatTime(_ ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    // MARK: - Persistence
    
    private func savePlaylist() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: playlistStorageURL)
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(historyItems) {
            try? data.write(to: historyStorageURL)
        }
    }
    
    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            try? data.write(to: bookmarksStorageURL)
        }
    }
    
    private func saveResumePositions() {
        if let data = try? JSONEncoder().encode(resumePositions) {
            try? data.write(to: resumePositionsURL)
        }
    }
    
    private func loadAll() {
        if let data = try? Data(contentsOf: playlistStorageURL),
           let decoded = try? JSONDecoder().decode([PlaylistItem].self, from: data) {
            self.items = decoded
            self.updateAvailableGroups()
        }
        if let data = try? Data(contentsOf: historyStorageURL),
           let decoded = try? JSONDecoder().decode([PlaylistItem].self, from: data) {
            self.historyItems = decoded
        }
        if let data = try? Data(contentsOf: bookmarksStorageURL),
           let decoded = try? JSONDecoder().decode([BookmarkItem].self, from: data) {
            self.bookmarks = decoded
        }
        if let data = try? Data(contentsOf: resumePositionsURL),
           let decoded = try? JSONDecoder().decode([String: Int64].self, from: data) {
            self.resumePositions = decoded
        }
    }
}
