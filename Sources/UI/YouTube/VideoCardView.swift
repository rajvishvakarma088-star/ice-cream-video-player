import SwiftUI
import AppKit
import AVFoundation
import AVKit

// MARK: - Native Inline Video Preview Player

// MARK: - Native Inline Video Preview Player (AVPlayerLayer-based)

public class VideoPreviewNSView: NSView {
    private let playerLayer = AVPlayerLayer()
    
    public override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }
    
    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
    
    // Transparent to mouse hit-testing:
    // Scroll events, clicks, hovers pass directly to the parent ScrollView and SwiftUI gestures!
    public override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    public var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
}

public struct InlineVideoPreviewView: NSViewRepresentable {
    public let url: URL
    @Binding public var progress: Double
    @Binding public var isMuted: Bool
    
    public init(
        url: URL,
        progress: Binding<Double>,
        isMuted: Binding<Bool> = .constant(true)
    ) {
        self.url = url
        self._progress = progress
        self._isMuted = isMuted
    }
    
    public func makeNSView(context: Context) -> VideoPreviewNSView {
        let previewView = VideoPreviewNSView()
        
        let player = AVPlayer(url: url)
        player.isMuted = isMuted
        player.actionAtItemEnd = .none
        
        // Loop video preview
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        
        // Track playback progress
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        let observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
            guard let current = player?.currentItem else { return }
            let duration = current.duration.seconds
            if duration > 0 {
                self.progress = time.seconds / duration
            }
        }
        
        context.coordinator.player = player
        context.coordinator.timeObserver = observer
        previewView.player = player
        player.play()
        return previewView
    }
    
    public func updateNSView(_ nsView: VideoPreviewNSView, context: Context) {
        if let player = context.coordinator.player {
            if player.isMuted != isMuted {
                player.isMuted = isMuted
            }
        }
    }
    
    public static func dismantleNSView(_ nsView: VideoPreviewNSView, coordinator: Coordinator) {
        if let observer = coordinator.timeObserver {
            coordinator.player?.removeTimeObserver(observer)
        }
        coordinator.player?.pause()
        coordinator.player = nil
        nsView.player = nil
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator {
        var player: AVPlayer?
        var timeObserver: Any?
    }
}

// MARK: - Video Card View with Live Hover Preview

public struct VideoCardView: View {
    public let item: MediaLibraryItem
    public let isDark: Bool
    public let isListView: Bool
    public let onPlay: () -> Void
    public let onToggleFavorite: () -> Void
    
    @ObservedObject private var library = MediaLibraryManager.shared
    @State private var isHovered: Bool = false
    @State private var isPreviewActive: Bool = false
    @State private var isPreviewMuted: Bool = true
    @State private var previewProgress: Double = 0.0
    @State private var scrubFraction: Double? = nil
    @State private var hoverTimer: Timer?
    
    public init(
        item: MediaLibraryItem,
        isDark: Bool,
        isListView: Bool = false,
        onPlay: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void
    ) {
        self.item = item
        self.isDark = isDark
        self.isListView = isListView
        self.onPlay = onPlay
        self.onToggleFavorite = onToggleFavorite
    }
    
    public var body: some View {
        if isListView {
            listView
        } else {
            gridView
        }
    }
    
    // MARK: - Grid View Card
    
    private var gridView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail Container (16:9)
            ZStack(alignment: .bottomTrailing) {
                // If hover preview active on video, play inline preview!
                if isPreviewActive && item.mediaType == .video && item.url.isFileURL {
                    InlineVideoPreviewView(
                        url: item.url,
                        progress: $previewProgress,
                        isMuted: $isPreviewMuted
                    )
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12)
                } else {
                    thumbnailImage
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(12)
                }
                
