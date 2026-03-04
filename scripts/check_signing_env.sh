#!/bin/zsh
set -euo pipefail

echo "== Xcode Path =="
xcode-select -p

echo "\n== Xcode Version =="
xcodebuild -version

echo "\n== Apple ID Accounts (defaults) =="
defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>/dev/null || echo "(none)"

echo "\n== Code Signing Identities =="
security find-identity -v -p codesigning || true

echo "\n== Provisioning Profiles =="
ls -1 ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision 2>/dev/null || echo "(none)"
