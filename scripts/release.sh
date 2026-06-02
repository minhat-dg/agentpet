#!/usr/bin/env bash
# Builds, Developer ID-signs, notarizes, and staples a distributable DMG.
#
# One-time setup (your Apple credentials, run it yourself):
#   xcrun notarytool store-credentials agentpet \
#     --apple-id "<your-apple-id-email>" \
#     --team-id 9D7HY2JCGN \
#     --password "<app-specific-password>"
# Create the app-specific password at https://appleid.apple.com → Sign-In & Security.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/build/AgentPet.app"
IDENTITY="Developer ID Application: Dat Nguyen (9D7HY2JCGN)"
PROFILE="${NOTARY_PROFILE:-agentpet}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' scripts/AppInfo.plist)"

echo "==> Building AgentPet.app"
./scripts/build-app.sh release

echo "==> Signing with Developer ID (hardened runtime)"
# Sign any nested bundles first, then the main executable, then the app.
while IFS= read -r -d '' nested; do
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$nested"
done < <(find "$APP/Contents/Resources" -name "*.bundle" -print0 2>/dev/null)

# Sparkle.framework ships nested XPC services and helper apps that each must be
# signed inside-out (deepest first) with the hardened runtime before the app.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE" ]; then
    SV="$SPARKLE/Versions/B"
    for nested in \
        "$SV/XPCServices/Downloader.xpc" \
        "$SV/XPCServices/Installer.xpc" \
        "$SV/Autoupdate" \
        "$SV/Updater.app"; do
        codesign --force --options runtime --timestamp --sign "$IDENTITY" "$nested"
    done
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$SPARKLE"
fi

codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP/Contents/MacOS/agentpet"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Building DMG"
DMG="$ROOT/build/AgentPet-$VERSION.dmg"
STAGE="$ROOT/build/dmg"
rm -f "$DMG"; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/AgentPet.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "AgentPet" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [ -n "${SKIP_NOTARIZE:-}" ]; then
    echo "==> Skipping notarization (SKIP_NOTARIZE set); signed-only build"
else
    echo "==> Notarizing (this can take a few minutes)"
    xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
    xcrun stapler staple "$DMG"
    xcrun stapler staple "$APP"
fi

echo "==> Signing update for Sparkle appcast"
SIGN_UPDATE="$(find "$ROOT/.build/artifacts" -name sign_update -path '*Sparkle*' 2>/dev/null | head -1)"
ED_ATTRS="$("$SIGN_UPDATE" "$DMG")"   # emits: sparkle:edSignature="..." length="..."

echo "==> Done"
echo "DMG:    $DMG"
echo "SHA256: $(shasum -a 256 "$DMG" | awk '{print $1}')"
echo ""
echo "Appcast <item> (paste into docs/appcast.xml, then commit + push for Pages):"
cat <<EOF
        <item>
            <title>$VERSION</title>
            <sparkle:version>$VERSION</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
            <enclosure url="https://github.com/ntd4996/agentpet/releases/download/v$VERSION/AgentPet-$VERSION.dmg"
                       $ED_ATTRS type="application/octet-stream" />
        </item>
EOF
