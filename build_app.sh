#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=========================================="
echo " Building Ice-Cream Player (macOS Native) "
echo "=========================================="

APP_NAME="Ice-Cream Player.app"
CONTENTS="$APP_NAME/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

mkdir -p "$MACOS" "$RESOURCES"

# 1. Bundle metadata
cp Info.plist "$CONTENTS/Info.plist"
printf "APPLICE#" > "$CONTENTS/PkgInfo"

# 2. Copy Application Icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"
fi

# 3. Copy LibVLC dynamic libraries
echo "==> Bundling LibVLC dynamic libraries..."
mkdir -p "$MACOS/lib"
cp -f lib/* "$MACOS/lib/" 2>/dev/null || cp -R lib/ "$MACOS/lib/"

# 4. Copy LibVLC plugins (skip if already present)
if [ ! -f "$MACOS/plugins/plugins.dat" ]; then
    echo "==> Bundling LibVLC plugins..."
    mkdir -p "$MACOS/plugins"
    cp -R plugins/ "$MACOS/plugins/"
else
    echo "==> LibVLC plugins already bundled."
fi

# 5. Compile Swift sources
echo "==> Compiling Swift application with Swift 6 / SwiftUI..."
SWIFT_FILES=(
    Sources/Theme/AppTheme.swift
    Sources/Models/AppMode.swift
    Sources/Models/PlaylistItem.swift
    Sources/Models/BookmarkItem.swift
    Sources/Models/AudioEqualizerPreset.swift
    Sources/Models/MediaLibraryItem.swift
    Sources/Engine/VLCPlayerEngine.swift
    Sources/Managers/PlaylistManager.swift
    Sources/Managers/StreamManager.swift
    Sources/Managers/MediaLibraryManager.swift
    Sources/UI/VLCVideoView.swift
    Sources/UI/AudioVisualizerView.swift
    Sources/UI/DropZoneView.swift
    Sources/UI/BottomControlsBarView.swift
    Sources/UI/SidebarView.swift
    Sources/UI/EqualizerView.swift
    Sources/UI/MediaInfoView.swift
    Sources/UI/OpenNetworkView.swift
    Sources/UI/YouTube/VideoCardView.swift
    Sources/UI/YouTube/YouTubeSidebarView.swift
    Sources/UI/YouTube/YouTubeLibraryView.swift
    Sources/UI/YouTube/YouTubePlayerView.swift
    Sources/UI/YouTube/YouTubeMiniPlayerView.swift
    Sources/UI/MainWindowView.swift
    Sources/App/VLCPlayerApp.swift
)

swiftc -parse-as-library \
    -I Clibvlc \
    -I include \
    -L "$MACOS/lib" \
    -lvlc -lvlccore \
    -framework AVKit -framework AVFoundation \
    -Xlinker -rpath -Xlinker @executable_path/lib \
    -Xlinker -rpath -Xlinker @executable_path/plugins \
    "${SWIFT_FILES[@]}" \
    -o "$MACOS/IceCreamPlayer"

# 6. Ad-hoc codesign
echo "==> Applying ad-hoc codesign signature..."
codesign -s - --force "$MACOS/IceCreamPlayer"
codesign -s - --force "$APP_NAME"

# Maintain backwards compatibility symlink
rm -rf "VLC Player.app"
ln -s "Ice-Cream Player.app" "VLC Player.app"

# 7. Install to /Applications
echo "==> Deploying to /Applications..."
cp -R "Ice-Cream Player.app" /Applications/

# 8. Generate installable DMG
if [ -f "./package_dmg.sh" ]; then
    ./package_dmg.sh
fi

echo "=========================================="
echo " Build successful: $DIR/$APP_NAME "
echo "=========================================="
