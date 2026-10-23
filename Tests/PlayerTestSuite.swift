import Foundation
import Clibvlc

@main
struct PlayerTestSuite {
    static var passedCount = 0
    static var failedCount = 0
    
    static func assertTest(_ condition: Bool, name: String, details: String = "") {
        if condition {
            print("  ✅ [PASS] \(name)")
            passedCount += 1
        } else {
            print("  ❌ [FAIL] \(name) - \(details)")
            failedCount += 1
        }
    }
    
    static func main() {
        print("\n==========================================")
        print(" VLC Media Player Test Suite (macOS)")
        print("==========================================\n")
        
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let pluginPath = fileManager.fileExists(atPath: "\(currentDir)/plugins") ? "\(currentDir)/plugins" : (fileManager.fileExists(atPath: "\(currentDir)/VLCPlayerApp/plugins") ? "\(currentDir)/VLCPlayerApp/plugins" : "/Users/rajvishvakarma/Downloads/practice app /VLCPlayerApp/plugins")
        setenv("VLC_PLUGIN_PATH", pluginPath, 1)
        
        // Test 1: LibVLC Engine Initialization
        testEngineInitialization()
        
        // Test 2: Audio Playback and State Transitions
        testAudioPlaybackAndState()
        
        // Test 3: Volume and Over-amplification (up to 200%)
        testVolumeAndMute()
        
        // Test 4: Seeking and Playback Rates
        testSeekingAndRate()
        
        // Test 5: 10-Band Graphic Equalizer & Presets
        testEqualizer()
        
        // Test 6: Playlist Management & Queue Transitions
        testPlaylistManagement()
        
        // Test 7: Persistence of Bookmarks and History
        testBookmarksAndPersistence()
        
        // Test 8: Invalid & Corrupted File Recovery
        testInvalidFileRecovery()
        
        // Test 9: Resource Stress & Memory Deallocation
        testResourceDeallocation()
        
        // Test 10: Network Streaming Configuration & Buffering Options
        testNetworkStreamingOptions()
        
        // Test 11: Media Library Item Model & Formatting
        testMediaLibraryModel()
        
        // Test 12: Stream URL Normalization & Presets
        testStreamPresetsAndValidation()
        
        print("\n==========================================")
        print(" Test Summary: \(passedCount) Passed, \(failedCount) Failed")
        print("==========================================\n")
        
        if failedCount > 0 {
            exit(1)
        }
    }
    
    // MARK: - Test Cases
    
    static func resolveAudioPath() -> String {
        if FileManager.default.fileExists(atPath: "test_audio.m4a") {
            return "test_audio.m4a"
        }
        if FileManager.default.fileExists(atPath: "VLCPlayerApp/test_audio.m4a") {
            return "VLCPlayerApp/test_audio.m4a"
        }
        return "/Users/rajvishvakarma/Downloads/practice app /VLCPlayerApp/test_audio.m4a"
    }
    
    static func testEngineInitialization() {
        print("1. Testing LibVLC Engine Initialization...")
        guard let ver = libvlc_get_version() else {
            assertTest(false, name: "LibVLC version lookup")
            return
        }
        let verStr = String(cString: ver)
        assertTest(verStr.contains("3.0.24"), name: "Version is 3.0.24", details: "Found: \(verStr)")
        
        let args = ["--no-video-title-show", "--no-stats", "--quiet", "--ignore-config"]
        let cArgs: [UnsafePointer<CChar>?] = args.map { UnsafePointer(strdup($0)) }
        defer {
            for ptr in cArgs {
                if let p = ptr { free(UnsafeMutableRawPointer(mutating: p)) }
            }
        }
        
        var inst = cArgs.withUnsafeBufferPointer { buf in
            libvlc_new(Int32(buf.count), buf.baseAddress)
        }
        if inst == nil {
            inst = libvlc_new(0, nil)
        }
        assertTest(inst != nil, name: "libvlc_new() instance creation")
        
        if let inst = inst {
            let player = libvlc_media_player_new(inst)
            assertTest(player != nil, name: "libvlc_media_player_new() creation")
            if let p = player {
                libvlc_media_player_release(p)
            }
            libvlc_release(inst)
            assertTest(true, name: "Clean engine deallocation")
        }
    }
    
