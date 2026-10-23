import SwiftUI

public enum SidebarTab: String, CaseIterable, Identifiable {
    case queue = "Queue"
    case history = "History"
    case bookmarks = "Bookmarks"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .queue: return "list.bullet"
        case .history: return "clock"
        case .bookmarks: return "bookmark"
        }
    }
}

public struct SidebarView: View {
    @ObservedObject var playlist = PlaylistManager.shared
    @ObservedObject var player = VLCPlayerEngine.shared
    
    @State private var selectedTab: SidebarTab = .queue
    @State private var searchText: String = ""
    
    var onOpenFile: () -> Void
    var onOpenStream: () -> Void
    
    public init(
        onOpenFile: @escaping () -> Void,
        onOpenStream: @escaping () -> Void
    ) {
        self.onOpenFile = onOpenFile
        self.onOpenStream = onOpenStream
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Tab Selector
            HStack(spacing: 0) {
                ForEach(SidebarTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 11))
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(selectedTab == tab ? AppleTheme.actionBlue : .white.opacity(0.6))
                            .padding(.vertical, 8)
                            
                            Rectangle()
                                .fill(selectedTab == tab ? AppleTheme.actionBlue : Color.clear)
                                .frame(height: 2)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .onHover { h in
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
            .background(AppleTheme.tile3)
            
            // MARK: - Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.system(size: 12))
                
                TextField("Filter items...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .padding(8)
            
            // MARK: - Content List
            switch selectedTab {
            case .queue:
                queueContent
            case .history:
                historyContent
            case .bookmarks:
                bookmarksContent
            }
            
            Divider()
            
            // MARK: - Bottom Actions
            HStack(spacing: 8) {
                Button(action: onOpenFile) {
                    Label("Add File...", systemImage: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button(action: onOpenStream) {
                    Label("Stream...", systemImage: "network")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppleTheme.tile3)
        }
        .frame(width: 250)
        .background(AppleTheme.tile2)
    }
    
    // MARK: - Queue Tab Content
    
    private var filteredQueueItems: [PlaylistItem] {
        if searchText.isEmpty {
            return Array(playlist.items.prefix(300))
        } else {
            let matches = playlist.items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            return Array(matches.prefix(300))
        }
    }
    
    private var queueContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(playlist.items.count) Items")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                if !playlist.items.isEmpty {
                    Button("Clear") {
                        playlist.clear()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            if filteredQueueItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.3))
                    Text(searchText.isEmpty ? "Queue is empty" : "No matches")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
            } else {
                List {
                    ForEach(Array(filteredQueueItems.enumerated()), id: \.element.id) { index, item in
                        let isCurrent = playlist.currentItem?.id == item.id
                        
                        HStack(spacing: 8) {
                            if isCurrent {
                                Image(systemName: player.state == .playing ? "speaker.wave.2.fill" : "pause.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppleTheme.actionBlue)
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(width: 16, alignment: .trailing)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                                    .foregroundColor(isCurrent ? AppleTheme.actionBlue : .white)
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    Text(item.formattedDuration)
                                    if let size = item.fileSizeBytes {
                                        Text("•")
                                        Text(item.formattedFileSize)
                                    }
                                }
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Button(action: { playlist.remove(item: item) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playlist.play(item: item)
                        }
                    }
                    .onMove { source, dest in
                        playlist.move(from: source, to: dest)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - History Tab Content
    
    private var filteredHistoryItems: [PlaylistItem] {
        if searchText.isEmpty {
            return playlist.historyItems
        } else {
            return playlist.historyItems.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var historyContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recently Played")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                if !playlist.historyItems.isEmpty {
                    Button("Clear") {
                        playlist.clearHistory()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            if filteredHistoryItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No playback history")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredHistoryItems) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.isNetworkStream ? "network" : "film")
                                .font(.system(size: 12))
                                .foregroundColor(AppleTheme.actionBlue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(item.formattedDuration)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playlist.play(item: item)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Bookmarks Tab Content
    
    private var filteredBookmarks: [BookmarkItem] {
        if searchText.isEmpty {
            return playlist.bookmarks
        } else {
            return playlist.bookmarks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var bookmarksContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Saved Bookmarks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            if filteredBookmarks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No saved bookmarks")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredBookmarks) { bookmark in
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AppleTheme.actionBlue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bookmark.title)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(bookmark.formattedTimestamp)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(AppleTheme.actionBlue.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Button(action: { playlist.removeBookmark(id: bookmark.id) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playlist.jumpToBookmark(bookmark)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
