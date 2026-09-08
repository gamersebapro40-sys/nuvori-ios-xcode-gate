NUVORI R3.5.22.4.1 — GITHUB ACTIONS macOS XCODE GATE

SOURCE EXPORT:
F:\NUVORI_DATA\exports\NUVORI-R3.5.22.4-MAC-BUNDLE-2026-09-08T04-36-11-159Z.zip

SOURCE EXPORT MANIFEST:
72ea8c954d5f54de679990fb496154b2004b359028574ff4e69acef716a61eaa

PURPOSE:
Run the exact R3.5.22.4 Mac/Xcode gate on a GitHub-hosted macOS runner.

HOW TO USE:

1. Create a NEW PRIVATE GitHub repository.
   Suggested name:
     nuvori-ios-xcode-gate

2. Upload/commit EVERYTHING inside this prepared directory:
     F:\NUVORI_DATA\exports\NUVORI-R3.5.22.4.1-GITHUB-ACTIONS-REPO

   The repository root must contain:
     .github/workflows/nuvori-ios-xcode-gate.yml
     mac-bundle/

3. Open GitHub:
     Actions
     -> NUVORI iOS Xcode Gate
     -> Run workflow

4. Wait for the macOS job.

5. Open the completed workflow run.
   Under Artifacts download:
     NUVORI-R3.5.22.4-XCODE-GATE-EVIDENCE

6. Send back:
     R3.5.22.4-MAC-RESULT.json
   and, if compile failed:
     R3.5.22.4-MAC-GATE.log

NO APPLE SECRETS ARE REQUIRED FOR THIS FIRST GATE.

This run uses:
- iOS Simulator
- CODE_SIGNING_ALLOWED=NO

So it proves compile/project integration WITHOUT configuring your Apple
Developer account yet.

The workflow does NOT:
- upload NUVORI food databases
- upload the PWA
- upload F:/NUVORI_DATA
- sign an app
- publish to TestFlight
- publish to App Store

Only the 23-file exported native/Xcode bundle is committed.

EXPECTED CURRENT STORE BLOCKERS EVEN IF COMPILE PASSES:
- final bundle ID
- Development Team
- real HTTPS NUVORI_API_BASE_URL
- final AppIcon files
- final privacy disclosure
- device/archive/TestFlight

SECURITY:
Keep the repository PRIVATE.
Do not add Apple credentials, Supabase service-role keys, production secrets,
or signing certificates for this compile-only gate.
