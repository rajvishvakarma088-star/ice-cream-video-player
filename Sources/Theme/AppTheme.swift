import SwiftUI
import AppKit

public enum ThemeMode: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"
    
    public var id: String { rawValue }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
    
    public var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}

public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @Published public var currentTheme: ThemeMode {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "icecream_theme_mode")
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "icecream_theme_mode"),
           let theme = ThemeMode(rawValue: saved) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .dark
        }
    }
    
    public func cycleTheme() {
        switch currentTheme {
        case .dark: currentTheme = .light
        case .light: currentTheme = .system
        case .system: currentTheme = .dark
        }
    }
}

public struct AppleTheme {
    // MARK: - Brand & Accent
    public static let actionBlue = Color(red: 0x00/255.0, green: 0x66/255.0, blue: 0xCC/255.0) // #0066cc
    public static let focusBlue = Color(red: 0x00/255.0, green: 0x71/255.0, blue: 0xE3/255.0)  // #0071e3
    public static let skyLinkBlue = Color(red: 0x29/255.0, green: 0x97/255.0, blue: 0xFF/255.0) // #2997ff
    
    // MARK: - Surface
    public static let canvas = Color.white // #ffffff
    public static let parchment = Color(red: 0xF5/255.0, green: 0xF5/255.0, blue: 0xF7/255.0) // #f5f5f7
    public static let pearlButton = Color(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFC/255.0) // #fafafc
    public static let tile1 = Color(red: 0x27/255.0, green: 0x27/255.0, blue: 0x29/255.0) // #272729 Near-Black Tile 1
    public static let tile2 = Color(red: 0x2A/255.0, green: 0x2A/255.0, blue: 0x2C/255.0) // #2a2a2c Near-Black Tile 2
    public static let tile3 = Color(red: 0x25/255.0, green: 0x25/255.0, blue: 0x27/255.0) // #252527 Near-Black Tile 3
    public static let surfaceBlack = Color.black // #000000 Pure Black
    public static let chipTranslucent = Color(red: 210/255.0, green: 210/255.0, blue: 215/255.0).opacity(0.64)
    
    // MARK: - Text & Ink
    public static let ink = Color(red: 0x1D/255.0, green: 0x1D/255.0, blue: 0x1F/255.0) // #1d1d1f Near-Black Ink
    public static let bodyOnDark = Color.white // #ffffff
    public static let bodyMuted = Color(red: 0xCC/255.0, green: 0xCC/255.0, blue: 0xCC/255.0) // #cccccc
    public static let inkMuted80 = Color(red: 0x33/255.0, green: 0x33/255.0, blue: 0x33/255.0) // #333333
    public static let inkMuted48 = Color(red: 0x7A/255.0, green: 0x7A/255.0, blue: 0x7A/255.0) // #7a7a7a
    
    // MARK: - Hairlines & Dividers
    public static let dividerSoft = Color(red: 0xF0/255.0, green: 0xF0/255.0, blue: 0xF0/255.0) // #f0f0f0
    public static let hairline = Color(red: 0xE0/255.0, green: 0xE0/255.0, blue: 0xE0/255.0) // #e0e0e0
    
    // MARK: - Border Radii
    public static let radiusSm: CGFloat = 8
    public static let radiusMd: CGFloat = 11
    public static let radiusLg: CGFloat = 18
    public static let radiusPill: CGFloat = 9999
}

// Backwards-compatible facade and dynamic surface resolution
public struct LiquidGlass {
    public static let accent = AppleTheme.actionBlue
    public static let actionBlue = AppleTheme.actionBlue
    public static let focusBlue = AppleTheme.focusBlue
    public static let skyLinkBlue = AppleTheme.skyLinkBlue
    public static let iceCreamPink = Color(red: 0.0, green: 0.4, blue: 0.8) // harmonized to Apple blue
    public static let iceCreamPurple = Color(red: 0.35, green: 0.45, blue: 0.95)
    public static let youtubeRed = Color(red: 0.95, green: 0.2, blue: 0.2)
    
    public static let brandGradient = LinearGradient(
        colors: [AppleTheme.actionBlue, Color(red: 0.1, green: 0.45, blue: 0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Backgrounds & Surfaces
    public static func surfaceBackground(isDark: Bool) -> Color {
        isDark ? AppleTheme.tile1 : AppleTheme.parchment
    }
    
    public static func sidebarBackground(isDark: Bool) -> Color {
        isDark ? AppleTheme.tile2 : AppleTheme.canvas
    }
    
    public static func cardBackground(isDark: Bool) -> Color {
        isDark ? AppleTheme.tile3 : AppleTheme.canvas
    }
    
    public static func cardHoverBackground(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.08) : AppleTheme.pearlButton
    }
    
    public static func cardBorder(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.08) : AppleTheme.hairline.opacity(0.7)
    }
    
    public static func hudBackground(isDark: Bool) -> Color {
        isDark ? AppleTheme.tile3.opacity(0.92) : AppleTheme.parchment.opacity(0.92)
    }
    
    public static func textPrimary(isDark: Bool) -> Color {
        isDark ? AppleTheme.bodyOnDark : AppleTheme.ink
    }
    
    public static func textSecondary(isDark: Bool) -> Color {
        isDark ? AppleTheme.bodyMuted : AppleTheme.inkMuted80
    }
    
    public static func textTertiary(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.48) : AppleTheme.inkMuted48
    }
    
    public static func interactiveColor(isDark: Bool) -> Color {
        isDark ? AppleTheme.skyLinkBlue : AppleTheme.actionBlue
    }
}

// Apple Micro-interaction Button Style: scale(0.95) on press
public struct ApplePressableButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// Visual Glass / Utility Card Modifier
public struct GlassCardModifier: ViewModifier {
    var isDark: Bool
    var cornerRadius: CGFloat = 18
    var strokeColor: Color? = nil
    
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LiquidGlass.cardBackground(isDark: isDark))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor ?? LiquidGlass.cardBorder(isDark: isDark), lineWidth: 1)
            )
            // Whisper-soft elevation: single product drop shadow rgba(0, 0, 0, 0.22) 3px 5px 30px
            .shadow(color: isDark ? Color.black.opacity(0.25) : Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

public extension View {
    func glassCard(isDark: Bool, cornerRadius: CGFloat = 18, strokeColor: Color? = nil) -> some View {
        self.modifier(GlassCardModifier(isDark: isDark, cornerRadius: cornerRadius, strokeColor: strokeColor))
    }
    
    func applePressable() -> some View {
        self.buttonStyle(ApplePressableButtonStyle())
    }
}
