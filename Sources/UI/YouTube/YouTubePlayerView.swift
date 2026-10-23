import SwiftUI
import AppKit

public struct YouTubePlayerView: View {
    @ObservedObject var player = VLCPlayerEngine.shared
    @ObservedObject var playlist = PlaylistManager.shared
    var isDark: Bool
    var onBackToLibrary: () -> Void
    var onToggleFullscreen: () -> Void
    var onOpenEqualizer: () -> Void
    var onOpenMediaInfo: () -> Void
    
    @State private var showHUD: Bool = true
    @State private var hudTimer: Timer?
    @State private var isSeeking: Bool = false
    @State private var seekFraction: Double = 0.0
    
    // YouTube-style centered ripple flash state
    @State private var flashIconName: String? = nil
    @State private var flashScale: CGFloat = 0.8
    @State private var flashOpacity: Double = 0.0
    
    // Small Channel List Drawer state
    @State private var showChannelList: Bool = false
    @State private var channelSearchText: String = ""
    @State private var selectedGroup: String? = nil
    
    public init(
        isDark: Bool,
        onBackToLibrary: @escaping () -> Void,
        onToggleFullscreen: @escaping () -> Void,
        onOpenEqualizer: @escaping () -> Void,
        onOpenMediaInfo: @escaping () -> Void
    ) {
        self.isDark = isDark
        self.onBackToLibrary = onBackToLibrary
        self.onToggleFullscreen = onToggleFullscreen
        self.onOpenEqualizer = onOpenEqualizer
        self.onOpenMediaInfo = onOpenMediaInfo
    }
    
    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Video Presentation Layer
            VLCVideoView(
                onDoubleClick: onToggleFullscreen,
                onDropFiles: { urls in
                    playlist.add(urls: urls)
                }
            )
            .edgesIgnoringSafeArea(.all)
            
