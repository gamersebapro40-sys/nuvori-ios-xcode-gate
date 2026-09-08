#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "NUVORI R3.5.22.2 - macOS Xcode project generation"
echo

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: Xcode command line tools are not available."
  exit 2
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "ERROR: XcodeGen is not installed."
  echo "Install XcodeGen on the Mac, then re-run this script."
  exit 3
fi

xcodegen generate --spec project.yml

echo
echo "Generated:"
ls -ld NUVORI.xcodeproj
echo
echo "Next:"
echo "  ./VERIFY_SIMULATOR_BUILD.command"
