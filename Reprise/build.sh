#!/bin/bash
set -euo pipefail
REPRISE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPRISE_DEST="${1:-$REPRISE_ROOT/build/reprise}"
REPRISE_OUT="$(mktemp -d "${TMPDIR:-/tmp}/reprise-build.XXXXXX")"
trap 'rm -rf "$REPRISE_OUT"' EXIT
REPRISE_CACHE="${TMPDIR:-/tmp}/reprise-swift-module-cache"
mkdir -p "$REPRISE_OUT/Reprise.app/Contents/MacOS" "$REPRISE_OUT/Reprise.app/Contents/Resources" "$REPRISE_CACHE"
swiftc -parse-as-library -O -module-cache-path "$REPRISE_CACHE" \
  "$REPRISE_ROOT/Reprise/App.swift" "$REPRISE_ROOT/Reprise/Thread.swift" \
  "$REPRISE_ROOT/Reprise/Capture.swift" "$REPRISE_ROOT/Reprise/Store.swift" "$REPRISE_ROOT/Reprise/Views.swift" \
  "$REPRISE_ROOT/Reprise/NotchSupport.swift" "$REPRISE_ROOT/Reprise/BrandGeometry.swift" "$REPRISE_ROOT/Reprise/BrandMark.swift" \
  "$REPRISE_ROOT/Reprise/Surface.swift" "$REPRISE_ROOT/Reprise/CompactNotch.swift" "$REPRISE_ROOT/Reprise/LibraryView.swift" \
  "$REPRISE_ROOT/Sources/Notch/SideNotchShape.swift" \
  "$REPRISE_ROOT/Sources/Notch/NotchMotion.swift" \
  -o "$REPRISE_OUT/Reprise.app/Contents/MacOS/Reprise"
swiftc -parse-as-library -O -module-cache-path "$REPRISE_CACHE" \
  "$REPRISE_ROOT/Reprise/NativeHost.swift" "$REPRISE_ROOT/Reprise/Capture.swift" \
  "$REPRISE_ROOT/Reprise/Thread.swift" "$REPRISE_ROOT/Reprise/BridgeIdentity.swift" \
  -o "$REPRISE_OUT/Reprise.app/Contents/MacOS/RepriseBridge"
codesign --force --sign - "$REPRISE_OUT/Reprise.app/Contents/MacOS/RepriseBridge"
cp "$REPRISE_ROOT/Reprise/Brand/Reprise.icns" "$REPRISE_OUT/Reprise.app/Contents/Resources/Reprise.icns"
cp "$REPRISE_ROOT/LICENSE" "$REPRISE_OUT/Reprise.app/Contents/Resources/LICENSE"
cat > "$REPRISE_OUT/Reprise.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Reprise</string>
<key>CFBundleIdentifier</key><string>tools.pulsar.reprise.study</string>
<key>CFBundleName</key><string>Reprise</string>
<key>CFBundleIconFile</key><string>Reprise</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.0</string>
<key>CFBundleVersion</key><string>7</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Reprise 2026. Based on Codenotch © 2026 Vinz, MIT.</string>
</dict></plist>
PLIST
# File Provider can attach Finder metadata to a bundle in Documents. Remove
# only that metadata before signing our own build; no quarantine is changed.
xattr -rd com.apple.FinderInfo "$REPRISE_OUT/Reprise.app" 2>/dev/null || true
codesign --force --sign - "$REPRISE_OUT/Reprise.app"
codesign --verify --deep --strict "$REPRISE_OUT/Reprise.app"
mkdir -p "$REPRISE_DEST"
ditto --norsrc --noextattr "$REPRISE_OUT/Reprise.app" "$REPRISE_DEST/Reprise.app"
ditto --norsrc --noextattr -c -k --keepParent "$REPRISE_OUT/Reprise.app" "$REPRISE_DEST/Reprise-macOS.zip"
printf 'Built: %s\n' "$REPRISE_DEST/Reprise.app"
