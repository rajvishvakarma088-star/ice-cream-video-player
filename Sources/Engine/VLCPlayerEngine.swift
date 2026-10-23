import Foundation
import AppKit
import Combine
import Clibvlc

public enum PlayerState: String, Codable {
    case idle = "Idle"
    case opening = "Opening"
    case buffering = "Buffering"
    case playing = "Playing"
    case paused = "Paused"
    case stopped = "Stopped"
    case ended = "Ended"
    case error = "Error"
}

public struct TrackItem: Identifiable, Equatable, Hashable {
    public let id: Int32
    public let name: String
}

public class VLCPlayerEngine: ObservableObject {
    public static let shared = VLCPlayerEngine()
    
    // Core LibVLC pointers
    private var vlcInstance: OpaquePointer?
    private var mediaPlayer: OpaquePointer?
    private var currentMedia: OpaquePointer?
    private var equalizer: OpaquePointer?
    
    // Video presentation view (Single persistent instance bound to LibVLC once)
    public let videoSurface: VideoSurfaceNSView = {
        let v = VideoSurfaceNSView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.black.cgColor
        return v
    }()
    
    // Persistent off-screen host ensuring videoSurface always has an active Cocoa hierarchy
    private let fallbackHostView: NSView = {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.black.cgColor
        return v
    }()
    
    public internal(set) weak var currentHostView: NSView?
    public var targetVideoView: NSView? { currentHostView }
    public var fallbackVideoView: NSView { fallbackHostView }
    
    // UI state
    @Published public var state: PlayerState = .idle
    @Published public var currentTimeMs: Int64 = 0
    @Published public var durationMs: Int64 = 0
    @Published public var position: Double = 0.0 // 0.0 .. 1.0
    @Published public var volume: Int32 = 100 // 0 .. 200%
    @Published public var isMuted: Bool = false
    @Published public var rate: Float = 1.0 // 0.25 .. 4.0
    @Published public var aspectRatio: String = "Default"
    @Published public var hasVideo: Bool = false
    @Published public var currentMediaTitle: String? = nil
    @Published public var currentMediaURL: URL? = nil
    @Published public var isNetworkStream: Bool = false
    @Published public var bufferingPercentage: Float = 0.0
    
    // Audio / Subtitles
    @Published public var audioTracks: [TrackItem] = []
    @Published public var selectedAudioTrackId: Int32 = -1
    @Published public var audioDelayMs: Int64 = 0
    
    @Published public var subtitleTracks: [TrackItem] = []
    @Published public var selectedSubtitleTrackId: Int32 = -1
    @Published public var subtitleDelayMs: Int64 = 0
    
