# NUVORI App Store blockers carried forward

This staging shell intentionally does NOT pretend these are solved:

1. Production API endpoint
   - The current canonical NUVORIAppState.swift contains:
     http://127.0.0.1:8765
   - That is valid only for local development assumptions.
   - It must become a production-configurable HTTPS endpoint before device/App Store release.

2. Authentication / secure token storage
   - Current native source inventory found no Keychain implementation.
   - Do not persist auth tokens in plain preferences.

3. Signing identity
   - DEVELOPMENT_TEAM is intentionally blank.
   - Bundle identifier is a staging placeholder: com.nuvori.app.
   - Final Apple Developer Team + unique App ID are still required.

4. App icon
   - AppIcon.appiconset exists only as a staging schema.
   - Final PNG assets are not installed.

5. Privacy
   - PrivacyInfo.xcprivacy is a neutral shell manifest.
   - App Store privacy disclosures must be derived from actual production data flows.
   - HealthKit, Speech, microphone and account/backend flows require final review.

6. Real build
   - Windows cannot perform an iOS/Xcode build.
   - GENERATE_XCODE_PROJECT.command and VERIFY_SIMULATOR_BUILD.command must run on macOS with Xcode.

7. Public backend
   - HTTPS/HSTS, trusted proxy, distributed rate limiting, observability and production operations remain separate R3.5.22 deployment work.
