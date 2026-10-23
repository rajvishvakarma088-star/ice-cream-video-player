import Foundation
import SwiftUI

public enum AppMode: String, CaseIterable, Identifiable, Codable {
    case classic = "Classic VLC"
    case pro = "YouTube Pro"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .classic: return "cone.fill"
        case .pro: return "play.rectangle.on.rectangle.fill"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .classic: return "Desktop Media Player"
        case .pro: return "Modern Media Discovery"
        }
    }
}
