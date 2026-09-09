#!/bin/bash
set -euo pipefail
REPRISE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPRISE_OUT="${1:-$REPRISE_ROOT/build/reprise}"
REPRISE_CACHE="${TMPDIR:-/tmp}/reprise-swift-module-cache"
mkdir -p "$REPRISE_OUT/Reprise.app/Contents/MacOS" "$REPRISE_OUT/Reprise.app/Contents/Resources" "$REPRISE_CACHE"
swiftc -parse-as-library -O -module-cache-path "$REPRISE_CACHE" \
  "$REPRISE_ROOT/Reprise/App.swift" "$REPRISE_ROOT/Reprise/Thread.swift" \
  "$REPRISE_ROOT/Reprise/Store.swift" "$REPRISE_ROOT/Reprise/Views.swift" \
  "$REPRISE_ROOT/Reprise/NotchSupport.swift" \
  "$REPRISE_ROOT/Sources/Notch/SideNotchShape.swift" \
  "$REPRISE_ROOT/Sources/Notch/NotchMotion.swift" \
  -o "$REPRISE_OUT/Reprise.app/Contents/MacOS/Reprise"
cp "$REPRISE_ROOT/LICENSE" "$REPRISE_OUT/Reprise.app/Contents/Resources/LICENSE"
cat > "$REPRISE_OUT/Reprise.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Reprise</string>
<key>CFBundleIdentifier</key><string>tools.pulsar.reprise.study</string>
<key>CFBundleName</key><string>Reprise</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Reprise 2026. Based on Codenotch © 2026 Vinz, MIT.</string>
</dict></plist>
PLIST
# File Provider can attach Finder metadata to a bundle in Documents. Remove
# only that metadata before signing our own build; no quarantine is changed.
xattr -rd com.apple.FinderInfo "$REPRISE_OUT/Reprise.app" 2>/dev/null || true
codesign --force --sign - "$REPRISE_OUT/Reprise.app"
printf 'Built: %s\n' "$REPRISE_OUT/Reprise.app"
