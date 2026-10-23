# Ice-Cream Player (macOS)
### Apple Liquid Glass Media Player with YouTube Pro & Classic VLC Modes

Ice-Cream Player is a macOS media player combining the discoverability of a **YouTube-style media library**, the distraction-free playback experience of a modern video player, Apple's refined **Liquid Glass design system**, and the versatile media decoding capabilities of **LibVLC 3.0.24**.

---

## 1. Dual-Mode Architecture

Users can toggle seamlessly between two distinct modes using the Apple-style segmented glass capsule in the top toolbar:

| Mode | Visual Paradigm | Core Target |
| :--- | :--- | :--- |
| **🍦 Classic VLC Mode** *(Default)* | Classic desktop player layout with VLC cone emblem, visualizer, bottom transport bar, and sidebar playlist. | Traditional desktop media player workflows, quick audio playback, file inspect, and queue management. |
| **🎬 YouTube Pro Mode** | Full-bleed media discovery hub with responsive thumbnail grid, continue-watching carousel, and theater-mode video player. | Modern video streaming, visual browsing of local & network media, auto-hiding Liquid Glass controls HUD. |

---

## 2. Key Features

### 🎬 YouTube Pro Media Library
- **Responsive Video Grid**: Adaptive thumbnail grid (`LazyVGrid`) with adjustable card sizes (compact to large) and instantaneous Grid/List view toggling.
- **Asynchronous Thumbnail Engine**: Generates 16:9 high-resolution preview thumbnails asynchronously via `AVAssetImageGenerator` on background utility threads without dropping UI frames.
- **Dual-Tier Cache**: Memory cache (`NSCache`) for fluid 60fps scrolling + disk cache (`~/Library/Caches/IceCreamPlayer/Thumbnails/`) for persistence across application launches.
- **Rich Card Metadata**: Duration badge, resolution pill (`4K UHD`, `1080p`, `720p`, `SD`), file format, and human-readable file size.
- **Continue Watching Progress**: Persistent red playback progress bar rendered across video thumbnails for partially-watched media.
- **Curated Navigation Sidebar**: Home, Videos, Music, Playlists, History, Favorites, Streams, and watched Folders.
- **Instant Search & Filters**: Live client-side search by title or extension, and filter chips for `All`, `4K Ultra HD`, `1080p Full HD`, `Short (< 5 min)`, `Long (> 20 min)`, and `Unwatched`.
- **Sorting Options**: Recently Added, Title (A-Z), Duration, and File Size.
- **Folder Watching & Import**: Security-scoped folder additions (Movies, Downloads, custom drives) with background crawling and drag-and-drop support.

### 🎬 YouTube-Style Theater Player
- **Distraction-Free Playback Canvas**: Edge-to-edge hardware-accelerated video rendering surface via `VLCVideoView`.
- **Auto-Hiding Liquid Glass HUD**: Floating frosted glass controls overlay that animates into view on cursor movement and smoothly auto-fades after 2.8s of idle mouse activity.
- **Interactive Red Scrub Bar**: YouTube-style scrub bar with real-time millisecond seeking and hover preview.
- **Transport Controls**: Play/Pause, -10s rewind, +10s forward, Previous, Next.
- **Volume & Amplification**: Hardware over-amplification up to **200%** with instantaneous mute toggle.
- **Settings Gear Menu**: Playback speed selection (0.25x to 2.0x), aspect ratio overrides (`16:9`, `4:3`, `1:1`, `16:10`, `2.35:1`), audio track selection, and subtitle tracks.
- **Picture-in-Picture & Snapshot**: One-click PiP floating window pinning and PNG frame captures.

### 🌐 Fixed & Supercharged Streaming
- **Root Cause of Previous Failure**: Previous implementation queued stream URLs into the playlist without auto-triggering immediate playback, lacked LibVLC network caching flags, and failed to provide buffering feedback to the user.
- **Network Resilience Options**: Every remote stream is automatically configured with:
  - `:network-caching=2500` (2.5s jitter buffer to eliminate stutter)
  - `:http-reconnect=true` (automatic reconnection on transient socket drops)
  - `:clock-jitter=0` & `:clock-synchro=0` (drift stabilization)
- **Immediate Playback**: Stream URLs start playing instantly without being blocked in a paused playlist queue.
- **Buffering HUD**: Sleek Liquid Glass spinner overlay with real-time status feedback during stream initialization and network buffering.
- **Verified Public Stream Presets**:
  1. *Apple HLS Test Stream* (`bipbop_4x3_variant.m3u8` adaptive bitrate multi-stream)
  2. *Big Buck Bunny* (1080p HTTP MP4)
  3. *Tears of Steel* (4K UHD Sci-Fi Short)
  4. *Sintel* (HD Animated Short)
  5. *SomaFM Groove Salad* (Live continuous network audio stream)
