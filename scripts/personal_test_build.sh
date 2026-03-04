#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_DIR"

echo "[1/3] Apple ID login check..."
APPLE_IDS="$(defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>/dev/null || true)"
if ! echo "$APPLE_IDS" | rg -q "IDE\\.Identifiers\\.Prod"; then
  echo "Xcode account information key not found."
  echo "Proceeding to build test to verify signing readiness."
elif echo "$APPLE_IDS" | rg -q 'IDE\.Identifiers\.Prod".*\(\s*\)' ; then
  echo "No Apple ID account is currently visible to Xcode CLI."
  echo "Proceeding to build test to confirm."
else
  echo "Apple ID account key detected."
fi

echo "[2/3] Build for personal device signing..."
if ! xcodebuild \
  -project Runner.xcodeproj \
  -scheme Runner \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  build; then
  echo "Build failed while preparing personal signing."
  echo "Check Signing & Capabilities in Xcode and confirm Team=Y86CBU3XP3 (Personal Team)."
  exit 1
fi

echo "[3/3] Ready."
echo "Now connect iPhone and run with Cmd+R in Xcode."
