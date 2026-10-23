import SwiftUI
import AppKit

public struct MainWindowView: View {
    @ObservedObject var player = VLCPlayerEngine.shared
    @ObservedObject var playlist = PlaylistManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var library = MediaLibraryManager.shared
    @ObservedObject var streamManager = StreamManager.shared
    
    // Mode switcher
    @State private var appMode: AppMode = .classic
    
    // YouTube Pro navigation state
    @State private var isYouTubePlayerActive: Bool = false
    
    // Classic VLC state
    @State private var showClassicSidebar: Bool = true
    
    // Sheets & Fullscreen
    @State private var showEqualizerSheet: Bool = false
    @State private var showMediaInfoSheet: Bool = false
    @State private var showOpenNetworkSheet: Bool = false
    @State private var isFullScreen: Bool = false
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: "icecream_app_mode"),
           let mode = AppMode(rawValue: saved) {
            _appMode = State(initialValue: mode)
        }
    }
    
    private var isDark: Bool {
        switch themeManager.currentTheme {
        case .dark: return true
        case .light: return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // MARK: - Global Top Toolbar (Hidden in Fullscreen)
                if !isFullScreen {
                    globalTopToolbar
                }
                
                // MARK: - Body by Mode
                if appMode == .classic {
                    classicVLCView
                } else {
                    youTubeProView
                }
            }
            
            // Global Error Banner
            if let err = player.errorMessage {
                VStack {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        Spacer()
                        Button("Dismiss") { player.errorMessage = nil }
                            .buttonStyle(.plain)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(8)
                    .padding(16)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Global Status Toast
            if let toast = player.statusToast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.85))
                                .overlay(
                                    Capsule().stroke(Color.orange.opacity(0.6), lineWidth: 1)
                                )
                        )
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .sheet(isPresented: $showEqualizerSheet) {
            EqualizerView(onClose: { showEqualizerSheet = false })
        }
        .sheet(isPresented: $showMediaInfoSheet) {
            MediaInfoView(onClose: { showMediaInfoSheet = false })
        }
        .sheet(isPresented: $showOpenNetworkSheet) {
            OpenNetworkView(
                onPlay: { _ in
                    if appMode == .pro {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isYouTubePlayerActive = true
                        }
                    }
                },
                onDismiss: { showOpenNetworkSheet = false }
            )
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDroppedFiles(providers)
            return true
        }
    }
    
    @Namespace private var modeNamespace
    
    // MARK: - Global Top Toolbar
    
    private var globalTopToolbar: some View {
        HStack(spacing: 14) {
            // App Branding & Icon (Apple Minimalist)
            HStack(spacing: 8) {
                Image(systemName: "ice.cream.fill")
                    .font(.system(size: 15))
                    .foregroundColor(AppleTheme.actionBlue)
                
                Text("Ice-Cream")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
            }
            
            // Mode Switcher Capsule (Icon-only: Cone for Classic VLC, Ice-Cream for YouTube/Ice-Cream Player)
            HStack(spacing: 2) {
                modeIconButton(mode: .classic, icon: "cone.fill", tooltip: "Classic VLC Player")
                modeIconButton(mode: .pro, icon: "ice.cream.fill", tooltip: "Ice-Cream Player (Library & Pro)")
            }
            .fixedSize()
            .padding(3)
            .background(
                Capsule()
                    .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(LiquidGlass.cardBorder(isDark: isDark), lineWidth: 1)
            )
            
            Spacer()
            
            // Quick Actions
            HStack(spacing: 8) {
                Button(action: openFileDialog) {
                    Label("Open File", systemImage: "doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .applePressable()
                
                Button(action: { showOpenNetworkSheet = true }) {
                    Label("Stream", systemImage: "network")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .applePressable()
                
                Button(action: { showEqualizerSheet.toggle() }) {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .applePressable()
                .help("Audio Equalizer")
            }
            
            Divider().frame(height: 16)
            
            // Theme Switcher Button
            Button(action: {
                themeManager.cycleTheme()
            }) {
                Image(systemName: themeManager.currentTheme.iconName)
                    .font(.system(size: 13))
                    .foregroundColor(isDark ? AppleTheme.skyLinkBlue : AppleTheme.actionBlue)
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Theme: \(themeManager.currentTheme.rawValue)")
            
            // Fullscreen Button
            Button(action: toggleFullscreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                    .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Toggle Fullscreen (Cmd+F)")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(isDark ? AppleTheme.surfaceBlack : AppleTheme.parchment)
        .overlay(
            Rectangle()
                .fill(LiquidGlass.cardBorder(isDark: isDark))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func modeIconButton(mode: AppMode, icon: String, tooltip: String) -> some View {
        let isSelected = appMode == mode
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                appMode = mode
                UserDefaults.standard.set(mode.rawValue, forKey: "icecream_app_mode")
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : LiquidGlass.textSecondary(isDark: isDark))
                .frame(width: 34, height: 24)
                .background(
                    Capsule()
                        .fill(isSelected ? AppleTheme.actionBlue : Color.clear)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .applePressable()
        .help(tooltip)
    }
    
    // MARK: - Classic VLC View Mode
    
    private var classicVLCView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if showClassicSidebar && !isFullScreen {
                    SidebarView(
                        onOpenFile: openFileDialog,
                        onOpenStream: { showOpenNetworkSheet = true }
                    )
                    .transition(.move(edge: .leading))
                    
                    Divider()
                }
                
                // Video / Dropzone Surface
                ZStack {
                    VLCVideoView(
                        onDoubleClick: toggleFullscreen,
                        onDropFiles: { urls in
                            playlist.add(urls: urls)
                        }
                    )
                    .background(Color.black)
                    
                    if (player.state == .idle || player.state == .stopped) && player.currentMediaURL == nil {
                        DropZoneView(
                            onOpenFile: openFileDialog,
                            onOpenFolder: openFolderDialog,
                            onOpenStream: { showOpenNetworkSheet = true }
                        )
                    }
                    
                    if let item = playlist.resumePromptItem {
                        VStack {
                            resumeBanner(for: item)
                                .padding(.top, 16)
                            Spacer()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Classic Bottom Bar
            BottomControlsBarView(
                onToggleEqualizer: { showEqualizerSheet.toggle() },
                onToggleMediaInfo: { showMediaInfoSheet.toggle() },
                onToggleFullscreen: toggleFullscreen
            )
        }
    }
    
    // MARK: - YouTube Pro View Mode (With Floating YouTube Mini Player)
    
    private var youTubeProView: some View {
        ZStack(alignment: .bottomTrailing) {
            if isYouTubePlayerActive {
                // Theater Player
                YouTubePlayerView(
                    isDark: isDark,
                    onBackToLibrary: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isYouTubePlayerActive = false
                        }
                    },
                    onToggleFullscreen: toggleFullscreen,
                    onOpenEqualizer: { showEqualizerSheet = true },
                    onOpenMediaInfo: { showMediaInfoSheet = true }
                )
                .transition(.opacity)
            } else {
                // Media Library & Sidebar Split
                HStack(spacing: 0) {
                    YouTubeSidebarView(isDark: isDark)
                    
                    Divider().opacity(0.3)
                    
                    YouTubeLibraryView(
                        isDark: isDark,
                        onPlayItem: { item in
                            playlist.playImmediately(url: item.url, title: item.title)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isYouTubePlayerActive = true
                            }
                        },
                        onPlayURL: { url in
                            playlist.playImmediately(url: url)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isYouTubePlayerActive = true
                            }
                        }
                    )
                }
                
                // YouTube-style Floating Mini Player when browsing library during playback
                if player.state == .playing || player.state == .paused {
                    YouTubeMiniPlayerView(
                        isDark: isDark,
                        onExpand: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isYouTubePlayerActive = true
                            }
                        },
                        onClose: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                player.stop()
                            }
                        }
                    )
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.85).combined(with: .opacity)
                    ))
                    .zIndex(100)
                }
            }
        }
    }
    
    // MARK: - Resume Prompt Banner
    
    private func resumeBanner(for item: PlaylistItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(AppleTheme.actionBlue)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Continue playback where you left off?")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Resume at \(formatTime(playlist.resumePromptTimeMs))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button("Resume") {
                withAnimation { playlist.confirmResume() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppleTheme.actionBlue)
            .applePressable()
            .controlSize(.small)
            
            Button("Start Over") {
                withAnimation { playlist.dismissResume() }
            }
            .buttonStyle(.bordered)
            .applePressable()
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppleTheme.actionBlue.opacity(0.4), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 30)
    }
    
    // MARK: - File Dialogs & Drag-and-Drop
    
    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audiovisualContent, .audio, .movie]
        panel.allowsOtherFileTypes = true
        
        if panel.runModal() == .OK {
            playlist.add(urls: panel.urls)
            if appMode == .pro {
                isYouTubePlayerActive = true
            }
        }
    }
    
    private func openFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            playlist.add(urls: panel.urls)
        }
    }
    
    private func handleDroppedFiles(_ providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let u = url { urls.append(u) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if !urls.isEmpty {
                playlist.add(urls: urls)
                library.importFiles(urls: urls)
                if appMode == .pro {
                    isYouTubePlayerActive = true
                }
            }
        }
    }
    
    private func toggleFullscreen() {
        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
            isFullScreen.toggle()
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
}
