import SwiftUI
import AppKit

public struct EqualizerView: View {
    @ObservedObject var player = VLCPlayerEngine.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var onClose: (() -> Void)?
    
    public init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }
    
    private var isDark: Bool {
        switch themeManager.currentTheme {
        case .dark: return true
        case .light: return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }
    
    private func handleClose() {
        if let onClose = onClose {
            onClose()
        } else {
            dismiss()
        }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppleTheme.actionBlue.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "slider.vertical.3")
                        .foregroundColor(AppleTheme.actionBlue)
                        .font(.system(size: 15, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Graphic Equalizer")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                    Text("10-Band Precision Audio Equalizer & Preamp")
                        .font(.system(size: 10))
                        .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                }
                
                Spacer()
                
                // Enable Toggle Switch
                Toggle("", isOn: Binding(
                    get: { player.equalizerEnabled },
                    set: { player.setEqualizerEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(player.equalizerEnabled ? "Disable Equalizer" : "Enable Equalizer")
                
                Text(player.equalizerEnabled ? "ON" : "OFF")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(player.equalizerEnabled ? AppleTheme.actionBlue : LiquidGlass.textTertiary(isDark: isDark))
                    .frame(width: 24)
                
                Divider().frame(height: 18)
                
                // Cross Close Button
                Button(action: handleClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                }
                .buttonStyle(.plain)
                .applePressable()
                .help("Close Equalizer")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Presets Picker Row
            HStack(spacing: 10) {
                Text("Preset Profile:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                
                Picker("", selection: Binding(
                    get: { player.currentPresetName },
                    set: { newName in
                        if let preset = AudioEqualizerPreset.standardPresets.first(where: { $0.name == newName }) {
                            player.setEqualizerPreset(preset)
                        }
                    }
                )) {
                    ForEach(AudioEqualizerPreset.standardPresets) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                    if player.currentPresetName == "Custom" {
                        Text("Custom").tag("Custom")
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                Spacer()
                
                Button("Flat (Reset)") {
                    if let flat = AudioEqualizerPreset.standardPresets.first(where: { $0.name == "Flat" }) {
                        player.setEqualizerPreset(flat)
                    }
                }
                .buttonStyle(.bordered)
                .applePressable()
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            
            Divider().padding(.horizontal, 20)
            
            // Sliders: Preamp + 10 Frequency Bands
            HStack(spacing: 12) {
                // Preamp Slider
                VStack(spacing: 6) {
                    Text(String(format: "%+.1fdB", player.equalizerPreamp))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppleTheme.actionBlue)
                    
                    Slider(
                        value: Binding(
                            get: { Double(player.equalizerPreamp) },
                            set: { player.setPreampGain(gainDb: Float($0)) }
                        ),
                        in: -20.0...20.0
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                    .accentColor(AppleTheme.actionBlue)
                    
                    Text("Preamp")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                }
                
                Divider().frame(height: 140)
                
                // 10 Frequency Bands
                ForEach(0..<10, id: \.self) { index in
                    let val = player.equalizerBands[index]
                    VStack(spacing: 6) {
                        Text(String(format: "%+.1f", val))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(val != 0 ? AppleTheme.actionBlue : LiquidGlass.textTertiary(isDark: isDark))
                        
                        Slider(
                            value: Binding(
                                get: { Double(player.equalizerBands[index]) },
                                set: { player.setBandGain(index: index, gainDb: Float($0)) }
                            ),
                            in: -20.0...20.0
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                        .accentColor(AppleTheme.actionBlue)
                        
                        Text(AudioEqualizerPreset.bandFrequencies[index])
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 680, height: 285)
        .background(isDark ? AppleTheme.surfaceBlack : AppleTheme.parchment)
        .cornerRadius(12)
    }
}
