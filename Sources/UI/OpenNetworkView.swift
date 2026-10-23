import SwiftUI
import AppKit

public struct OpenNetworkView: View {
    @ObservedObject var streamManager = StreamManager.shared
    @ObservedObject var playlist = PlaylistManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var urlInput: String = ""
    @State private var selectedTab: Int = 0 // 0 = Presets, 1 = History
    @State private var validationMessage: String? = nil
    
    var onPlay: ((URL) -> Void)?
    var onDismiss: () -> Void
    
    public init(onPlay: ((URL) -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.onPlay = onPlay
        self.onDismiss = onDismiss
    }
    
    private var isDark: Bool {
        switch themeManager.currentTheme {
        case .dark: return true
        case .light: return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }
    
    private var detectedProtocolBadge: (String, Color)? {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return nil }
        if trimmed.contains(".m3u8") {
            return ("HLS STREAM", AppleTheme.actionBlue)
        } else if trimmed.hasPrefix("rtsp://") {
            return ("RTSP LIVE", .purple)
        } else if trimmed.hasPrefix("rtmp://") {
            return ("RTMP FEED", .red)
        } else if trimmed.hasPrefix("udp://") || trimmed.hasPrefix("rtp://") {
            return ("MULTICAST", .orange)
        } else if trimmed.contains("somafm.com") || trimmed.hasSuffix(".mp3") || trimmed.hasSuffix(".aac") || trimmed.hasSuffix(".ogg") {
            return ("LIVE AUDIO", .green)
        } else if trimmed.hasPrefix("https://") {
            return ("SECURE HTTPS", AppleTheme.skyLinkBlue)
        } else if trimmed.hasPrefix("http://") {
            return ("DIRECT HTTP", AppleTheme.actionBlue)
        } else if trimmed.hasPrefix("file://") || trimmed.hasPrefix("/") {
            return ("LOCAL FILE", .gray)
        }
        return ("NETWORK URL", AppleTheme.actionBlue)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppleTheme.actionBlue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: AppleTheme.actionBlue.opacity(0.35), radius: 6, x: 0, y: 2)
                    
                    Image(systemName: "network")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Network Stream")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                    Text("Stream direct HLS (.m3u8), RTSP, RTMP, HTTP, HTTPS, or live audio feeds")
                        .font(.system(size: 11))
                        .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                }
                .buttonStyle(.plain)
                .applePressable()
            }
            
            // URL Input Field with live detection badge
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Stream Address / URL:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                    
                    Spacer()
                    
                    if let badge = detectedProtocolBadge {
                        HStack(spacing: 4) {
                            Circle().fill(badge.1).frame(width: 5, height: 5)
                            Text(badge.0)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(badge.1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badge.1.opacity(0.12))
                        .cornerRadius(4)
                        .transition(.opacity)
                    }
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundColor(AppleTheme.actionBlue)
                        .font(.system(size: 13))
                    
                    TextField("Enter https://, rtsp://, or HLS .m3u8 stream address...", text: $urlInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular))
                    
                    if !urlInput.isEmpty {
                        Button(action: { urlInput = "" }) {
                            Image(systemName: "multiply.circle.fill")
                                .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button("Paste") {
                        if let str = NSPasteboard.general.string(forType: .string) {
                            urlInput = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(10)
                .background(isDark ? AppleTheme.tile1 : Color.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppleTheme.actionBlue.opacity(urlInput.isEmpty ? 0.2 : 0.6), lineWidth: 1)
                )
            }
            
            // Error banner if any
            if let err = streamManager.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }
            
            // M3U Playlist Loading Banner
            if playlist.isM3ULoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(playlist.m3uLoadingStatus)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppleTheme.actionBlue)
                    Spacer()
                }
                .padding(8)
                .background(AppleTheme.actionBlue.opacity(0.1))
                .cornerRadius(6)
            }
            
            // Segmented Picker: Presets vs History
            Picker("", selection: $selectedTab) {
                Text("Sample Streams (\(streamManager.presets.count))").tag(0)
                Text("Recent Streams (\(streamManager.recentStreams.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            
            // Tab Content
            if selectedTab == 0 {
                presetsList
            } else {
                historyList
            }
            
            // Actions Row
            HStack(spacing: 12) {
                Button("Cancel", action: onDismiss)
                    .buttonStyle(.bordered)
                    .applePressable()
                
                Spacer()
                
                Button(action: handlePlayAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Start Streaming")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppleTheme.actionBlue)
                .applePressable()
                .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 540)
        .background(isDark ? AppleTheme.surfaceBlack : AppleTheme.parchment)
        .cornerRadius(14)
    }
    
    // MARK: - Presets List
    
    private var presetsList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 6) {
                ForEach(streamManager.presets) { preset in
                    Button(action: {
                        urlInput = preset.urlString
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: preset.badge.contains("AUDIO") || preset.badge.contains("LIVE") ? "antenna.radiowaves.left.and.right" : "play.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppleTheme.actionBlue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                                
                                Text(preset.description)
                                    .font(.system(size: 10))
                                    .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(preset.badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppleTheme.actionBlue))
                        }
                        .padding(9)
                        .background(isDark ? AppleTheme.tile2 : Color.white.opacity(0.8))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(urlInput == preset.urlString ? AppleTheme.actionBlue : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .applePressable()
                }
            }
        }
        .frame(maxHeight: 180)
    }
    
    // MARK: - History List
    
    private var historyList: some View {
        Group {
            if streamManager.recentStreams.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24))
                        .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                    Text("No recent stream history")
                        .font(.system(size: 12))
                        .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                }
                .frame(maxWidth: .infinity, maxHeight: 180)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 6) {
                        ForEach(streamManager.recentStreams, id: \.self) { stream in
                            Button(action: {
                                urlInput = stream
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppleTheme.actionBlue)
                                    
                                    Text(stream)
                                        .font(.system(size: 11))
                                        .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 10))
                                        .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                                }
                                .padding(8)
                                .background(isDark ? AppleTheme.tile2 : Color.white.opacity(0.8))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }
    
    // MARK: - Play Action Handler
    
    private func handlePlayAction() {
        guard let url = streamManager.validateAndNormalizeURL(urlInput) else {
            streamManager.lastError = "Invalid stream URL. Please verify address."
            return
        }
        
        streamManager.addToHistory(url.absoluteString)
        
        if playlist.isM3U(url: url) {
            playlist.loadM3UPlaylist(url: url) { success, count in
                DispatchQueue.main.async {
                    if success {
                        onPlay?(url)
                        onDismiss()
                    } else {
                        streamManager.playStream(urlString: url.absoluteString)
                        onPlay?(url)
                        onDismiss()
                    }
                }
            }
        } else {
            streamManager.playStream(urlString: url.absoluteString)
            onPlay?(url)
            onDismiss()
        }
    }
}
