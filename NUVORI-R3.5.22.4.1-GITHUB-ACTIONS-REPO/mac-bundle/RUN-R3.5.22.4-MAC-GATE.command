#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPORT="$ROOT/R3.5.22.4-MAC-RESULT.json"
STAGE="$ROOT/native/ios-xcode-staging/NUVORI-R3.5.22.2"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: this gate must run on macOS."
  exit 2
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild is unavailable."
  exit 3
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "ERROR: XcodeGen is unavailable."
  echo "Install XcodeGen on the Mac, then rerun."
  exit 4
fi

cd "$STAGE"
rm -rf NUVORI.xcodeproj
xcodegen generate --spec project.yml

XCODE_VERSION="$(xcodebuild -version | tr '\n' ' ')"
DERIVED="$ROOT/.derived-r35224"
rm -rf "$DERIVED"

set +e
BUILD_OUT="$(xcodebuild \
  -project NUVORI.xcodeproj \
  -scheme NUVORI \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1)"
BUILD_RC=$?
set -e

SIM_PASS=false
if [ "$BUILD_RC" -eq 0 ]; then SIM_PASS=true; fi

SETTINGS="$(xcodebuild -project NUVORI.xcodeproj -scheme NUVORI -showBuildSettings 2>/dev/null || true)"
BUNDLE="$(printf "%s\n" "$SETTINGS" | awk -F' = ' '/ PRODUCT_BUNDLE_IDENTIFIER = /{print $2; exit}')"
TEAM="$(printf "%s\n" "$SETTINGS" | awk -F' = ' '/ DEVELOPMENT_TEAM = /{print $2; exit}')"
APIURL="$(printf "%s\n" "$SETTINGS" | awk -F' = ' '/ NUVORI_API_BASE_URL = /{print $2; exit}')"

ICON_COUNT="$(find Resources/Assets.xcassets/AppIcon.appiconset -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' \) 2>/dev/null | wc -l | tr -d ' ')"

PRIVACY_EMPTY=false
if grep -q '<key>NSPrivacyCollectedDataTypes</key>' Resources/PrivacyInfo.xcprivacy && \
   grep -A1 '<key>NSPrivacyCollectedDataTypes</key>' Resources/PrivacyInfo.xcprivacy | grep -q '<array/>'; then
  PRIVACY_EMPTY=true
fi

SIGNED_READY=false
if [ -n "${TEAM:-}" ] && [ -n "${BUNDLE:-}" ] && [ "$BUNDLE" != "com.nuvori.app" ]; then SIGNED_READY=true; fi

API_READY=false
if [[ "${APIURL:-}" == https://* ]]; then API_READY=true; fi

ICON_READY=false
if [ "${ICON_COUNT:-0}" -gt 0 ]; then ICON_READY=true; fi

STORE_READY=false
if [ "$SIM_PASS" = true ] && [ "$SIGNED_READY" = true ] && [ "$API_READY" = true ] && [ "$ICON_READY" = true ] && [ "$PRIVACY_EMPTY" = false ]; then
  STORE_READY=true
fi

python3 - "$REPORT" "$SIM_PASS" "$SIGNED_READY" "$API_READY" "$ICON_READY" "$PRIVACY_EMPTY" "$STORE_READY" "$BUNDLE" "$TEAM" "$APIURL" "$XCODE_VERSION" "$BUILD_RC" <<'PY'
import json,sys,datetime
p,sim,signing,api,icon,privacy_empty,store,bundle,team,apiurl,xcode,rc=sys.argv[1:]
j={
 "patch":"R3.5.22.4-MAC-XCODE-COMPILE-SIGNING-BUNDLE-PRIVACY-READINESS-GATE",
 "generatedAt":datetime.datetime.now(datetime.timezone.utc).isoformat(),
 "macOS":True,
 "xcodeVersion":xcode,
 "simulatorBuildPass":sim=="true",
 "signingConfigured":signing=="true",
 "releaseAPIConfigured":api=="true",
 "appIconAssetsPresent":icon=="true",
 "privacyManifestStillNeutralOrEmpty":privacy_empty=="true",
 "appStoreReady":store=="true",
 "buildReturnCode":int(rc),
 "buildSettings":{
   "PRODUCT_BUNDLE_IDENTIFIER":bundle or None,
   "DEVELOPMENT_TEAM":team or None,
   "NUVORI_API_BASE_URL":apiurl or None
 },
 "verdict":(
   "R3.5.22.4_MAC_SIMULATOR_BUILD_PASS_APP_STORE_READINESS_HAS_DEPLOYMENT_AND_STORE_BLOCKERS"
   if sim=="true" and store!="true" else
   "R3.5.22.4_MAC_XCODE_APP_STORE_READINESS_PASS"
   if store=="true" else
   "R3.5.22.4_MAC_XCODE_COMPILE_HAS_BLOCKERS"
 )
}
open(p,"w").write(json.dumps(j,indent=2))
print(json.dumps(j,indent=2))
PY

echo
echo "===================================================================="
echo "MAC RESULT: $REPORT"
echo "Simulator build pass: $SIM_PASS"
echo "Signing configured:    $SIGNED_READY"
echo "Release API configured:$API_READY"
echo "AppIcon assets present:$ICON_READY"
echo "Privacy still neutral: $PRIVACY_EMPTY"
echo "App Store ready:       $STORE_READY"
echo "===================================================================="

if [ "$SIM_PASS" != true ]; then
  echo
  echo "----- BUILD TAIL -----"
  printf "%s\n" "$BUILD_OUT" | tail -n 120
  exit 10
fi
