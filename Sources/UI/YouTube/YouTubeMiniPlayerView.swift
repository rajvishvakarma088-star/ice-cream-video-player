import SwiftUI
import AppKit

public struct YouTubeMiniPlayerView: View {
    @ObservedObject var player = VLCPlayerEngine.shared
    @ObservedObject var playlist = PlaylistManager.shared
    var isDark: Bool
    var onExpand: () -> Void
    var onClose: () -> Void
    
    @State private var isHovered: Bool = false
    @State private var isSeeking: Bool = false
    
    public init(
        isDark: Bool,
        onExpand: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.isDark = isDark
        self.onExpand = onExpand
        self.onClose = onClose
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 12) {
                // Mini Video / Artwork Container (16:9)
                ZStack(alignment: .center) {
                    VLCVideoView(
                        onDoubleClick: onExpand,
                        onDropFiles: { urls in
                            playlist.add(urls: urls)
                        }
                    )
                    .background(Color.black)
                    
                    if !player.hasVideo && !player.isNetworkStream {
                        // Audio waveform placeholder for local audio files
                        LinearGradient(
                            colors: [AppleTheme.actionBlue.opacity(0.8), Color.purple.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        )
                    }
                    // Hover expand overlay button
                    if isHovered {
                        Button(action: onExpand) {
                            Circle()
                                .fill(Color.black.opacity(0.55))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .frame(width: 104, height: 58)
                .clipped()
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    onExpand()
                }
                
                // Track Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.currentMediaTitle ?? "Playing Media")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    HStack(spacing: 6) {
                        if player.isNetworkStream {
                            Text("LIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(LiquidGlass.youtubeRed))
                        } else {
                            Text(timeProgressText)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onExpand()
                }
                
                // Controls Group
                HStack(spacing: 8) {
                    // Play / Pause Button
                    Button(action: {
                        player.togglePlayPause()
                    }) {
                        Circle()
                            .fill(AppleTheme.actionBlue)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: player.state == .playing ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(player.state == .playing ? "Pause" : "Play")
                    
                    // Stop & Close Button (Cross)
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            player.stop()
                            onClose()
                        }
                    }) {
                        Circle()
                            .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Stop and Close Mini Player")
                }
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 360, height: 74)
            
            // Bottom Scrubber Bar (Interactive)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                        .frame(height: 3)
                    
                    Rectangle()
                        .fill(LiquidGlass.youtubeRed)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(player.position))), height: 3)
                }
                .frame(height: 3)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isSeeking = true
                            let fraction = max(0.0, min(1.0, Double(val.location.x / geo.size.width)))
                            player.seek(toFraction: fraction)
                        }
                        .onEnded { _ in
                            isSeeking = false
                        }
                )
            }
            .frame(height: 3)
        }
        .frame(width: 360, height: 74)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDark ? AppleTheme.tile3 : AppleTheme.canvas)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.12) : AppleTheme.hairline, lineWidth: 1)
        )
        // Whisper-soft elevation
        .shadow(color: Color.black.opacity(isDark ? 0.45 : 0.16), radius: 18, x: 0, y: 8)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    private var timeProgressText: String {
        let current = formatTime(player.currentTimeMs)
        let total = formatTime(player.durationMs)
        return "\(current) / \(total)"
    }
    
    private func formatTime(_ ms: Int64) -> String {
        guard ms > 0 else { return "00:00" }
        let totalSec = Int(ms / 1000)
        let hours = totalSec / 3600
        let minutes = (totalSec % 3600) / 60
        let seconds = totalSec % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
