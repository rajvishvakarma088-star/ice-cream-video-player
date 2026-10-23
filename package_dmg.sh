#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=========================================="
echo " Packaging Installable macOS DMG          "
echo "=========================================="

APP_PATH="Ice-Cream Player.app"
DMG_DEST="/Users/rajvishvakarma/Downloads/practice app /Ice-Cream-Player.dmg"
STAGING_DIR="/tmp/IceCreamPlayer_dmg_staging_$$"

# Clean up any leftover staging
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "==> Preparing DMG staging root..."
cp -R "$APP_PATH" "$STAGING_DIR/Ice-Cream Player.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Volume icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$STAGING_DIR/.VolumeIcon.icns"
fi

# Remove any old DMG
rm -f "$DMG_DEST"

echo "==> Creating compressed installable UDZO DMG..."
hdiutil create \
    -volname "Ice-Cream Player" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_DEST"

# Clean up staging
rm -rf "$STAGING_DIR"

echo "==> DMG successfully created at:"
ls -lh "$DMG_DEST"
echo "=========================================="