            // Click-to-Pause Screen Interaction Overlay
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    onToggleFullscreen()
                }
                .onTapGesture(count: 1) {
                    togglePlayPauseWithFeedback()
                }
            
            // YouTube Centered Ripple Flash Indicator
            if let icon = flashIconName {
                Circle()
                    .fill(Color.black.opacity(0.65))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: icon == "play.fill" ? 3 : 0)
                    )
                    .scaleEffect(flashScale)
                    .opacity(flashOpacity)
                    .transition(.opacity)
            }
            
            // Buffering / Connecting Indicator Overlay
            if player.state == .buffering || player.state == .opening {
                bufferingOverlayView
                    .transition(.opacity)
            }
            
            // Floating Top & Bottom Controls (Auto-hiding Liquid Glass HUD)
            if showHUD || player.state != .playing || isSeeking || showChannelList {
                VStack(spacing: 0) {
                    topHUDView
                    Spacer()
                    bottomHUDView
                }
                .transition(.opacity)
            }
            
            // Small Channel List Drawer (Floating Compact Channel Selector)
            if showChannelList && !playlist.items.isEmpty {
                HStack(spacing: 0) {
                    Spacer()
                    compactChannelListView
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .padding(.top, 60)
                .padding(.bottom, 75)
                .padding(.trailing, 16)
                .zIndex(45)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                kickHUDTimer()
            case .ended:
                break
            }
        }
        .onAppear {
            kickHUDTimer()
        }
        .onDisappear {
            hudTimer?.invalidate()
        }
        .onChange(of: player.state) {
            let newState = player.state
            // If paused, keep HUD visible
            if newState != .playing {
                withAnimation(.easeOut(duration: 0.15)) {
                    showHUD = true
                }
            } else {
                kickHUDTimer()
            }
        }
    }
    
    // MARK: - Play / Pause with Visual Ripple Feedback
    
    private func togglePlayPauseWithFeedback() {
        player.togglePlayPause()
        kickHUDTimer()
        
        let icon = player.state == .playing ? "play.fill" : "pause.fill"
        flashIconName = icon
        flashScale = 0.8
        flashOpacity = 0.95
        
        withAnimation(.easeOut(duration: 0.35)) {
            flashScale = 1.2
            flashOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if flashOpacity == 0.0 {
                flashIconName = nil
            }
        }
    }
    
    // MARK: - Buffering Overlay
    
    private var bufferingOverlayView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.3)
            
            Text(player.isNetworkStream ? "Connecting to stream..." : "Loading media...")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Top HUD
    
    private var topHUDView: some View {
        HStack(spacing: 14) {
            Button(action: onBackToLibrary) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                    Text("Library")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(Color.black.opacity(0.6))
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Media Title & Stream Badge
            HStack(spacing: 8) {
                if player.isNetworkStream {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(LiquidGlass.youtubeRed))
                }
                
                Text(player.currentMediaTitle ?? "Playing Media")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            // Small Channel List Toggle Button
            if !playlist.items.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showChannelList.toggle()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: showChannelList ? "tv.inset.filled" : "tv")
                            .font(.system(size: 11, weight: .bold))
                        Text(showChannelList ? "Hide List" : "Channels (\(playlist.items.count))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(showChannelList ? AppleTheme.actionBlue : Color.black.opacity(0.6))
                    )
                    .overlay(
                        Capsule().stroke(showChannelList ? Color.white.opacity(0.6) : Color.white.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .applePressable()
                .help(showChannelList ? "Hide channels list" : "Show all channels list to change channel")
            }
            
            Spacer()
            
            // Picture in Picture
            Button(action: {
                if let win = NSApplication.shared.keyWindow {
                    win.level = win.level == .floating ? .normal : .floating
                    player.setAspectRatio("Default")
                }
            }) {
                Image(systemName: "pip.enter")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(8)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .buttonStyle(.plain)
            .help("Picture in Picture (Pin on Top)")
            
            // Snapshot
            Button(action: { player.takeSnapshot() }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(8)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .buttonStyle(.plain)
            .help("Take Snapshot")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.8), Color.clear], startPoint: .top, endPoint: .bottom)
        )
    }
    
    // MARK: - Bottom HUD
    
    private var bottomHUDView: some View {
        VStack(spacing: 8) {
            scrubBarView
            
            HStack(spacing: 16) {
                transportControlsView
                
                timeDisplayView
                
                Spacer()
                
                volumeControlsView
                
                // Channel List Shortcut Button
                if !playlist.items.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showChannelList.toggle()
                        }
                    }) {
                        Image(systemName: showChannelList ? "tv.inset.filled" : "tv")
                            .font(.system(size: 14))
                            .foregroundColor(showChannelList ? AppleTheme.actionBlue : .white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .help(showChannelList ? "Hide Channels" : "Channels List")
                }
                
                settingsMenuView
                
                Button(action: onToggleFullscreen) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help("Toggle Fullscreen")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .background(
            LinearGradient(colors: [Color.clear, Color.black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
        )
    }
    
    // MARK: - Scrub Bar
    
    private var scrubBarView: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let currentPos = isSeeking ? seekFraction : player.position
            let progressWidth = max(0.0, min(width, width * CGFloat(currentPos)))
            
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: isSeeking ? 6 : 4)
                    .cornerRadius(2)
                
                // Progress
                Rectangle()
                    .fill(LiquidGlass.youtubeRed)
                    .frame(width: progressWidth, height: isSeeking ? 6 : 4)
                    .cornerRadius(2)
                
                // Scrubber thumb
                Circle()
                    .fill(LiquidGlass.youtubeRed)
                    .frame(width: 12, height: 12)
                    .offset(x: max(0, progressWidth - 6))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        kickHUDTimer()
                        isSeeking = true
                        let fraction = max(0.0, min(1.0, Double(val.location.x / width)))
                        seekFraction = fraction
                    }
                    .onEnded { val in
                        let fraction = max(0.0, min(1.0, Double(val.location.x / width)))
                        player.seek(toFraction: fraction)
                        isSeeking = false
                        kickHUDTimer()
                    }
            )
        }
        .frame(height: 14)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Transport Controls
    
    private var transportControlsView: some View {
        HStack(spacing: 12) {
            // Previous
            Button(action: {
                playlist.playPrevious()
                kickHUDTimer()
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            // Jump Back 10s
            Button(action: {
                player.jump(bySeconds: -10)
                kickHUDTimer()
            }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            // Play / Pause
            Button(action: {
                togglePlayPauseWithFeedback()
            }) {
                Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            
            // Jump Forward 10s
            Button(action: {
                player.jump(bySeconds: 10)
                kickHUDTimer()
            }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            // Next
            Button(action: {
                playlist.playNext()
                kickHUDTimer()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Time Display
    
    private var timeDisplayView: some View {
        HStack(spacing: 4) {
            Text(formatTime(player.currentTimeMs))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("/")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            
            Text(player.durationMs > 0 ? formatTime(player.durationMs) : "Live")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Volume Controls
    
    private var volumeControlsView: some View {
        HStack(spacing: 8) {
            Button(action: {
                player.toggleMute()
                kickHUDTimer()
            }) {
                Image(systemName: player.isMuted ? "speaker.slash.fill" : (player.volume > 100 ? "speaker.wave.3.fill" : "speaker.wave.2.fill"))
                    .font(.system(size: 14))
                    .foregroundColor(player.isMuted ? .red : .white)
            }
            .buttonStyle(.plain)
            
            Slider(
                value: Binding<Double>(
                    get: { Double(player.volume) },
                    set: {
                        player.setVolume(Int32($0))
                        kickHUDTimer()
                    }
                ),
                in: 0.0...200.0
            )
            .frame(width: 75)
            .accentColor(.white)
        }
    }
    
    // MARK: - Settings Menu
    
    private var settingsMenuView: some View {
        Menu {
            // Speed Menu
            Menu("Playback Speed (\(String(format: "%.2fx", player.rate)))") {
                ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { rate in
                    Button(String(format: "%.2fx", rate)) {
                        player.setRate(Float(rate))
                        kickHUDTimer()
                    }
                }
            }
            
            // Aspect Ratio
            Menu("Aspect Ratio (\(player.aspectRatio))") {
                ForEach(["Default", "16:9", "4:3", "1:1", "16:10", "2.35:1"], id: \.self) { ratio in
                    Button(ratio) {
                        player.setAspectRatio(ratio)
                        kickHUDTimer()
                    }
                }
            }
            
            // Audio Track
            Menu("Audio Track") {
                ForEach(player.audioTracks) { track in
                    Button(track.name) {
                        player.setAudioTrack(id: track.id)
                        kickHUDTimer()
                    }
                }
            }
            
            // Subtitles
            Menu("Subtitles") {
                ForEach(player.subtitleTracks) { sub in
                    Button(sub.name) {
                        player.setSubtitleTrack(id: sub.id)
                        kickHUDTimer()
                    }
                }
            }
            
            Divider()
            
            Button("Graphic Equalizer...") {
                onOpenEqualizer()
            }
            
            Button("Media Information...") {
                onOpenMediaInfo()
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15))
                .foregroundColor(.white)
        }
        .menuStyle(.borderlessButton)
    }
    
    // MARK: - Auto-Hide HUD Logic
    
    private func kickHUDTimer() {
        if !showHUD {
            withAnimation(.easeOut(duration: 0.15)) {
                showHUD = true
            }
        }
        hudTimer?.invalidate()
        hudTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: false) { _ in
            if player.state == .playing && !isSeeking {
                withAnimation(.easeIn(duration: 0.25)) {
                    showHUD = false
                }
            }
        }
    }
    
    private func formatTime(_ ms: Int64) -> String {
        guard ms > 0 else { return "00:00" }
        let totalSeconds = Int(ms / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Small Channels List Drawer View
    
    private var filteredChannels: [(index: Int, item: PlaylistItem)] {
        guard showChannelList else { return [] }
        let trimmed = channelSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result: [(index: Int, item: PlaylistItem)] = []
        result.reserveCapacity(200)
        
        let targetGroup = selectedGroup
        let isSearching = !trimmed.isEmpty
        
        for (idx, item) in playlist.items.enumerated() {
            if let grp = targetGroup, !grp.isEmpty {
                if item.group != grp { continue }
            }
            if isSearching {
                if !item.title.localizedCaseInsensitiveContains(trimmed) {
                    continue
                }
            }
            result.append((index: idx, item: item))
            if result.count >= 200 {
                break
            }
        }
        return result
    }
    
    private var availableGroups: [String] {
        return playlist.availableGroups
    }
    
    private var compactChannelListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppleTheme.actionBlue)
                        .frame(width: 22, height: 22)
                    Image(systemName: "tv.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 11, weight: .bold))
                }
                
                Text("Channels")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(playlist.items.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showChannelList = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .applePressable()
                .help("Hide Channels (Close)")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            
            // Search Input Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 11))
                
                TextField("Filter channels...", text: $channelSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                
                if !channelSearchText.isEmpty {
                    Button(action: { channelSearchText = "" }) {
                        Image(systemName: "multiply.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            // Category Filter Chips
            if !availableGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button(action: { selectedGroup = nil }) {
                            Text("All")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(selectedGroup == nil ? .white : .white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(selectedGroup == nil ? AppleTheme.actionBlue : Color.white.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(availableGroups.prefix(12), id: \.self) { grp in
                            Button(action: { selectedGroup = grp }) {
                                Text(grp)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(selectedGroup == grp ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(selectedGroup == grp ? AppleTheme.actionBlue : Color.white.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            
            Divider().background(Color.white.opacity(0.15))
            
            // Scrollable Channels List
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 4) {
                    ForEach(filteredChannels, id: \.item.id) { entry in
                        let isCurrent = playlist.currentIndex == entry.index
                        Button(action: {
                            playlist.play(index: entry.index)
                        }) {
                            HStack(spacing: 8) {
                                // Channel index number
                                Text("\(entry.index + 1)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(isCurrent ? AppleTheme.actionBlue : .white.opacity(0.45))
                                    .frame(width: 28, alignment: .trailing)
                                
                                // Channel Title & Group
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.item.title)
                                        .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                                        .foregroundColor(isCurrent ? AppleTheme.actionBlue : .white)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    if let grp = entry.item.group, !grp.isEmpty {
                                        Text(grp)
                                            .font(.system(size: 9))
                                            .foregroundColor(.white.opacity(0.45))
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                if isCurrent {
                                    HStack(spacing: 2) {
                                        RoundedRectangle(cornerRadius: 1).fill(AppleTheme.actionBlue).frame(width: 2, height: 10)
                                        RoundedRectangle(cornerRadius: 1).fill(AppleTheme.actionBlue).frame(width: 2, height: 14)
                                        RoundedRectangle(cornerRadius: 1).fill(AppleTheme.actionBlue).frame(width: 2, height: 8)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isCurrent ? AppleTheme.actionBlue.opacity(0.25) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isCurrent ? AppleTheme.actionBlue.opacity(0.7) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .applePressable()
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 380)
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.7), radius: 20, x: -6, y: 6)
        )
    }
}
