import SwiftUI
import AppKit

public struct YouTubeLibraryView: View {
    @ObservedObject var library = MediaLibraryManager.shared
    @ObservedObject var playlist = PlaylistManager.shared
    @ObservedObject var streamManager = StreamManager.shared
    var isDark: Bool
    var onPlayItem: (MediaLibraryItem) -> Void
    var onPlayURL: (URL) -> Void
    
    @State private var streamURLInput: String = ""
    
    public init(
        isDark: Bool,
        onPlayItem: @escaping (MediaLibraryItem) -> Void,
        onPlayURL: @escaping (URL) -> Void
    ) {
        self.isDark = isDark
        self.onPlayItem = onPlayItem
        self.onPlayURL = onPlayURL
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Filter & Search Bar
            topBarView
            
            Divider().opacity(0.3)
            
            // Content
            if library.selectedCategory == .streams {
                streamsHubView
            } else {
                mediaCollectionView
            }
        }
        .background(LiquidGlass.surfaceBackground(isDark: isDark))
    }
    
    // MARK: - Top Bar
    
    private var topBarView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Search Field (Apple pill search input)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                        .font(.system(size: 13))
                    
                    TextField("Search your media library...", text: $library.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                    
                    if !library.searchQuery.isEmpty {
                        Button(action: { library.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isDark ? Color.white.opacity(0.08) : Color.white)
                )
                .overlay(
                    Capsule()
                        .stroke(LiquidGlass.cardBorder(isDark: isDark), lineWidth: 1)
                )
                
                Spacer()
                
                // Sort Menu
                Menu {
                    ForEach(LibrarySortOption.allCases) { opt in
                        Button(action: { library.sortOption = opt }) {
                            HStack {
                                Text(opt.rawValue)
                                if library.sortOption == opt {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11))
                        Text(library.sortOption.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LiquidGlass.cardBackground(isDark: isDark))
                    .cornerRadius(AppleTheme.radiusSm)
                }
                .menuStyle(.borderlessButton)
                
                // Grid / List Toggle
                HStack(spacing: 2) {
                    Button(action: { library.isGridView = true }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 12))
                            .foregroundColor(library.isGridView ? AppleTheme.actionBlue : LiquidGlass.textSecondary(isDark: isDark))
                            .padding(6)
                            .background(library.isGridView ? AppleTheme.actionBlue.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .applePressable()
                    
                    Button(action: { library.isGridView = false }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12))
                            .foregroundColor(!library.isGridView ? AppleTheme.actionBlue : LiquidGlass.textSecondary(isDark: isDark))
                            .padding(6)
                            .background(!library.isGridView ? AppleTheme.actionBlue.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .applePressable()
                }
                .padding(2)
                .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                .cornerRadius(8)
                
                // Scan Mac Action
                Button(action: { library.promptGrantMacAccess() }) {
                    Label("Scan Mac", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .applePressable()
                .controlSize(.small)
                .help("Discover and index all media files across your Mac")
                
                // Import Action
                Button(action: { library.promptImportFiles() }) {
                    Label("Import", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(AppleTheme.actionBlue)
                .applePressable()
                .controlSize(.small)
            }
            
            // Filter Pills Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LibraryFilterOption.allCases) { filter in
                        let isSelected = library.filterOption == filter
                        Button(action: { library.filterOption = filter }) {
                            Text(filter.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : LiquidGlass.textSecondary(isDark: isDark))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? AppleTheme.actionBlue : (isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.05)))
                                )
                        }
                        .buttonStyle(.plain)
                        .applePressable()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Media Collection
    
    private var mediaCollectionView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Continue Watching Section (if any progress)
                let continueWatching = library.items.filter { $0.watchedProgress > 0.05 && $0.watchedProgress < 0.95 }
                if !continueWatching.isEmpty && library.selectedCategory == .home && library.searchQuery.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.red)
                            Text("Continue Watching")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(continueWatching) { item in
                                    VideoCardView(
                                        item: item,
                                        isDark: isDark,
                                        isListView: false,
                                        onPlay: { onPlayItem(item) },
                                        onToggleFavorite: { library.toggleFavorite(item: item) }
                                    )
                                    .frame(width: 240)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
                
                // Section Title
                HStack {
                    Text(library.selectedCategory.rawValue)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                    
                    Text("(\(library.filteredItems.count) items)")
                        .font(.system(size: 12))
                        .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                    
                    Spacer()
                }
                
                // Grid or List Content
                if library.filteredItems.isEmpty {
                    emptyStateView
                } else if library.isGridView {
                    let columns = [GridItem(.adaptive(minimum: library.gridCardWidth, maximum: 380), spacing: 16)]
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(library.filteredItems) { item in
                            VideoCardView(
                                item: item,
                                isDark: isDark,
                                isListView: false,
                                onPlay: { onPlayItem(item) },
                                onToggleFavorite: { library.toggleFavorite(item: item) }
                            )
                        }
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(library.filteredItems) { item in
                            VideoCardView(
                                item: item,
                                isDark: isDark,
                                isListView: true,
                                onPlay: { onPlayItem(item) },
                                onToggleFavorite: { library.toggleFavorite(item: item) }
                            )
                        }
                    }
                }
            }
            .padding(18)
        }
    }
    
    // MARK: - Streams Hub
    
    private var streamsHubView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                // Direct URL Entry Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "network.badge.shield.half.filled")
                            .foregroundColor(AppleTheme.actionBlue)
                            .font(.system(size: 18))
                        
                        Text("Open Network Media Stream")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                        
                        Spacer()
                    }
                    
                    Text("Stream directly from HTTP, HTTPS, HLS (.m3u8), RTSP, RTMP, or network audio broadcasts:")
                        .font(.system(size: 12))
                        .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                    
                    HStack(spacing: 8) {
                        TextField("Enter stream URL (e.g. https://example.com/live.m3u8)", text: $streamURLInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                        
                        Button(action: {
                            if let url = streamManager.validateAndNormalizeURL(streamURLInput) {
                                streamManager.playStream(urlString: streamURLInput)
                                onPlayURL(url)
                            }
                        }) {
                            Label("Play Stream", systemImage: "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppleTheme.actionBlue)
                        .disabled(streamURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    if let err = streamManager.lastError {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                            Text(err).font(.system(size: 11)).foregroundColor(.red)
                        }
                    }
                }
                .padding(18)
                .glassCard(isDark: isDark, cornerRadius: 14)
                
                // Verified Sample Streams Grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("VERIFIED PUBLIC STREAMS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                    
                    let columns = [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 14)]
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(streamManager.presets) { preset in
                            Button(action: {
                                if let url = preset.url {
                                    streamManager.playStream(urlString: preset.urlString, title: preset.name)
                                    onPlayURL(url)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(LiquidGlass.brandGradient)
                                            .frame(width: 48, height: 48)
                                        
                                        Image(systemName: preset.badge == "LIVE" ? "dot.radiowaves.left.and.right" : "play.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(preset.name)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            Text(preset.badge)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(AppleTheme.actionBlue))
                                        }
                                        
                                        Text(preset.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                                            .lineLimit(2)
                                    }
                                }
                                .padding(12)
                                .glassCard(isDark: isDark, cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                            .applePressable()
                        }
                    }
                }
                
                // Recent Streams History
                if !streamManager.recentStreams.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("RECENT STREAMS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                            
                            Spacer()
                            
                            Button("Clear History") {
                                streamManager.clearHistory()
                            }
                            .buttonStyle(.plain)
                            .applePressable()
                            .font(.system(size: 11))
                            .foregroundColor(AppleTheme.actionBlue)
                        }
                        
                        VStack(spacing: 6) {
                            ForEach(streamManager.recentStreams, id: \.self) { streamStr in
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 12))
                                        .foregroundColor(LiquidGlass.textTertiary(isDark: isDark))
                                    
                                    Text(streamStr)
                                        .font(.system(size: 12))
                                        .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Button("Play") {
                                        if let url = URL(string: streamStr) {
                                            streamManager.playStream(urlString: streamStr)
                                            onPlayURL(url)
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.mini)
                                }
                                .padding(10)
                                .background(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding(18)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(AppleTheme.actionBlue.opacity(0.8))
            
            Text("No Media Found")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(LiquidGlass.textPrimary(isDark: isDark))
            
            Text("Add folders with videos and music, or import media files to populate your media library.")
                .font(.system(size: 13))
                .foregroundColor(LiquidGlass.textSecondary(isDark: isDark))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            
            HStack(spacing: 12) {
                Button(action: { library.promptGrantMacAccess() }) {
                    Label("Scan Entire Mac for Media", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(AppleTheme.actionBlue)
                .applePressable()
                
                Button(action: { library.promptAddFolder() }) {
                    Label("Add Folder...", systemImage: "folder.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .applePressable()
                
                Button(action: { library.promptImportFiles() }) {
                    Label("Import Files", systemImage: "plus.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .applePressable()
            }
            
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
}