- **Recent Stream History**: Remembers recently played network streams with 1-click replay.

### 🎨 Apple Liquid Glass Design System
- **Translucent Materials**: Subtle glass blurs (`.ultraThinMaterial`), refined 12-14pt corner radii, and 1px borders (`white.opacity(0.12)` in dark mode, `black.opacity(0.08)` in light mode).
- **Themes**: Complete Dark, Light, and System appearances with smooth theme transitions and persistent storage in `UserDefaults`.
- **SF Symbols**: Native macOS SF Symbols throughout all transport controls and sidebars.

---

## 3. Architecture & Codebase Map

```
VLCPlayerApp/
├── Sources/
│   ├── App/
│   │   └── VLCPlayerApp.swift              # App entry point, menus & global shortcuts
│   ├── Theme/
│   │   └── AppTheme.swift                  # Liquid Glass design tokens, colors & modifiers
│   ├── Models/
│   │   ├── AppMode.swift                   # Classic VLC vs YouTube Pro mode enum
│   │   ├── MediaLibraryItem.swift          # Video card model with duration, resolution & progress
│   │   ├── PlaylistItem.swift              # Playlist queue item with JSON serialization
│   │   ├── BookmarkItem.swift              # Media bookmark with millisecond timestamp
│   │   └── AudioEqualizerPreset.swift      # 10-band equalizer presets
│   ├── Engine/
│   │   └── VLCPlayerEngine.swift           # Native Swift wrapper around LibVLC 3.0.24 C APIs
│   ├── Managers/
│   │   ├── PlaylistManager.swift           # Queue state, history, resume positions & instant play
│   │   ├── StreamManager.swift             # URL normalization, verified presets & stream history
│   │   └── MediaLibraryManager.swift       # Background folder scanner & dual-tier thumbnail cache
│   └── UI/
│       ├── MainWindowView.swift            # Top-level window, mode switcher & sheet coordinators
│       ├── VLCVideoView.swift              # Hardware video presentation surface
│       ├── AudioVisualizerView.swift       # 24-band animated audio visualizer
│       ├── DropZoneView.swift              # Classic drag-and-drop landing view
│       ├── BottomControlsBarView.swift     # Classic VLC bottom controls bar
│       ├── SidebarView.swift               # Classic VLC playlist & bookmark sidebar
│       ├── EqualizerView.swift             # 10-band graphic equalizer modal
│       ├── MediaInfoView.swift             # Metadata & stream inspector modal
│       ├── OpenNetworkView.swift           # Network stream dialog with verified presets
│       └── YouTube/
│           ├── VideoCardView.swift         # Responsive 16:9 thumbnail card with hover play
│           ├── YouTubeSidebarView.swift    # Navigation categories & watched folders sidebar
│           ├── YouTubeLibraryView.swift    # Media grid, continue watching, filters & streaming hub
│           └── YouTubePlayerView.swift     # Theater video canvas with auto-hiding Liquid Glass HUD
├── Tests/
│   └── PlayerTestSuite.swift               # 43 automated unit & integration tests
├── Resources/
│   └── AppIcon.icns                        # Apple-style Liquid Glass squircle icon
├── lib/                                    # Bundled libvlc.dylib & libvlccore.dylib
├── plugins/                                # 344 bundled LibVLC dynamic plugins
├── build_app.sh                            # Automated build and codesign script
└── Info.plist                              # macOS app bundle definition
```

---

## 4. Test Suite Verification

Run the automated test suite verifying all 12 modules:

```bash
cd VLCPlayerApp
./build_app.sh
swiftc -parse-as-library \
    -I Clibvlc -I include -L "lib" -lvlc -lvlccore \
    -Xlinker -rpath -Xlinker "@loader_path/lib" \
    -Xlinker -rpath -Xlinker "$PWD/lib" \
    Sources/Models/*.swift Sources/Theme/*.swift \
    Sources/Engine/*.swift Sources/Managers/*.swift \
    Tests/PlayerTestSuite.swift \
    -o Tests/run_tests && ./Tests/run_tests
```

**Test Results:**
```
==========================================
 Test Summary: 43 Passed, 0 Failed
==========================================
```

---

## 5. Building & Creating the DMG

1. **Build the macOS App Bundle**:
   ```bash
   cd VLCPlayerApp
   ./build_app.sh
   ```
   *Generates `Ice-Cream Player.app` with all bundled dylibs, plugins, and ad-hoc signatures.*

2. **Package the Disk Image (.dmg)**:
   ```bash
   cd ..
   ./create_dmg.sh
   ```
   *Generates `Ice-Cream-Player.dmg` (92 MB) ready for drag-and-drop installation into `/Applications`.*
