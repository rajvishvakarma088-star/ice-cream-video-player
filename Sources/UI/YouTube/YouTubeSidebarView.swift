import SwiftUI
import AppKit

public struct YouTubeSidebarView: View {
    @ObservedObject var library = MediaLibraryManager.shared
    @ObservedObject var playlist = PlaylistManager.shared
    @ObservedObject var streamManager = StreamManager.shared
    var isDark: Bool
    
    public init(isDark: Bool) {
        self.isDark = isDark
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Branding Header (Clean Apple Minimalist)
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppleTheme.radiusSm)
                        .fill(AppleTheme.actionBlue)
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "ice.cream.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Ice-Cream")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                    
                    Text("Media Library")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            Divider().opacity(0.3)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // Main Library Navigation
                    VStack(alignment: .leading, spacing: 3) {
                        YouTubeSidebarRow(
                            category: .home,
                            count: library.items.count,
                            isSelected: library.selectedCategory == .home && library.selectedFolder == nil,
                            isDark: isDark
                        ) {
                            library.selectedFolder = nil
                            library.selectedCategory = .home
                        }
                        
                        YouTubeSidebarRow(
                            category: .videos,
                            count: library.items.filter { $0.mediaType == .video }.count,
                            isSelected: library.selectedCategory == .videos && library.selectedFolder == nil,
                            isDark: isDark
                        ) {
                            library.selectedFolder = nil
                            library.selectedCategory = .videos
                        }
                        
                        YouTubeSidebarRow(
                            category: .music,
                            count: library.items.filter { $0.mediaType == .audio }.count,
                            isSelected: library.selectedCategory == .music && library.selectedFolder == nil,
                            isDark: isDark
                        ) {
                            library.selectedFolder = nil
                            library.selectedCategory = .music
                        }
                        
                        YouTubeSidebarRow(
                            category: .streams,
                            count: streamManager.presets.count,
                            isSelected: library.selectedCategory == .streams && library.selectedFolder == nil,
                            isDark: isDark
                        ) {
                            library.selectedFolder = nil
                            library.selectedCategory = .streams
                        }
                    }
                    
                    Divider().opacity(0.2)
                    
                    // Personal Collections Section
                    VStack(alignment: .leading, spacing: 3) {
                        Text("COLLECTIONS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                        
                        YouTubeSidebarRow(
                            category: .playlists,
                            count: playlist.items.count,
                            isSelected: library.selectedCategory == .playlists && library.selectedFolder == nil,
                            isDark: isDark
                        ) {
                            library.selectedFolder = nil
                            library.selectedCategory = .playlists
                        }
                        
                        YouTubeSidebarRow(
                            category: .history,
                            count: playlist.historyItems.count,
                            isSelected: library.selectedCategory == .history && library.selectedFolder == nil,
                            isDark: isDark
                        ) {
                            library.selectedFolder = nil
                            library.selectedCategory = .history
                        }
                        
                        YouTubeSidebarRow(
                            category: .favorites,
                            count: library.items.filter { $0.isFavorite }.count,
                            isSelected: library.selectedCategory == .favorites && library.selectedFolder == nil,
                            isDark: isDark
                        ) {
                            library.selectedFolder = nil
                            library.selectedCategory = .favorites
                        }
                    }
                    
                    Divider().opacity(0.2)
                    
                    // Folders Section
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("FOLDERS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                            
                            Spacer()
                            
                            // Scan Mac Action Button
                            Button(action: { library.promptGrantMacAccess() }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "sparkles")
                                    Text("Scan Mac")
                                }
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppleTheme.actionBlue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AppleTheme.actionBlue.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .applePressable()
                            .help("Scan Entire Mac for Videos & Music")
                            
                            // Add Folder Action Button
                            Button(action: { library.promptAddFolder() }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppleTheme.actionBlue)
                            }
                            .buttonStyle(.plain)
                            .applePressable()
                            .help("Add Media Folder")
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                        
                        ForEach(library.watchedFolders, id: \.path) { folder in
                            YouTubeFolderRow(
                                folder: folder,
                                isSelected: library.selectedFolder == folder,
                                isDark: isDark,
                                action: {
                                    library.selectedCategory = .folders
                                    library.selectedFolder = folder
                                },
                                onRescan: { library.scanFolder(folder) },
                                onRemove: { library.removeFolder(url: folder) }
                            )
                        }
                        
                        if library.watchedFolders.isEmpty {
                            Button(action: { library.promptAddFolder() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 12))
                                    Text("Add Folder...")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(AppleTheme.actionBlue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .applePressable()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Bottom Library Scan Status
            if library.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    
                    Text("Indexing files...")
                        .font(.system(size: 10))
                        .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.1))
            }
        }
        .frame(width: 216)
        .background(LiquidGlass.sidebarBackground(isDark: isDark))
    }
}

// MARK: - Dedicated Interactive Rows with High Sensitivity and Pointing Hand Cursor

struct YouTubeSidebarRow: View {
    let category: LibraryCategory
    let count: Int
    let isSelected: Bool
    let isDark: Bool
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: category.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? AppleTheme.actionBlue : LiquidGlass.textSecondary(isDark: isDark))
                    .frame(width: 18)
                
                Text(category.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppleTheme.actionBlue : LiquidGlass.textPrimary(isDark: isDark))
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isSelected ? AppleTheme.actionBlue : LiquidGlass.textTertiary(isDark: isDark))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(isSelected ? AppleTheme.actionBlue.opacity(0.15) : (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: AppleTheme.radiusSm)
                    .fill(isSelected ? AppleTheme.actionBlue.opacity(0.12) : (isHovered ? (isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.05)) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .applePressable()
        .padding(.horizontal, 8)
        .onHover { h in
            isHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

struct YouTubeFolderRow: View {
    let folder: URL
    let isSelected: Bool
    let isDark: Bool
    let action: () -> Void
    let onRescan: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? AppleTheme.actionBlue : Color.blue.opacity(0.85))
                
                Text(folder.lastPathComponent)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppleTheme.actionBlue : LiquidGlass.textPrimary(isDark: isDark))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? AppleTheme.actionBlue.opacity(0.12) : (isHovered ? (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .applePressable()
        .padding(.horizontal, 8)
        .onHover { h in
            isHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .contextMenu {
            Button("Rescan Folder", action: onRescan)
            Divider()
            Button("Remove from Library", action: onRemove)
        }
    }
}