    // Equalizer
    @Published public var equalizerEnabled: Bool = false
    @Published public var equalizerPreamp: Float = 0.0
    @Published public var equalizerBands: [Float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    @Published public var currentPresetName: String = "Flat"
    
    // A-B Loop
    @Published public var abLoopEnabled: Bool = false
    @Published public var abPointAMs: Int64? = nil
    @Published public var abPointBMs: Int64? = nil
    
    // Visualizer simulation (for audio-only / playback reactivity)
    @Published public var visualizerLevels: [CGFloat] = Array(repeating: 0.1, count: 24)
    
    // Notifications / Error
    @Published public var errorMessage: String? = nil
    @Published public var statusToast: String? = nil
    
    // Update timer
    private var updateTimer: Timer?
    private var isUserSeeking: Bool = false
    
    public init() {
        setupPluginPath()
        initializeLibVLC()
        startUpdateTimer()
    }
    
    deinit {
        stopUpdateTimer()
        cleanupMedia()
        if let player = mediaPlayer {
            libvlc_media_player_stop(player)
            libvlc_media_player_release(player)
            mediaPlayer = nil
        }
        if let eq = equalizer {
            libvlc_audio_equalizer_release(eq)
            equalizer = nil
        }
        if let inst = vlcInstance {
            libvlc_release(inst)
            vlcInstance = nil
        }
    }
    
    // MARK: - Initialization
    
    private func setupPluginPath() {
        let fileManager = FileManager.default
        let bundlePath = Bundle.main.bundlePath
        let currentDir = fileManager.currentDirectoryPath
        
        let candidates = [
            "\(bundlePath)/Contents/MacOS/plugins",
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/plugins").path,
            "\(currentDir)/VLCPlayerApp/VLC Player.app/Contents/MacOS/plugins",
            "\(currentDir)/VLCPlayerApp/plugins",
            "\(currentDir)/plugins",
            "/Users/rajvishvakarma/Downloads/practice app /VLCPlayerApp/VLC Player.app/Contents/MacOS/plugins",
            "/Users/rajvishvakarma/Downloads/practice app /VLCPlayerApp/plugins"
        ]
        
        for candidate in candidates {
            if fileManager.fileExists(atPath: candidate) {
                setenv("VLC_PLUGIN_PATH", candidate, 1)
                break
            }
        }
    }
    
    private func initializeLibVLC() {
        let args: [String] = [
            "IceCreamPlayer",
            "--no-video-title-show",
            "--no-stats",
            "--no-sub-autodetect-file",
            "--network-caching=3000",
            "--live-caching=3000",
            "--http-user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "--quiet",
            "--ignore-config"
        ]
        
        let cStrings: [UnsafePointer<CChar>?] = args.map { UnsafePointer(strdup($0)) }
        defer {
            for ptr in cStrings {
                if let p = ptr { free(UnsafeMutableRawPointer(mutating: p)) }
            }
        }
        
        var inst = cStrings.withUnsafeBufferPointer { buf in
            libvlc_new(Int32(buf.count), buf.baseAddress)
        }
        
        // Robust fallback: if args fail on any system, initialize with clean defaults
        if inst == nil {
            inst = libvlc_new(0, nil)
        }
        
        guard let validInst = inst else {
            errorMessage = "Failed to initialize LibVLC engine."
            return
        }
        
        self.vlcInstance = validInst
        self.mediaPlayer = libvlc_media_player_new(validInst)
        
        // Host videoSurface initially in persistent fallback host
        fallbackHostView.addSubview(videoSurface)
        videoSurface.frame = fallbackHostView.bounds
        videoSurface.autoresizingMask = [.width, .height]
        
        // Immediately bind our persistent video surface ONCE to LibVLC player!
        if let player = self.mediaPlayer {
            let surfacePtr = Unmanaged.passUnretained(videoSurface).toOpaque()
            libvlc_media_player_set_nsobject(player, surfacePtr)
            libvlc_audio_set_volume(player, volume)
        }
        
        // Create 10-band equalizer
        self.equalizer = libvlc_audio_equalizer_new()
    }
    
    // MARK: - Video Surface Binding
    
    public func attachVideoSurface(to hostView: NSView) {
        self.currentHostView = hostView
        if videoSurface.superview !== hostView {
            videoSurface.removeFromSuperview()
            videoSurface.frame = hostView.bounds
            videoSurface.autoresizingMask = [.width, .height]
            videoSurface.translatesAutoresizingMaskIntoConstraints = true
            hostView.addSubview(videoSurface)
        } else {
            if videoSurface.frame != hostView.bounds {
                videoSurface.frame = hostView.bounds
            }
        }
        
        if let host = hostView as? VideoHostNSView {
            videoSurface.onDoubleClick = host.onDoubleClick
            videoSurface.onDropFiles = host.onDropFiles
        }
        videoSurface.needsLayout = true
        videoSurface.needsDisplay = true
    }
    
    public func detachVideoSurface(from hostView: NSView) {
        if self.currentHostView === hostView || videoSurface.superview === hostView {
            self.currentHostView = nil
            videoSurface.removeFromSuperview()
            fallbackHostView.addSubview(videoSurface)
            videoSurface.frame = fallbackHostView.bounds
            videoSurface.autoresizingMask = [.width, .height]
        }
    }
    
    // Compatibility forwarders
    public func attach(to view: NSView) {
        attachVideoSurface(to: view)
    }
    
    public func detach(from view: NSView) {
        detachVideoSurface(from: view)
    }
    
    // MARK: - Media Loading & Playback Controls
    
    public func loadAndPlay(url: URL, title: String? = nil, startTimeMs: Int64 = 0, options: [String] = []) {
        guard let inst = vlcInstance, let player = mediaPlayer else {
            errorMessage = "LibVLC engine is not initialized."
            return
        }
        
        // 1. Crucial: Stop previous media player FIRST before releasing media or changing state!
        // This avoids race conditions and crashes in background decoder threads!
        libvlc_media_player_stop(player)
        cleanupMedia()
        
        self.currentMediaURL = url
        self.currentMediaTitle = title ?? url.deletingPathExtension().lastPathComponent
        self.abPointAMs = nil
        self.abPointBMs = nil
        self.abLoopEnabled = false
        self.errorMessage = nil
        
        self.isNetworkStream = !url.isFileURL
        self.bufferingPercentage = 0.0
        
        let media: OpaquePointer?
        if url.isFileURL {
            let path = url.path
            media = path.withCString { libvlc_media_new_path(inst, $0) }
        } else {
            let urlString = url.absoluteString
            media = urlString.withCString { libvlc_media_new_location(inst, $0) }
        }
        
        guard let validMedia = media else {
            self.errorMessage = "Failed to create media item from \(url.lastPathComponent)"
            self.state = .error
            return
        }
        
        if !url.isFileURL {
            ":network-caching=2500".withCString { libvlc_media_add_option(validMedia, $0) }
            ":live-caching=2500".withCString { libvlc_media_add_option(validMedia, $0) }
            ":sout-mux-caching=2500".withCString { libvlc_media_add_option(validMedia, $0) }
            ":http-reconnect".withCString { libvlc_media_add_option(validMedia, $0) }
            
            // Apply custom options from M3U (#EXTVLCOPT / headers)
            for opt in options {
                let trimmed = opt.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let formatted = trimmed.hasPrefix(":") ? trimmed : ":\(trimmed)"
                    formatted.withCString { libvlc_media_add_option(validMedia, $0) }
                }
            }
        }
        
        self.currentMedia = validMedia
        libvlc_media_player_set_media(player, validMedia)
        
        // Ensure LibVLC outputs to our persistent single videoSurface
        let surfacePtr = Unmanaged.passUnretained(videoSurface).toOpaque()
        libvlc_media_player_set_nsobject(player, surfacePtr)
        
        libvlc_media_player_play(player)
        self.state = .playing
        
        if startTimeMs > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.seek(toMs: startTimeMs)
            }
        }
        
        refreshTracks()
    }
    
    public func play() {
        guard let player = mediaPlayer else { return }
        libvlc_media_player_play(player)
        self.state = .playing
    }
    
    public func pause() {
        guard let player = mediaPlayer else { return }
        libvlc_media_player_pause(player)
        self.state = .paused
    }
    
    public func togglePlayPause() {
        guard let player = mediaPlayer else { return }
        let isPlaying = libvlc_media_player_is_playing(player) == 1
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func stop() {
        guard let player = mediaPlayer else { return }
        libvlc_media_player_stop(player)
        self.state = .stopped
        self.currentTimeMs = 0
        self.position = 0.0
    }
    
    private func cleanupMedia() {
        if let m = currentMedia {
            libvlc_media_release(m)
            currentMedia = nil
        }
    }
    
    // MARK: - Seeking & Navigation
    
    public func setSeeking(_ seeking: Bool) {
        self.isUserSeeking = seeking
    }
    
    public func seek(toFraction fraction: Double) {
        guard let player = mediaPlayer else { return }
        let clamped = max(0.0, min(1.0, fraction))
        libvlc_media_player_set_position(player, Float(clamped))
        self.position = clamped
        if durationMs > 0 {
            self.currentTimeMs = Int64(clamped * Double(durationMs))
        }
    }
    
    public func seek(toMs ms: Int64) {
        guard let player = mediaPlayer else { return }
        let targetMs = max(0, ms)
        libvlc_media_player_set_time(player, targetMs)
        self.currentTimeMs = targetMs
        if durationMs > 0 {
            self.position = Double(targetMs) / Double(durationMs)
        }
    }
    
    public func jump(bySeconds seconds: Int64) {
        let newTime = max(0, currentTimeMs + (seconds * 1000))
        seek(toMs: newTime)
        showStatusToast(seconds > 0 ? "+\(seconds)s" : "\(seconds)s")
    }
    
    public func nextFrame() {
        guard let player = mediaPlayer else { return }
        libvlc_media_player_next_frame(player)
        showStatusToast("Frame Step")
    }
    
    // MARK: - Playback Speed
    
    public func setRate(_ newRate: Float) {
        guard let player = mediaPlayer else { return }
        let clamped = max(0.25, min(4.0, newRate))
        libvlc_media_player_set_rate(player, clamped)
        self.rate = clamped
        showStatusToast(String(format: "%.2fx", clamped))
    }
    
    // MARK: - Volume & Audio Controls
    
    public func setVolume(_ newVolume: Int32) {
        guard let player = mediaPlayer else { return }
        let clamped = max(0, min(200, newVolume))
        libvlc_audio_set_volume(player, clamped)
        self.volume = clamped
        if clamped > 0 && isMuted {
            isMuted = false
            libvlc_audio_set_mute(player, 0)
        }
    }
    
    public func toggleMute() {
        guard let player = mediaPlayer else { return }
        let newMuted = !isMuted
        libvlc_audio_set_mute(player, newMuted ? 1 : 0)
        self.isMuted = newMuted
        showStatusToast(newMuted ? "Muted" : "Unmuted (\(volume)%)")
    }
    
    public func setAudioDelay(ms: Int64) {
        guard let player = mediaPlayer else { return }
        // microseconds in libvlc
        libvlc_audio_set_delay(player, ms * 1000)
        self.audioDelayMs = ms
        showStatusToast(String(format: "Audio delay: %+d ms", ms))
    }
    
    // MARK: - Aspect Ratio
    
    public func setAspectRatio(_ ratio: String) {
        guard let player = mediaPlayer else { return }
        self.aspectRatio = ratio
        if ratio == "Default" {
            libvlc_video_set_aspect_ratio(player, nil)
        } else {
            ratio.withCString { cStr in
                libvlc_video_set_aspect_ratio(player, cStr)
            }
        }
        showStatusToast("Aspect Ratio: \(ratio)")
    }
    
    // MARK: - Track Discovery & Selection
    
    public func refreshTracks() {
        guard let player = mediaPlayer else { return }
        
        // Refresh Audio Tracks
        var audioList: [TrackItem] = []
        let audioDesc = libvlc_audio_get_track_description(player)
        var currentAudioDesc = audioDesc
        while let desc = currentAudioDesc {
            let id = desc.pointee.i_id
            let nameStr: String
            if let psz = desc.pointee.psz_name {
                nameStr = String(cString: psz)
            } else {
                nameStr = "Track \(id)"
            }
            audioList.append(TrackItem(id: id, name: nameStr))
            currentAudioDesc = desc.pointee.p_next
        }
        if let audioDesc = audioDesc {
            libvlc_track_description_list_release(audioDesc)
        }
        self.audioTracks = audioList
        self.selectedAudioTrackId = libvlc_audio_get_track(player)
        
        // Refresh Subtitle (SPU) Tracks
        var subList: [TrackItem] = []
        let subDesc = libvlc_video_get_spu_description(player)
        var currentSubDesc = subDesc
        while let desc = currentSubDesc {
            let id = desc.pointee.i_id
            let nameStr: String
            if let psz = desc.pointee.psz_name {
                nameStr = String(cString: psz)
            } else {
                nameStr = id == -1 ? "Disable Subtitles" : "Subtitle \(id)"
            }
            subList.append(TrackItem(id: id, name: nameStr))
            currentSubDesc = desc.pointee.p_next
        }
        if let subDesc = subDesc {
            libvlc_track_description_list_release(subDesc)
        }
        self.subtitleTracks = subList
        self.selectedSubtitleTrackId = libvlc_video_get_spu(player)
    }
    
    public func setAudioTrack(id: Int32) {
        guard let player = mediaPlayer else { return }
        libvlc_audio_set_track(player, id)
        self.selectedAudioTrackId = id
        if let track = audioTracks.first(where: { $0.id == id }) {
            showStatusToast("Audio: \(track.name)")
        }
    }
    
    public func setSubtitleTrack(id: Int32) {
        guard let player = mediaPlayer else { return }
        libvlc_video_set_spu(player, id)
        self.selectedSubtitleTrackId = id
        if let track = subtitleTracks.first(where: { $0.id == id }) {
            showStatusToast("Subtitles: \(track.name)")
        }
    }
    
    public func loadExternalSubtitle(fileURL: URL) {
        guard let player = mediaPlayer else { return }
        let path = fileURL.path
        let success = path.withCString { libvlc_video_set_subtitle_file(player, $0) } == 1
        if success {
            showStatusToast("Loaded subtitle: \(fileURL.lastPathComponent)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refreshTracks()
            }
        } else {
            showStatusToast("Failed to load subtitle file")
        }
    }
    
    public func setSubtitleDelay(ms: Int64) {
        guard let player = mediaPlayer else { return }
        libvlc_video_set_spu_delay(player, ms * 1000)
        self.subtitleDelayMs = ms
        showStatusToast(String(format: "Subtitle delay: %+d ms", ms))
    }
    
    // MARK: - Snapshot Capture
    
    public func takeSnapshot(directory: URL? = nil) {
        guard let player = mediaPlayer else { return }
        
        let saveDir = directory ?? FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "VLC_Snapshot_\(timestamp).png"
        let fileURL = saveDir.appendingPathComponent(filename)
        
        let res = fileURL.path.withCString { cPath in
            libvlc_video_take_snapshot(player, 0, cPath, 0, 0)
        }
        
        if res == 0 {
            showStatusToast("Snapshot saved: \(filename)")
        } else {
            showStatusToast("Snapshot failed")
        }
    }
    
    // MARK: - Audio Equalizer
    
    public func setEqualizerEnabled(_ enabled: Bool) {
        self.equalizerEnabled = enabled
        applyEqualizer()
        showStatusToast(enabled ? "Equalizer Enabled" : "Equalizer Disabled")
    }
    
    public func setEqualizerPreset(_ preset: AudioEqualizerPreset) {
        self.currentPresetName = preset.name
        self.equalizerPreamp = preset.preamp
        self.equalizerBands = preset.bands
        applyEqualizer()
        showStatusToast("EQ Preset: \(preset.name)")
    }
    
    public func setBandGain(index: Int, gainDb: Float) {
        guard index >= 0 && index < 10 else { return }
        equalizerBands[index] = max(-20.0, min(20.0, gainDb))
        self.currentPresetName = "Custom"
        applyEqualizer()
    }
    
    public func setPreampGain(gainDb: Float) {
        equalizerPreamp = max(-20.0, min(20.0, gainDb))
        self.currentPresetName = "Custom"
        applyEqualizer()
    }
    
    private func applyEqualizer() {
        guard let player = mediaPlayer, let eq = equalizer else { return }
        if !equalizerEnabled {
            libvlc_media_player_set_equalizer(player, nil)
            return
        }
        
        libvlc_audio_equalizer_set_preamp(eq, equalizerPreamp)
        for (idx, gain) in equalizerBands.enumerated() {
            libvlc_audio_equalizer_set_amp_at_index(eq, gain, UInt32(idx))
        }
        libvlc_media_player_set_equalizer(player, eq)
    }
    
    // MARK: - A-B Loop Playback
    
    public func setPointA() {
        self.abPointAMs = currentTimeMs
        showStatusToast("Point A set at \(formatTime(currentTimeMs))")
        if let b = abPointBMs, b > currentTimeMs {
            self.abLoopEnabled = true
        }
    }
    
    public func setPointB() {
        if let a = abPointAMs, currentTimeMs > a {
            self.abPointBMs = currentTimeMs
            self.abLoopEnabled = true
            showStatusToast("A-B Loop Active (\(formatTime(a)) -> \(formatTime(currentTimeMs)))")
        } else {
            showStatusToast("Point B must be after Point A")
        }
    }
    
    public func clearABLoop() {
        self.abLoopEnabled = false
        self.abPointAMs = nil
        self.abPointBMs = nil
        showStatusToast("A-B Loop Cleared")
    }
    
    // MARK: - Periodic Status Update Loop
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func tick() {
        guard let player = mediaPlayer else { return }
        
        let rawState = libvlc_media_player_get_state(player)
        // LibVLC states: 0=NothingSpecial, 1=Opening, 2=Buffering, 3=Playing, 4=Paused, 5=Stopped, 6=Ended, 7=Error
        let newState: PlayerState
        switch rawState {
        case libvlc_Opening: newState = .opening
        case libvlc_Buffering: newState = .buffering
        case libvlc_Playing: newState = .playing
        case libvlc_Paused: newState = .paused
        case libvlc_Stopped: newState = .stopped
        case libvlc_Ended: newState = .ended
        case libvlc_Error: newState = .error
        default: newState = .idle
        }
        
        if self.state != newState {
            self.state = newState
            if newState == .playing {
                refreshTracks()
            } else if newState == .error {
                if self.errorMessage == nil {
                    self.errorMessage = "Playback failed: Unable to open media source or network stream. Check URL or network connection."
                }
            }
        }
        
        guard newState == .playing || newState == .paused || newState == .buffering else {
            if hasVideo && (newState == .stopped || newState == .ended || newState == .error) {
                hasVideo = false
            }
            updateVisualizer(active: false)
            return
        }
        
        let vouts = libvlc_media_player_has_vout(player)
        let isVideo = vouts > 0
        if self.hasVideo != isVideo {
            self.hasVideo = isVideo
        }
        
        let length = libvlc_media_player_get_length(player)
        if length > 0 && self.durationMs != length {
            self.durationMs = length
        }
        
        if !isUserSeeking {
            let current = libvlc_media_player_get_time(player)
            if current >= 0 {
                self.currentTimeMs = current
                if length > 0 {
                    self.position = Double(current) / Double(length)
                }
            }
            
            // Check A-B Loop boundaries
            if abLoopEnabled, let a = abPointAMs, let b = abPointBMs, b > a {
                if current >= b {
                    seek(toMs: a)
                }
            }
        }
        
        updateVisualizer(active: newState == .playing)
    }
    
    private func updateVisualizer(active: Bool) {
        if !active {
            for i in 0..<visualizerLevels.count {
                visualizerLevels[i] = max(0.05, visualizerLevels[i] * 0.8)
            }
            return
        }
        
        let volFactor = CGFloat(volume) / 100.0
        for i in 0..<visualizerLevels.count {
            let target = CGFloat.random(in: 0.15...0.95) * volFactor
            visualizerLevels[i] = visualizerLevels[i] * 0.4 + target * 0.6
        }
    }
    
    public func showStatusToast(_ message: String) {
        self.statusToast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.statusToast == message {
                self?.statusToast = nil
            }
        }
    }
    
    private func formatTime(_ ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
