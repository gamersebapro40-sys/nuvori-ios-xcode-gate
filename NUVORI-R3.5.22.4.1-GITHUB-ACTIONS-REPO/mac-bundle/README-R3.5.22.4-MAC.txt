NUVORI R3.5.22.4 — MAC/XCODE GATE

This portable bundle was exported from the exact post-R3.5.22.3.4.1 state.

On a Mac:

1. Install Xcode.
2. Install XcodeGen.
3. Unzip this bundle preserving folders.
4. In Terminal:
     chmod +x RUN-R3.5.22.4-MAC-GATE.command
     ./RUN-R3.5.22.4-MAC-GATE.command

It will:
- generate one NUVORI.xcodeproj from the existing project.yml
- compile the real Swift source for iOS Simulator with signing disabled
- inspect bundle ID
- inspect Development Team
- inspect NUVORI_API_BASE_URL
- inspect AppIcon assets
- inspect PrivacyInfo.xcprivacy
- emit R3.5.22.4-MAC-RESULT.json

PASSING THE SIMULATOR BUILD DOES NOT MEAN APP STORE READY.

Expected remaining blockers before App Store:
- final unique bundle identifier
- Apple Developer Team/signing
- real HTTPS production API URL
- final AppIcon PNGs
- final PrivacyInfo/App Store privacy disclosures
- device/archive/TestFlight validation

The bundle intentionally contains NO PWA source and NO food database.
