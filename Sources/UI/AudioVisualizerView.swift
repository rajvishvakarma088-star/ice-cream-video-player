import SwiftUI

public struct AudioVisualizerView: View {
    @ObservedObject var player = VLCPlayerEngine.shared
    
    public init() {}
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<player.visualizerLevels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.9),
                                Color.red.opacity(0.8),
                                Color.purple.opacity(0.7)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: 8,
                        height: max(6, player.visualizerLevels[index] * 80)
                    )
                    .animation(.easeOut(duration: 0.12), value: player.visualizerLevels[index])
            }
        }
        .frame(height: 90)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