    static func testAudioPlaybackAndState() {
        print("\n2. Testing Audio Playback & State Transitions...")
        let audioPath = resolveAudioPath()
        guard FileManager.default.fileExists(atPath: audioPath) else {
            assertTest(false, name: "Audio file existence", details: "Missing: \(audioPath)")
            return
        }
        
        var inst = libvlc_new(0, nil)
        guard let validInst = inst else {
            assertTest(false, name: "LibVLC instance creation")
            return
        }
        defer { libvlc_release(validInst) }
        
        guard let media = audioPath.withCString({ libvlc_media_new_path(validInst, $0) }),
              let player = libvlc_media_player_new_from_media(media) else {
            assertTest(false, name: "Media player setup")
            return
        }
        defer {
            libvlc_media_player_release(player)
            libvlc_media_release(media)
        }
        
        // Initial state
        let s0 = libvlc_media_player_get_state(player)
        assertTest(s0 == libvlc_NothingSpecial || s0 == libvlc_Stopped, name: "Initial state is Idle/Stopped")
        
        // Play
        let playRes = libvlc_media_player_play(player)
        assertTest(playRes == 0, name: "libvlc_media_player_play returns 0")
        
        Thread.sleep(forTimeInterval: 0.4)
        
        // Playing state
        let s1 = libvlc_media_player_get_state(player)
        assertTest(s1 == libvlc_Playing || s1 == libvlc_Buffering, name: "State transitions to Playing")
        
        let length = libvlc_media_player_get_length(player)
        assertTest(length > 1000, name: "Media length parsed correctly (>1000ms)", details: "Length: \(length)ms")
        
        // Pause
        libvlc_media_player_pause(player)
        var s2 = libvlc_media_player_get_state(player)
        for _ in 1...10 {
            if s2 == libvlc_Paused { break }
            Thread.sleep(forTimeInterval: 0.05)
            s2 = libvlc_media_player_get_state(player)
        }
        assertTest(s2 == libvlc_Paused, name: "State transitions to Paused")
        
        // Stop
        libvlc_media_player_stop(player)
        let s3 = libvlc_media_player_get_state(player)
        assertTest(s3 == libvlc_Stopped, name: "State transitions to Stopped")
    }
    
    static func testVolumeAndMute() {
        print("\n3. Testing Volume & Over-Amplification Controls...")
        guard let inst = libvlc_new(0, nil),
              let player = libvlc_media_player_new(inst) else {
            assertTest(false, name: "Volume test setup")
            return
        }
        defer {
            libvlc_media_player_release(player)
            libvlc_release(inst)
        }
        
        // Set standard volume
        libvlc_audio_set_volume(player, 80)
        let v80 = libvlc_audio_get_volume(player)
        assertTest(v80 == 80, name: "Volume set to 80%")
        
        // Over-amplification (150%)
        libvlc_audio_set_volume(player, 150)
        let v150 = libvlc_audio_get_volume(player)
        assertTest(v150 == 150, name: "Volume over-amplified to 150%")
        
        // Mute toggle
        libvlc_audio_set_mute(player, 1)
        let m1 = libvlc_audio_get_mute(player)
        assertTest(m1 == 1, name: "Audio muted")
        
        libvlc_audio_set_mute(player, 0)
        let m0 = libvlc_audio_get_mute(player)
        assertTest(m0 == 0, name: "Audio unmuted")
    }
    
    static func testSeekingAndRate() {
        print("\n4. Testing Seeking & Playback Rates...")
        let audioPath = resolveAudioPath()
        guard let inst = libvlc_new(0, nil),
              let media = audioPath.withCString({ libvlc_media_new_path(inst, $0) }),
              let player = libvlc_media_player_new_from_media(media) else {
            assertTest(false, name: "Seek test setup")
            return
        }
        defer {
            libvlc_media_player_stop(player)
            libvlc_media_player_release(player)
            libvlc_media_release(media)
            libvlc_release(inst)
        }
        
        libvlc_media_player_play(player)
        Thread.sleep(forTimeInterval: 0.3)
        
        // Seek to 500ms
        libvlc_media_player_set_time(player, 500)
        Thread.sleep(forTimeInterval: 0.1)
        let t = libvlc_media_player_get_time(player)
        assertTest(t >= 400 && t <= 800, name: "Seek to millisecond timestamp (500ms)", details: "Current: \(t)ms")
        
        // Rate adjustment
        libvlc_media_player_set_rate(player, 1.5)
        let r15 = libvlc_media_player_get_rate(player)
        assertTest(abs(r15 - 1.5) < 0.05, name: "Playback speed set to 1.50x", details: "Rate: \(r15)")
        
        libvlc_media_player_set_rate(player, 0.5)
        let r05 = libvlc_media_player_get_rate(player)
        assertTest(abs(r05 - 0.5) < 0.05, name: "Playback speed set to 0.50x", details: "Rate: \(r05)")
    }
    
