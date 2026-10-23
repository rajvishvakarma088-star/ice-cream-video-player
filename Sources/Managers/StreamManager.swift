import Foundation
import Combine

public struct StreamPreset: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let category: String
    public let urlString: String
    public let description: String
    public let badge: String
    
    public var url: URL? {
        URL(string: urlString)
    }
}

public class StreamManager: ObservableObject {
    public static let shared = StreamManager()
    
    @Published public var recentStreams: [String] = []
    @Published public var isConnecting: Bool = false
    @Published public var connectionStatus: String = "Ready"
    @Published public var lastError: String? = nil
    
    private let storageURL: URL
    
    public let presets: [StreamPreset] = [
        StreamPreset(
            name: "IPTV Global Channels (index.m3u)",
            category: "IPTV Live TV",
            urlString: "https://iptv-org.github.io/iptv/index.m3u",
            description: "Worldwide live television index with 8,000+ categorized channels",
            badge: "IPTV M3U"
        ),
        StreamPreset(
            name: "Big Buck Bunny (HLS Multi-Bitrate)",
            category: "Open Movies",
            urlString: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            description: "Blender Studio open animated comedy movie (Adaptive HLS 1080p/720p)",
            badge: "HLS 1080p"
        ),
        StreamPreset(
            name: "Tears of Steel (4K Sci-Fi Short)",
            category: "Open Movies",
            urlString: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8",
            description: "Blender VFX open movie set in dystopian Amsterdam (Adaptive HLS 4K)",
            badge: "4K HLS"
        ),
        StreamPreset(
            name: "Tears of Steel (Direct QuickTime MOV)",
            category: "Open Movies",
            urlString: "https://download.blender.org/demo/movies/ToS/tears_of_steel_720p.mov",
            description: "Direct official high-bitrate master from Blender Foundation archives",
            badge: "DIRECT"
        ),
        StreamPreset(
            name: "Akamai 24/7 Global Live Feed",
            category: "Live Streams",
            urlString: "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8",
            description: "Akamai CDN global live video stream test with multi-audio feeds",
            badge: "LIVE"
        ),
        StreamPreset(
            name: "Apple 16:9 Advanced Master Stream",
            category: "HLS / M3U8",
            urlString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
            description: "Official Apple multi-bitrate HLS adaptive test stream (16:9 widescreen)",
            badge: "APPLE HLS"
        ),
        StreamPreset(
            name: "Apple BipBop 4:3 Adaptive Stream",
            category: "HLS / M3U8",
            urlString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8",
            description: "Official Apple adaptive bitrate stream with multi-channel audio",
            badge: "HLS"
        ),
        StreamPreset(
            name: "SomaFM Groove Salad (Ambient / Chill)",
            category: "Live Audio",
            urlString: "https://ice1.somafm.com/groovesalad-128-mp3",
            description: "Downtempo electronic ambient live network radio from San Francisco",
            badge: "LIVE"
        ),
        StreamPreset(
            name: "SomaFM DEF CON Radio (Cyberpunk / Beats)",
            category: "Live Audio",
            urlString: "https://ice2.somafm.com/defcon-128-mp3",
            description: "Official hacker conference broadcast: downtempo, electro, darkwave",
            badge: "LIVE"
        ),
        StreamPreset(
            name: "SomaFM Drone Zone (Atmospheric Space)",
            category: "Live Audio",
            urlString: "https://ice4.somafm.com/dronezone-128-mp3",
            description: "Continuous peaceful ambient textures for focus and relaxation",
            badge: "LIVE"
        )
    ]
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDir = appSupport.appendingPathComponent("IceCreamPlayer", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.storageURL = appDir.appendingPathComponent("recent_streams.json")
        loadRecentStreams()
    }
    
    public func validateAndNormalizeURL(_ input: String) -> URL? {
        var str = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.isEmpty { return nil }
        
        // Strip wrapping quotes or brackets
        if (str.hasPrefix("\"") && str.hasSuffix("\"")) || (str.hasPrefix("'") && str.hasSuffix("'")) {
            str = String(str.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if str.hasPrefix("<") && str.hasSuffix(">") {
            str = String(str.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Check for local file path
        if str.hasPrefix("/") {
            return URL(fileURLWithPath: str)
        }
        if str.lowercased().hasPrefix("file://") {
            let path = str.replacingOccurrences(of: "file://", with: "", options: .caseInsensitive)
            return URL(fileURLWithPath: path)
        }
        
        // Supported streaming protocols: http, https, rtsp, rtmp, mms, udp, rtp, ftp, sftp
        let supportedSchemes = ["http://", "https://", "rtsp://", "rtmp://", "mms://", "udp://", "rtp://", "ftp://", "sftp://"]
        let hasScheme = supportedSchemes.contains { str.lowercased().hasPrefix($0) }
        
        if !hasScheme {
            if !str.contains("://") {
                str = "https://" + str
            }
        }
        
        // 1. Direct URL initialization
        if let direct = URL(string: str) {
            return direct
        }
        
        // 2. Percent-encode path / query if unencoded characters or spaces are present
        if let encoded = str.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed.union(.urlQueryAllowed).union(.urlPathAllowed)),
           let url = URL(string: encoded) {
            return url
        }
        
        return nil
    }
    
    @discardableResult
    public func playStream(urlString: String, title: String? = nil, onReady: ((URL) -> Void)? = nil) -> Bool {
        guard let url = validateAndNormalizeURL(urlString) else {
            self.lastError = "Invalid stream URL. Please verify format (e.g. https://, rtsp://, or .m3u8)."
            self.connectionStatus = "Error: Invalid URL"
            return false
        }
        
        self.lastError = nil
        self.isConnecting = true
        self.connectionStatus = "Connecting to stream..."
        
        // Add to recent streams
        addToHistory(url.absoluteString)
        
        // Use PlaylistManager to start playing immediately
        PlaylistManager.shared.playImmediately(url: url, title: title ?? url.lastPathComponent)
        
        onReady?(url)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.isConnecting = false
            self?.connectionStatus = "Streaming active"
        }
        return true
    }
    
    public func addToHistory(_ urlString: String) {
        recentStreams.removeAll { $0 == urlString }
        recentStreams.insert(urlString, at: 0)
        if recentStreams.count > 30 {
            recentStreams.removeLast()
        }
        saveRecentStreams()
    }
    
    public func clearHistory() {
        recentStreams.removeAll()
        saveRecentStreams()
    }
    
    private func saveRecentStreams() {
        if let data = try? JSONEncoder().encode(recentStreams) {
            try? data.write(to: storageURL)
        }
    }
    
    private func loadRecentStreams() {
        if let data = try? Data(contentsOf: storageURL),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            self.recentStreams = list
        }
    }
}
