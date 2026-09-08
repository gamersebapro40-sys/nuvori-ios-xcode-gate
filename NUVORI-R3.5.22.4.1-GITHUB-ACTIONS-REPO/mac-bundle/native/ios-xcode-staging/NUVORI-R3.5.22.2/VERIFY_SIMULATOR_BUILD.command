#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -d "NUVORI.xcodeproj" ]; then
  echo "ERROR: NUVORI.xcodeproj not generated. Run GENERATE_XCODE_PROJECT.command first."
  exit 2
fi

echo "Xcode:"
xcodebuild -version
echo
echo "Schemes:"
xcodebuild -project NUVORI.xcodeproj -list
echo
echo "Building iOS Simulator with signing disabled..."

xcodebuild   -project NUVORI.xcodeproj   -scheme NUVORI   -configuration Debug   -sdk iphonesimulator   -destination 'generic/platform=iOS Simulator'   CODE_SIGNING_ALLOWED=NO   build

echo
echo "PASS: simulator build completed."
echo "NOTE: this does NOT certify device signing, archive, App Store privacy, or production API connectivity."