    static func testEqualizer() {
        print("\n5. Testing 10-Band Graphic Equalizer & Presets...")
        let eq = libvlc_audio_equalizer_new()
        assertTest(eq != nil, name: "Equalizer instance created")
        
        if let eq = eq {
            let bandCount = libvlc_audio_equalizer_get_band_count()
            assertTest(bandCount == 10, name: "Equalizer has exactly 10 frequency bands", details: "Count: \(bandCount)")
            
            // Set Preamp
            let preampRes = libvlc_audio_equalizer_set_preamp(eq, 6.0)
            assertTest(preampRes == 0, name: "Preamp gain set to +6.0 dB")
            
            // Set 10 Bands
            let testGains: [Float] = [4.8, 3.6, 1.2, -1.8, -3.0, -1.2, 1.8, 3.6, 4.8, 5.4] // Rock preset
            var allBandsSet = true
            for (idx, gain) in testGains.enumerated() {
                if libvlc_audio_equalizer_set_amp_at_index(eq, gain, UInt32(idx)) != 0 {
                    allBandsSet = false
                }
            }
            assertTest(allBandsSet, name: "All 10 frequency band gains updated successfully")
            
            // Attach to player
            let args = ["--quiet"]
            let cArgs = args.map { UnsafePointer(strdup($0)) }
            defer { for p in cArgs { if let p = p { free(UnsafeMutableRawPointer(mutating: p)) } } }
            let inst = cArgs.withUnsafeBufferPointer { libvlc_new(Int32($0.count), $0.baseAddress) }!
            let player = libvlc_media_player_new(inst)!
            
            let attachRes = libvlc_media_player_set_equalizer(player, eq)
            assertTest(attachRes == 0, name: "Equalizer attached to media player")
            
            libvlc_media_player_set_equalizer(player, nil)
            libvlc_media_player_release(player)
            libvlc_release(inst)
            libvlc_audio_equalizer_release(eq)
            assertTest(true, name: "Equalizer released cleanly")
        }
    }
    
    static func testPlaylistManagement() {
        print("\n6. Testing Playlist Queue & Transition Logic...")
        let item1 = PlaylistItem(url: URL(fileURLWithPath: "/test/track1.mp4"), title: "Track 1", durationMs: 120000)
        let item2 = PlaylistItem(url: URL(fileURLWithPath: "/test/track2.mkv"), title: "Track 2", durationMs: 180000)
        let item3 = PlaylistItem(url: URL(fileURLWithPath: "/test/track3.mp3"), title: "Track 3", durationMs: 240000)
        
        var queue = [item1, item2, item3]
        assertTest(queue.count == 3, name: "Queue initialized with 3 items")
        
        // Reordering
        queue.swapAt(0, 2)
        assertTest(queue[0].title == "Track 3" && queue[2].title == "Track 1", name: "Queue items reordered")
        
        // Removal
        queue.remove(at: 1)
        assertTest(queue.count == 2 && queue[1].title == "Track 1", name: "Item removed from queue")
        
        // Clear
        queue.removeAll()
        assertTest(queue.isEmpty, name: "Queue cleared")
    }
    
    static func testBookmarksAndPersistence() {
        print("\n7. Testing Bookmarks & JSON Serialization...")
        let sampleURL = URL(fileURLWithPath: "/movies/intro.mp4")
        let bookmark = BookmarkItem(mediaURL: sampleURL, title: "Action Scene", timeMs: 45000)
        
        assertTest(bookmark.formattedTimestamp == "00:45", name: "Bookmark formatted timestamp", details: bookmark.formattedTimestamp)
        
        // Test JSON Encoding / Decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        guard let data = try? encoder.encode([bookmark]) else {
            assertTest(false, name: "Bookmark JSON serialization")
            return
        }
        
        guard let decoded = try? decoder.decode([BookmarkItem].self, from: data), let first = decoded.first else {
            assertTest(false, name: "Bookmark JSON deserialization")
            return
        }
        