                // Top Right Action Buttons (Preview badge & Audio button)
                VStack {
                    HStack {
                        Spacer()
                        if isPreviewActive {
                            HStack(spacing: 6) {
                                // Live Preview Indicator
                                HStack(spacing: 4) {
                                    Circle().fill(Color.red).frame(width: 6, height: 6)
                                    Text("PREVIEW")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.black.opacity(0.8)))
                                
                                // Interactive Audio Button in Preview
                                Button(action: {
                                    isPreviewMuted.toggle()
                                }) {
                                    Image(systemName: isPreviewMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color.black.opacity(0.85)))
                                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help(isPreviewMuted ? "Unmute preview audio" : "Mute preview audio")
                            }
                            .padding(8)
                        }
                    }
                    Spacer()
                }
                
                // Resolution Badge (Top Left)
                VStack {
                    HStack {
                        Text(item.resolutionBadge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(item.resolutionBadge.contains("4K") ? AppleTheme.actionBlue : Color.black.opacity(0.75))
                            )
                            .padding(8)
                        
                        Spacer()
                    }
                    Spacer()
                }
                
                // Duration Badge (Bottom Right)
                if !isPreviewActive {
                    Text(item.formattedDuration)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(4)
                        .padding(8)
                }
                
                // Watched / Live Preview Progress Bar (Bottom of Thumbnail)
                VStack {
                    Spacer()
                    GeometryReader { geo in
                        let activeProgress = isPreviewActive ? previewProgress : item.watchedProgress
                        if activeProgress > 0.01 {
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: isPreviewActive ? 4 : 3)
                                Rectangle()
                                    .fill(AppleTheme.actionBlue)
                                    .frame(width: geo.size.width * CGFloat(activeProgress), height: isPreviewActive ? 4 : 3)
                            }
                        }
                    }
                    .frame(height: isPreviewActive ? 4 : 3)
                }
                .cornerRadius(12)
            }
            .contentShape(Rectangle())
            // Single click on thumbnail opens full view immediately!
            .onTapGesture {
                onPlay()
            }
            
            // Meta Row
            HStack(alignment: .top, spacing: 8) {
                // Media Type Icon
                Image(systemName: item.mediaType == .audio ? "music.note" : "film")
                    .font(.system(size: 13))
                    .foregroundColor(item.mediaType == .audio ? .purple : AppleTheme.actionBlue)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 4) {
                        Text(item.fileExtension)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                        
                        Text(item.formattedFileSize)
                            .font(.system(size: 10))
                            .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                    }
                }
                
                Spacer()
                
                // Favorite Heart Button
                Button(action: onToggleFavorite) {
                    Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 13))
                        .foregroundColor(item.isFavorite ? .red : LiquidGlass.textTertiary(isDark: isDark))
                }
                .buttonStyle(.plain)
                .opacity(isHovered || item.isFavorite ? 1.0 : 0.0)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHovered ? LiquidGlass.cardHoverBackground(isDark: isDark) : LiquidGlass.cardBackground(isDark: isDark))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHovered ? AppleTheme.actionBlue.opacity(0.5) : LiquidGlass.cardBorder(isDark: isDark), lineWidth: 1)
        )
        .shadow(color: isDark ? Color.black.opacity(0.3) : Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
        // Single click anywhere on card opens full view!
        .onTapGesture {
            onPlay()
        }
        .onHover { hovering in
            isHovered = hovering
            hoverTimer?.invalidate()
            
            if hovering {
                // Delay 350ms before initiating live hover video preview
                hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
                    if isHovered && item.mediaType == .video {
                        withAnimation(.easeIn(duration: 0.2)) {
                            isPreviewActive = true
                        }
                    }
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    isPreviewActive = false
                    isPreviewMuted = true
                    previewProgress = 0.0
                    scrubFraction = nil
                }
            }
        }
    }
    
    // MARK: - List View Row (Fixed: Strictly bounded thumbnail and progress bar)
    
    private var listView: some View {
        HStack(spacing: 14) {
            // Rigid 140x79 Thumbnail Container (Prevents horizontal layout stretch bug)
            ZStack(alignment: .bottomLeading) {
                if isPreviewActive && item.mediaType == .video && item.url.isFileURL {
                    InlineVideoPreviewView(
                        url: item.url,
                        progress: $previewProgress,
                        isMuted: $isPreviewMuted
                    )
                    .frame(width: 140, height: 79)
                    .clipped()
                    .cornerRadius(8)
                } else {
                    thumbnailImage
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 140, height: 79)
                        .clipped()
                        .cornerRadius(8)
                }
                
                // Top-right audio button when preview is active in list
                if isPreviewActive {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                isPreviewMuted.toggle()
                            }) {
                                Image(systemName: isPreviewMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.black.opacity(0.85)))
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                        }
                        Spacer()
                    }
                }
                
                // Duration Badge (Bottom-Right)
                if !isPreviewActive {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(item.formattedDuration)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.85))
                                .cornerRadius(3)
                                .padding(4)
                        }
                    }
                }
                
                // Watched Progress Bar (Strictly fixed width: 140px to prevent layout distortion)
                if item.watchedProgress > 0.02 || isPreviewActive {
                    let activeProgress = max(0.0, min(1.0, isPreviewActive ? previewProgress : item.watchedProgress))
                    VStack {
                        Spacer()
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 140, height: 3)
                            Rectangle()
                                .fill(AppleTheme.actionBlue)
                                .frame(width: 140.0 * CGFloat(activeProgress), height: 3)
                        }
                    }
                    .frame(width: 140, height: 3, alignment: .leading)
                }
            }
            .frame(width: 140, height: 79)
            .clipped()
            .cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture {
                onPlay()
            }
            
            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(item.resolutionBadge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(AppleTheme.actionBlue)
                        )
                    
                    Text("\(item.fileExtension) • \(item.formattedFileSize)")
                        .font(.system(size: 11))
                        .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                }
                
                Text(item.url.path)
                    .font(.system(size: 10))
                    .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onToggleFavorite) {
                    Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor(item.isFavorite ? .red : LiquidGlass.textTertiary(isDark: isDark))
                }
                .buttonStyle(.plain)
                
                Button(action: onPlay) {
                    Circle()
                        .fill(AppleTheme.actionBlue)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: 1)
                        )
                }
                .buttonStyle(.plain)
                .applePressable()
            }
            .padding(.trailing, 8)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? LiquidGlass.cardHoverBackground(isDark: isDark) : LiquidGlass.cardBackground(isDark: isDark))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? AppleTheme.actionBlue.opacity(0.4) : LiquidGlass.cardBorder(isDark: isDark), lineWidth: 1)
        )
        .contentShape(Rectangle())
        // Single click anywhere on row opens full view immediately!
        .onTapGesture {
            onPlay()
        }
        .onHover { hovering in
            isHovered = hovering
            hoverTimer?.invalidate()
            if hovering {
                hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
                    if isHovered && item.mediaType == .video {
                        withAnimation(.easeIn(duration: 0.2)) {
                            isPreviewActive = true
                        }
                    }
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    isPreviewActive = false
                    isPreviewMuted = true
                    previewProgress = 0.0
                }
            }
        }
    }
    
    // MARK: - Thumbnail View
    
    @ViewBuilder
    private var thumbnailImage: some View {
        if let thumb = library.getThumbnail(for: item) {
            Image(nsImage: thumb)
                .resizable()
        } else {
            // Elegant Apple-styled gradient placeholder with icon
            LinearGradient(
                colors: item.mediaType == .audio ?
                    [AppleTheme.actionBlue.opacity(0.85), Color.purple.opacity(0.75)] :
                    [AppleTheme.tile2, AppleTheme.tile1],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: item.mediaType == .audio ? "music.note" : "film")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.4))
            )
        }
    }
}
