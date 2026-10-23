import SwiftUI
import AppKit

public struct DropZoneView: View {
    @ObservedObject var playlist = PlaylistManager.shared
    @ObservedObject var player = VLCPlayerEngine.shared
    @State private var isTargeted: Bool = false
    
    var onOpenFile: () -> Void
    var onOpenFolder: () -> Void
    var onOpenStream: () -> Void
    
    public init(
        onOpenFile: @escaping () -> Void,
        onOpenFolder: @escaping () -> Void,
        onOpenStream: @escaping () -> Void
    ) {
        self.onOpenFile = onOpenFile
        self.onOpenFolder = onOpenFolder
        self.onOpenStream = onOpenStream
    }
    
    public var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // If audio is playing, show visualizer and track info!
                if player.state == .playing || player.state == .paused {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(.orange)
                            .shadow(color: .orange.opacity(0.4), radius: 12)
                        
                        Text(player.currentMediaTitle ?? "Playing Audio")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 40)
                        
                        AudioVisualizerView()
                    }
                } else {
                    // Idle Dropzone
                    VStack(spacing: 16) {
                        // Ice-Cream Player icon with subtle ambient glow
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            AppleTheme.actionBlue.opacity(0.35),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 75
                                    )
                                )
                                .frame(width: 140, height: 140)
                            
                            Image(systemName: "play.tv.fill")
                                .font(.system(size: 54, weight: .medium))
                                .foregroundColor(AppleTheme.actionBlue)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Drop Media Files or Folders Here")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Plays MP4, MKV, AVI, MOV, WMV, FLV, WebM, TS, VOB, 3GP, DivX, RMVB, ASF, MXF, MP3, FLAC & Network Streams")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Quick Action Buttons
                    HStack(spacing: 14) {
                        Button(action: onOpenFile) {
                            Label("Open File...", systemImage: "doc.badge.plus")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppleTheme.actionBlue)
                        .applePressable()
                        
                        Button(action: onOpenFolder) {
                            Label("Open Folder...", systemImage: "folder.badge.plus")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .applePressable()
                        
                        Button(action: onOpenStream) {
                            Label("Stream URL...", systemImage: "network")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .applePressable()
                    }
                    .controlSize(.regular)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isTargeted ? Color.orange : Color.white.opacity(0.1),
                        lineWidth: isTargeted ? 2 : 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(isTargeted ? 0.05 : 0.02))
                    )
            )
            .padding(40)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            var loadedURLs: [URL] = []
            let group = DispatchGroup()
            
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        loadedURLs.append(url)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                if !loadedURLs.isEmpty {
                    playlist.add(urls: loadedURLs)
                }
            }
            return true
        }
    }
}
