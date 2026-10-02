#!/usr/bin/env bash
# Build Fleet.app into dist/ and (with --install) copy to /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

# Regression suite gates every build: nothing ships red. (--skip-tests to bypass.)
if [[ " $* " != *" --skip-tests "* ]]; then
    echo "▶ Running tests…"
    log="$(mktemp)"
    if swift test >"$log" 2>&1; then
        grep -E 'Executed [0-9]+ tests' "$log" | tail -1
        echo "✓ Tests passed"
    else
        grep -E 'error:|failed \(' "$log" | sed "s|$PWD/||" | head -40
        echo "✗ Tests failed — not building. Fix them or pass --skip-tests."
        rm -f "$log"; exit 1
    fi
    rm -f "$log"
fi

swift build -c release

APP=dist/Fleet.app
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/Fleet "$APP/Contents/MacOS/Fleet"
# Icon needs BOTH forms: Assets.car for macOS 26+ (Tahoe reads
# CFBundleIconName from the asset catalog), .icns for older macOS.
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/Assets.car "$APP/Contents/Resources/Assets.car"

# Embed Sparkle.framework so the OS can load it at @executable_path/../Frameworks.
SPARKLE_FW=$(find .build/artifacts -name "Sparkle.framework" -type d 2>/dev/null | head -1)
if [ -n "$SPARKLE_FW" ]; then
    cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"
    codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
else
    echo "Warning: Sparkle.framework not found in .build/artifacts — update checking won't work." >&2
fi

# Unique build number per build — correct release hygiene, and it busts
# macOS's icon cache (which keys on bundle identity+version, so a changed
# icon never shows if the version stays constant).
BUILD_NUMBER="$(date +%Y%m%d.%H%M%S)"

# Sparkle public key — set SPARKLE_PUBLIC_KEY in the environment before building
# (or update the default below after running scripts/generate-sparkle-keys.sh).
# An empty/placeholder value disables update checking safely; it's fine for local dev.
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Fleet</string>
    <key>CFBundleIdentifier</key><string>com.davidkr.fleet</string>
    <key>CFBundleName</key><string>Fleet</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>SUFeedURL</key><string>https://davidkras95.github.io/fleet/appcast.xml</string>
    <key>SUPublicEDKey</key><string>${SPARKLE_PUBLIC_KEY}</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    rm -rf /Applications/Fleet.app
    cp -R "$APP" /Applications/Fleet.app
    echo "Installed /Applications/Fleet.app"
fi