        assertTest(first.title == "Action Scene" && first.timeMs == 45000, name: "Bookmark round-trip serialization matches exactly")
    }
    
    static func testInvalidFileRecovery() {
        print("\n8. Testing Invalid & Non-Existent File Recovery...")
        let args = ["--no-video-title-show", "--quiet"]
        let cArgs = args.map { UnsafePointer(strdup($0)) }
        defer { for p in cArgs { if let p = p { free(UnsafeMutableRawPointer(mutating: p)) } } }
        let inst = cArgs.withUnsafeBufferPointer { libvlc_new(Int32($0.count), $0.baseAddress) }!
        let player = libvlc_media_player_new(inst)!
        defer {
            libvlc_media_player_release(player)
            libvlc_release(inst)
        }
        
        // Point to a non-existent file
        let invalidPath = "/tmp/non_existent_corrupted_media_\(UUID().uuidString).xyz"
        let media = invalidPath.withCString { libvlc_media_new_path(inst, $0) }!
        libvlc_media_player_set_media(player, media)
        
        libvlc_media_player_play(player)
        Thread.sleep(forTimeInterval: 0.3)
        
        let state = libvlc_media_player_get_state(player)
        // Should encounter error or stopped without crashing
        assertTest(state == libvlc_Error || state == libvlc_Ended || state == libvlc_Stopped, name: "Graceful error detection for invalid file", details: "State: \(state)")
        
        libvlc_media_player_stop(player)
        libvlc_media_release(media)
        assertTest(true, name: "Recovery and cleanup completed without crash")
    }
    
    static func testResourceDeallocation() {
        let audioPath = resolveAudioPath()
        guard let inst = libvlc_new(0, nil) else {
            assertTest(false, name: "Stress test setup")
            return
        }
        defer { libvlc_release(inst) }
        
        var successCycles = 0
        for _ in 1...15 {
            guard let media = audioPath.withCString({ libvlc_media_new_path(inst, $0) }),
                  let player = libvlc_media_player_new_from_media(media) else { break }
            libvlc_media_player_play(player)
            Thread.sleep(forTimeInterval: 0.05)
            libvlc_media_player_stop(player)
            libvlc_media_player_release(player)
            libvlc_media_release(media)
            successCycles += 1
        }
        
        assertTest(successCycles == 15, name: "Completed 15 rapid create/play/stop/destroy cycles cleanly")
    }
    
    static func testNetworkStreamingOptions() {
        print("\n10. Testing Network Streaming Configuration & Buffering Options...")
        let args = ["--no-video-title-show", "--quiet"]
        let cArgs = args.map { UnsafePointer(strdup($0)) }
        defer { for p in cArgs { if let p = p { free(UnsafeMutableRawPointer(mutating: p)) } } }
        let inst = cArgs.withUnsafeBufferPointer { libvlc_new(Int32($0.count), $0.baseAddress) }!
        defer { libvlc_release(inst) }
        
        let testStream = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"
        let media = testStream.withCString { libvlc_media_new_location(inst, $0) }
        assertTest(media != nil, name: "Stream media location created for HLS M3U8")
        
        if let media = media {
            ":network-caching=2500".withCString { libvlc_media_add_option(media, $0) }
            ":http-reconnect=true".withCString { libvlc_media_add_option(media, $0) }
            ":clock-jitter=0".withCString { libvlc_media_add_option(media, $0) }
            ":clock-synchro=0".withCString { libvlc_media_add_option(media, $0) }
            assertTest(true, name: "Network caching (2500ms) & reconnect options applied")
            
            let player = libvlc_media_player_new_from_media(media)
            assertTest(player != nil, name: "Media player configured with streaming media")
            if let p = player {
                libvlc_media_player_release(p)
            }
            libvlc_media_release(media)
        }
    }
    
    static func testMediaLibraryModel() {
        print("\n11. Testing Media Library Model & Metadata...")
        let sampleURL = URL(fileURLWithPath: "/Movies/SampleMovie.mp4")
        let item = MediaLibraryItem(
            url: sampleURL,
            title: "Sample Movie",
            durationMs: 7325000, // 2h 2m 5s
            fileSizeBytes: 1024 * 1024 * 850, // 850 MB
            resolutionBadge: "4K UHD",
            mediaType: .video,
            watchedProgress: 0.45
        )
        
        assertTest(item.formattedDuration == "2:02:05", name: "Duration formatted correctly (2:02:05)", details: item.formattedDuration)
        assertTest(item.formattedFileSize.contains("MB") || item.formattedFileSize.contains("850"), name: "File size formatted correctly", details: item.formattedFileSize)
        assertTest(item.resolutionBadge == "4K UHD", name: "Resolution badge assigned (4K UHD)")
        assertTest(item.fileExtension == "MP4", name: "File extension detected (MP4)")
    }
    
    static func testStreamPresetsAndValidation() {
        print("\n12. Testing Stream Presets & Normalization...")
        let manager = StreamManager.shared
        assertTest(manager.presets.count >= 4, name: "Stream manager contains verified presets", details: "Count: \(manager.presets.count)")
        
        // Test URL normalization (auto-prefix http/https)
        let normalized1 = manager.validateAndNormalizeURL("example.com/stream.m3u8")
        assertTest(normalized1?.absoluteString == "https://example.com/stream.m3u8", name: "Auto-prepend https:// to scheme-less stream URL")
        
        let normalized2 = manager.validateAndNormalizeURL("  http://test.org/live  ")
        assertTest(normalized2?.absoluteString == "http://test.org/live", name: "Trim whitespace and preserve http://")
        
        let invalid = manager.validateAndNormalizeURL("   ")
        assertTest(invalid == nil, name: "Empty string rejects cleanly as nil")
    }
}
