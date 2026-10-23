import SwiftUI
import AppKit

@main
struct VLCPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var player = VLCPlayerEngine.shared
    @ObservedObject var playlist = PlaylistManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .navigationTitle("Ice-Cream Player")
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            // MARK: - File Menu
            CommandGroup(replacing: .newItem) {
                Button("Open File...") {
                    openFile()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Open Folder...") {
                    openFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                
                Button("Open Network Stream...") {
                    openNetworkStream()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Divider()
                
                Button("Load External Subtitle...") {
                    loadSubtitle()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            
            // MARK: - Playback Menu
            CommandMenu("Playback") {
                Button(player.state == .playing ? "Pause" : "Play") {
                    player.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button("Stop") {
                    player.stop()
                }
                .keyboardShortcut(".", modifiers: .command)
                
                Divider()
                
                Button("Previous") {
                    playlist.playPrevious()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                
                Button("Next") {
                    playlist.playNext()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                
                Divider()
                
                Button("Jump Backward 10s") {
                    player.jump(bySeconds: -10)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Button("Jump Forward 10s") {
                    player.jump(bySeconds: 10)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                
                Button("Next Frame") {
                    player.nextFrame()
                }
                .keyboardShortcut(.rightArrow, modifiers: .shift)
                
                Divider()
                
                Button("Faster") {
                    player.setRate(min(4.0, player.rate + 0.25))
                }
                .keyboardShortcut("]", modifiers: .command)
                
                Button("Slower") {
                    player.setRate(max(0.25, player.rate - 0.25))
                }
                .keyboardShortcut("[", modifiers: .command)
                
                Button("Normal Speed") {
                    player.setRate(1.0)
                }
                .keyboardShortcut("=", modifiers: .command)
                
                Divider()
                
                Button("Toggle A-B Loop") {
                    if player.abLoopEnabled {
                        player.clearABLoop()
                    } else if player.abPointAMs == nil {
                        player.setPointA()
                    } else {
                        player.setPointB()
                    }
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Button("Add Bookmark") {
                    playlist.addBookmark()
                }
                .keyboardShortcut("b", modifiers: .command)
            }
            
            // MARK: - Audio Menu
            CommandMenu("Audio") {
                Button("Volume Up") {
                    player.setVolume(min(200, player.volume + 5))
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                
                Button("Volume Down") {
                    player.setVolume(max(0, player.volume - 5))
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                
                Button(player.isMuted ? "Unmute" : "Mute") {
                    player.toggleMute()
                }
                .keyboardShortcut("m", modifiers: [])
                
                Divider()
                
                Menu("Audio Track") {
                    ForEach(player.audioTracks) { track in
                        Button(track.name) {
                            player.setAudioTrack(id: track.id)
                        }
                    }
                }
                
                Button("Equalizer...") {
                    // Handled in UI
                }
                .keyboardShortcut("e", modifiers: .command)
            }
            
            // MARK: - Video Menu
            CommandMenu("Video") {
                Button("Toggle Full Screen") {
                    if let win = NSApplication.shared.keyWindow {
                        win.toggleFullScreen(nil)
                    }
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Divider()
                
                Menu("Aspect Ratio") {
                    ForEach(["Default", "16:9", "4:3", "1:1", "16:10", "2.21:1", "2.35:1"], id: \.self) { ratio in
                        Button(ratio) {
                            player.setAspectRatio(ratio)
                        }
                    }
                }
                
                Divider()
                
                Button("Take Snapshot") {
                    player.takeSnapshot()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }
        }
    }
    
    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audiovisualContent, .audio, .movie]
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK {
            playlist.add(urls: panel.urls)
        }
    }
    
    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            playlist.add(urls: panel.urls)
        }
    }
    
    private func openNetworkStream() {
        // Handled via state or prompt
    }
    
    private func loadSubtitle() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            player.loadExternalSubtitle(fileURL: url)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        PlaylistManager.shared.add(urls: urls)
    }
}
