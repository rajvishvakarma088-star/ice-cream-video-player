import SwiftUI

public struct MediaInfoView: View {
    @ObservedObject var player = VLCPlayerEngine.shared
    @ObservedObject var playlist = PlaylistManager.shared
    
    var onClose: () -> Void
    
    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))
                
                Text("Media Information")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    infoRow(title: "Title", value: player.currentMediaTitle ?? "None")
                    
                    if let url = player.currentMediaURL {
                        infoRow(title: "Location", value: url.absoluteString)
                        infoRow(title: "Format", value: url.pathExtension.uppercased().isEmpty ? "Stream" : url.pathExtension.uppercased())
                    }
                    
                    infoRow(title: "State", value: player.state.rawValue)
                    infoRow(title: "Current Time", value: formatTime(player.currentTimeMs))
                    infoRow(title: "Total Duration", value: formatTime(player.durationMs))
                    infoRow(title: "Playback Speed", value: String(format: "%.2fx", player.rate))
                    infoRow(title: "Aspect Ratio", value: player.aspectRatio)
                    
                    Divider()
                    
                    Text("Audio Streams")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    if player.audioTracks.isEmpty {
                        Text("No active audio streams detected")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        ForEach(player.audioTracks) { track in
                            HStack {
                                Text(track.name)
                                    .font(.system(size: 11))
                                Spacer()
                                if track.id == player.selectedAudioTrackId {
                                    Text("Active")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Text("Subtitle Streams")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    if player.subtitleTracks.isEmpty {
                        Text("No active subtitle streams detected")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        ForEach(player.subtitleTracks) { track in
                            HStack {
                                Text(track.name)
                                    .font(.system(size: 11))
                                Spacer()
                                if track.id == player.selectedSubtitleTrackId {
                                    Text("Active")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
        }
        .padding(20)
        .frame(width: 480, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
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
