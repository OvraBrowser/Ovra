#!/usr/bin/env bash
#
# Builds a signed Ovra update and (optionally) publishes it with Sparkle.
#
#   scripts/release.sh 1.0.1                      # build + sign + appcast, nothing uploaded
#   scripts/release.sh 1.0.1 --notes notes.md     # same, with release notes
#   scripts/release.sh 1.0.1 --notes notes.md --publish
#
# --publish creates the GitHub release v<version> with the zip, then commits
# the updated appcast.xml (and the version bump) to main. GitHub Pages serves
# it at https://ovrabrowser.github.io/Ovra/appcast.xml.
#
# The Sparkle signing key is read from your login keychain (generate_keys).
#
# Developer ID (recommended — no Gatekeeper warning on first install):
#   OVRA_TEAM_ID=XXXXXXXXXX NOTARY_PROFILE=ovra-notary scripts/release.sh 1.0.1 --publish
# OVRA_TEAM_ID is the paid team's ID. The app is exported with Developer ID
# signing (a local certificate or Xcode's cloud-managed one) and, with
# NOTARY_PROFILE set, notarized and stapled. Without OVRA_TEAM_ID the build
# keeps the project's development signing.
#
set -euo pipefail

VERSION="${1:-}"
shift || true
NOTES=""
PUBLISH=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes) NOTES="$2"; shift 2 ;;
    --publish) PUBLISH=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Usage: scripts/release.sh <version, e.g. 1.0.1> [--notes file.md] [--publish]"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

REPO="OvraBrowser/Ovra"
TAG="v$VERSION"
# Sparkle compares CFBundleVersion, so it must always grow: use a timestamp.
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
WORK="$ROOT/build/release/$VERSION"
UPDATES="$ROOT/build/updates"
ZIP_NAME="Ovra-$VERSION.zip"

if [[ $PUBLISH -eq 1 ]]; then
  gh auth status >/dev/null 2>&1 || { echo "Log in first: gh auth login"; exit 1; }
  if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
    echo "Release $TAG already exists."; exit 1
  fi
fi

echo "▸ Building Ovra $VERSION ($BUILD_NUMBER)"
rm -rf "$WORK"
mkdir -p "$WORK" "$UPDATES"
TEAM_ARGS=()
if [[ -n "${OVRA_TEAM_ID:-}" ]]; then
  TEAM_ARGS=(DEVELOPMENT_TEAM="$OVRA_TEAM_ID")
fi
xcodebuild -project Ovra.xcodeproj -scheme Ovra -configuration Release \
  -archivePath "$WORK/Ovra.xcarchive" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  ${TEAM_ARGS[@]+"${TEAM_ARGS[@]}"} \
  -allowProvisioningUpdates archive -quiet

APP="$WORK/Ovra.xcarchive/Products/Applications/Ovra.app"
[[ -d "$APP" ]] || { echo "Archive has no Ovra.app"; exit 1; }

if [[ -n "${OVRA_TEAM_ID:-}" ]]; then
  echo "▸ Exporting with Developer ID (team $OVRA_TEAM_ID)"
  # A Developer ID certificate in the keychain (e.g. exported by the Account
  # Holder) is used directly; otherwise Xcode tries a cloud-managed one.
  if security find-identity -v -p codesigning | grep -q "Developer ID Application:.*($OVRA_TEAM_ID)"; then
    SIGNING_STYLE="<key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>"
  else
    SIGNING_STYLE="<key>signingStyle</key><string>automatic</string>"
  fi
  cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  $SIGNING_STYLE
  <key>teamID</key><string>$OVRA_TEAM_ID</string>
</dict>
</plist>
PLIST
  if ! xcodebuild -exportArchive -archivePath "$WORK/Ovra.xcarchive" \
       -exportOptionsPlist "$WORK/ExportOptions.plist" -exportPath "$WORK/export" \
       -allowProvisioningUpdates -quiet; then
    echo "✗ Developer ID export failed. Your Apple ID needs a Developer ID certificate on"
    echo "  team $OVRA_TEAM_ID in your keychain (ask the Account Holder — see scripts/RELEASING.md)."
    exit 1
  fi
  APP="$WORK/export/Ovra.app"
fi

echo "▸ Checking code signature"
codesign --verify --deep --strict "$APP"
codesign -dv "$APP" 2>&1 | grep -E "Authority=|TeamIdentifier=" | head -2

if [[ -n "${OVRA_TEAM_ID:-}" && -n "${NOTARY_PROFILE:-}" ]]; then
  echo "▸ Notarizing (this can take a few minutes)"
  ditto -c -k --keepParent "$APP" "$WORK/notarize.zip"
  xcrun notarytool submit "$WORK/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
else
  echo "▸ Skipping notarization (needs OVRA_TEAM_ID and NOTARY_PROFILE)."
  echo "  First installs will need right-click › Open; Sparkle updates still install normally."
fi

echo "▸ Packaging"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$UPDATES/$ZIP_NAME"
if [[ -n "$NOTES" ]]; then
  cp "$NOTES" "$UPDATES/Ovra-$VERSION.${NOTES##*.}"
else
  printf "# Ovra %s\n\nBug fixes and improvements.\n" "$VERSION" > "$UPDATES/Ovra-$VERSION.md"
fi

echo "▸ Generating signed appcast"
# Start from the published feed so earlier releases stay listed.
cp "$ROOT/appcast.xml" "$UPDATES/appcast.xml"
SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*SourcePackages/artifacts/sparkle/Sparkle/bin" -type d 2>/dev/null | head -1)"
[[ -x "$SPARKLE_BIN/generate_appcast" ]] || { echo "Sparkle tools not found. Build Ovra in Xcode once first."; exit 1; }
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
  --link "https://github.com/$REPO" \
  --embed-release-notes \
  "$UPDATES"

grep -q "sparkle:edSignature" "$UPDATES/appcast.xml" || { echo "Appcast is missing an EdDSA signature."; exit 1; }
echo "  Appcast: $UPDATES/appcast.xml"
echo "  Update:  $UPDATES/$ZIP_NAME ($(du -h "$UPDATES/$ZIP_NAME" | cut -f1))"

if [[ $PUBLISH -eq 0 ]]; then
  echo "✓ Built. Nothing was uploaded. Re-run with --publish to release."
  exit 0
fi

echo "▸ Publishing GitHub release $TAG"
NOTES_FILE="$UPDATES/Ovra-$VERSION.md"
[[ -f "$NOTES_FILE" ]] || NOTES_FILE="$UPDATES/Ovra-$VERSION.${NOTES##*.}"
gh release create "$TAG" "$UPDATES/$ZIP_NAME" -R "$REPO" --title "Ovra $VERSION" --notes-file "$NOTES_FILE"

echo "▸ Updating appcast on main"
cp "$UPDATES/appcast.xml" "$ROOT/appcast.xml"
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" Ovra.xcodeproj/project.pbxproj
git add appcast.xml Ovra.xcodeproj/project.pbxproj
git commit -m "Release Ovra $VERSION"
git push origin HEAD:main

echo "✓ Ovra $VERSION is live. Installed copies will see it within a day (or via Check for Updates)."
