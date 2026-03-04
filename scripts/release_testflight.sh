#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="$PROJECT_DIR/build/청약리포터.xcarchive"
EXPORT_DIR="$PROJECT_DIR/build/export"
EXPORT_OPTIONS="$PROJECT_DIR/exportOptions-appstore.plist"

cd "$PROJECT_DIR"

echo "[1/4] Preflight signing check..."
IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
if ! echo "$IDENTITIES" | rg -q "[1-9][0-9]* valid identities found"; then
  echo "No code signing identities found."
  echo "Open Xcode > Settings > Accounts and sign in with your Apple Developer account first."
  exit 1
fi

# 1) Signed archive (requires Apple account login and valid signing assets)
echo "[2/4] Creating signed archive..."
xcodebuild \
  -project Runner.xcodeproj \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  archive

# 2) Export IPA for App Store Connect/TestFlight
echo "[3/4] Exporting IPA..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

# 3) Upload IPA (choose one; app-specific password example)
# xcrun altool --upload-app --type ios --file "$EXPORT_DIR/Runner.ipa" --username "<APPLE_ID_EMAIL>" --password "<APP_SPECIFIC_PASSWORD>"

echo "[4/4] Done."
echo "Release artifacts: $EXPORT_DIR"
