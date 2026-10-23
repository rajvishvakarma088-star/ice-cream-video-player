import SwiftUI

public struct BottomControlsBarView: View {
    @ObservedObject var player = VLCPlayerEngine.shared
    @ObservedObject var playlist = PlaylistManager.shared
    
    @State private var showRemainingTime: Bool = false
    @State private var sliderValue: Double = 0.0
    @State private var isDraggingSlider: Bool = false
    
    var onToggleEqualizer: () -> Void
    var onToggleMediaInfo: () -> Void
    var onToggleFullscreen: () -> Void
    
    public init(
        onToggleEqualizer: @escaping () -> Void,
        onToggleMediaInfo: @escaping () -> Void,
        onToggleFullscreen: @escaping () -> Void
    ) {
        self.onToggleEqualizer = onToggleEqualizer
        self.onToggleMediaInfo = onToggleMediaInfo
        self.onToggleFullscreen = onToggleFullscreen
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            scrubBarView
            
            HStack(spacing: 14) {
                transportControlsView
                Spacer()
                secondaryControlsView
                Spacer()
                audioVideoMenusView
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(
            Color.black.opacity(0.9)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
    
    // MARK: - Scrub Bar
    
    private var scrubBarView: some View {
        let positionBinding = Binding<Double>(
            get: { self.isDraggingSlider ? self.sliderValue : self.player.position },
            set: { (val: Double) in
                self.sliderValue = val
                if !self.isDraggingSlider {
                    self.isDraggingSlider = true
                    self.player.setSeeking(true)
                }
            }
        )
        
        return HStack(spacing: 10) {
            Text(formatTime(player.currentTimeMs))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 55, alignment: .trailing)
            
            Slider(
                value: positionBinding,
                in: 0.0...1.0,
                onEditingChanged: { editing in
                    self.isDraggingSlider = editing
                    self.player.setSeeking(editing)
                    if !editing {
                        self.player.seek(toFraction: self.sliderValue)
                    }
                }
            )
            .accentColor(AppleTheme.actionBlue)
            
            Button(action: { showRemainingTime.toggle() }) {
                Text(timeLabel)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 60, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
    
    // MARK: - Transport Controls
    
    private var transportControlsView: some View {
        HStack(spacing: 6) {
            Button(action: { playlist.toggleShuffle() }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(playlist.isShuffle ? AppleTheme.actionBlue : .white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Toggle Shuffle")
            
            Button(action: { playlist.cycleRepeatMode() }) {
                Image(systemName: repeatIconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(playlist.repeatMode != .off ? AppleTheme.actionBlue : .white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Cycle Repeat: \(playlist.repeatMode.rawValue)")
            
            Divider().frame(height: 16).padding(.horizontal, 4)
            
            Button(action: { playlist.playPrevious() }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Previous Track")
            
            Button(action: { player.jump(bySeconds: -10) }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Jump Backward 10s")
            
            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(AppleTheme.actionBlue)
                        .frame(width: 34, height: 34)
                        .shadow(color: AppleTheme.actionBlue.opacity(0.35), radius: 6)
                    
                    Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: player.state == .playing ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
            .applePressable()
            .help(player.state == .playing ? "Pause (Space)" : "Play (Space)")
            
            Button(action: { player.jump(bySeconds: 10) }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("Jump Forward 10s")
            
            Button(action: { playlist.playNext() }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("Next Track")
            
            Button(action: { player.stop() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Stop Playback")
        }
    }
    
    // MARK: - Center Secondary Controls
    
    private var secondaryControlsView: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0], id: \.self) { (speed: Double) in
                    Button(String(format: "%.2fx", speed)) {
                        player.setRate(Float(speed))
                    }
                }
            } label: {
                Text(String(format: "%.2fx", player.rate))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .help("Playback Speed")
            
            Button(action: { player.nextFrame() }) {
                Image(systemName: "forward.frame")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Step One Frame Forward")
            
            Menu {
                Button("Set Point A (Start)") { player.setPointA() }
                Button("Set Point B (End)") { player.setPointB() }
                Divider()
                Button("Clear A-B Loop") { player.clearABLoop() }
            } label: {
                HStack(spacing: 2) {
                    Text("A-B")
                        .font(.system(size: 11, weight: .bold))
                    if player.abLoopEnabled {
                        Circle().fill(AppleTheme.actionBlue).frame(width: 5, height: 5)
                    }
                }
                .foregroundColor(player.abLoopEnabled ? AppleTheme.actionBlue : .white.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .applePressable()
            .help("A-B Loop Playback")
            
            Button(action: { playlist.addBookmark() }) {
                Image(systemName: "bookmark")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Add Bookmark at Current Time")
            
            Button(action: { player.takeSnapshot() }) {
                Image(systemName: "camera")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Take Snapshot of Current Frame")
        }
    }
    
    // MARK: - Audio & Video Menus
    
    private var audioVideoMenusView: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(player.subtitleTracks) { track in
                    Button(track.name) {
                        player.setSubtitleTrack(id: track.id)
                    }
                }
                Divider()
                Menu("Subtitle Delay") {
                    Button("+50 ms") { player.setSubtitleDelay(ms: player.subtitleDelayMs + 50) }
                    Button("-50 ms") { player.setSubtitleDelay(ms: player.subtitleDelayMs - 50) }
                    Button("Reset Delay") { player.setSubtitleDelay(ms: 0) }
                }
            } label: {
                Image(systemName: "captions.bubble")
                    .font(.system(size: 14))
                    .foregroundColor(player.selectedSubtitleTrackId != -1 ? AppleTheme.actionBlue : .white.opacity(0.8))
            }
            .menuStyle(.borderlessButton)
            .applePressable()
            .help("Subtitles")
            
            Menu {
                ForEach(player.audioTracks) { track in
                    Button(track.name) {
                        player.setAudioTrack(id: track.id)
                    }
                }
                Divider()
                Menu("Audio Delay") {
                    Button("+50 ms") { player.setAudioDelay(ms: player.audioDelayMs + 50) }
                    Button("-50 ms") { player.setAudioDelay(ms: player.audioDelayMs - 50) }
                    Button("Reset Delay") { player.setAudioDelay(ms: 0) }
                }
            } label: {
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .menuStyle(.borderlessButton)
            .applePressable()
            .help("Audio Tracks")
            
            Menu {
                ForEach(["Default", "16:9", "4:3", "1:1", "16:10", "2.21:1", "2.35:1"], id: \.self) { ratio in
                    Button(ratio) {
                        player.setAspectRatio(ratio)
                    }
                }
            } label: {
                Image(systemName: "aspectratio")
                    .font(.system(size: 14))
                    .foregroundColor(player.aspectRatio != "Default" ? AppleTheme.actionBlue : .white.opacity(0.8))
            }
            .menuStyle(.borderlessButton)
            .applePressable()
            .help("Aspect Ratio: \(player.aspectRatio)")
            
            Button(action: onToggleEqualizer) {
                Image(systemName: "slider.vertical.3")
                    .font(.system(size: 14))
                    .foregroundColor(player.equalizerEnabled ? AppleTheme.actionBlue : .white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Audio Equalizer")
            
            Button(action: onToggleMediaInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Media Information")
            
            volumeControlView
            
            Button(action: onToggleFullscreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Toggle Full Screen")
        }
    }
    
    // MARK: - Volume Slider
    
    private var volumeControlView: some View {
        let volumeBinding = Binding<Double>(
            get: { Double(self.player.volume) },
            set: { (val: Double) in self.player.setVolume(Int32(val)) }
        )
        
        return HStack(spacing: 5) {
            Button(action: { player.toggleMute() }) {
                Image(systemName: volumeIconName)
                    .font(.system(size: 13))
                    .foregroundColor(player.isMuted ? .red : .white.opacity(0.85))
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .applePressable()
            .help("Mute / Unmute")
            
            Slider(value: volumeBinding, in: 0.0...200.0)
                .frame(width: 65)
                .accentColor(player.volume > 100 ? AppleTheme.actionBlue : .accentColor)
            
            Text("\(player.volume)%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 32, alignment: .leading)
        }
    }
    
    private var timeLabel: String {
        if showRemainingTime && player.durationMs > 0 {
            let remaining = max(0, player.durationMs - player.currentTimeMs)
            return "-" + formatTime(remaining)
        } else {
            return formatTime(player.durationMs)
        }
    }
    
    private var repeatIconName: String {
        switch playlist.repeatMode {
        case .off: return "repeat"
        case .repeatAll: return "repeat"
        case .repeatOne: return "repeat.1"
        }
    }
    
    private var volumeIconName: String {
        if player.isMuted || player.volume == 0 {
            return "speaker.slash.fill"
        } else if player.volume < 70 {
            return "speaker.wave.1.fill"
        } else if player.volume <= 120 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
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
