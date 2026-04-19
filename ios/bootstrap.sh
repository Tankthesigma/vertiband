#!/usr/bin/env bash
# One-shot bootstrap for the Mac.
# Usage:  ./bootstrap.sh
set -euo pipefail

cd "$(dirname "$0")"

# 1. Homebrew (optional; most devs already have it)
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install from https://brew.sh/ then re-run this script."
  exit 1
fi

# 2. XcodeGen — generates the .xcodeproj from project.yml
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing xcodegen…"
  brew install xcodegen
fi

# 3. Generate the Xcode project
xcodegen generate

# 4. Open in Xcode
open VertiBand.xcodeproj
echo
echo "Done. In Xcode: pick your Apple ID under Signing & Capabilities,"
echo "plug in your iPhone, select it at the top, and press ⌘R."
