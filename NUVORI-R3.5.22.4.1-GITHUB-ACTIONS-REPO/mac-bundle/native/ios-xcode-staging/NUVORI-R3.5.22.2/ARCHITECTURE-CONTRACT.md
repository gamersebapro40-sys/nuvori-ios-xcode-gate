# Native architecture contract — R3.5.22.2

This stage preserves a single native app owner.

Canonical native source:
- ../../ios-swiftui/NUVORI/NUVORIApp.swift       -> ONE @main owner
- ../../ios-swiftui/NUVORI/RootView.swift        -> ONE root view
- ../../ios-swiftui/NUVORI/NUVORIAppState.swift  -> ONE app state
- existing APIClient / HealthKit / Speech source reused directly

Important:
- No Swift source is copied into this staging tree.
- The XcodeGen target references the canonical existing Swift directory.
- native-reference/HealthKitBridge.swift is intentionally EXCLUDED.
- No WKWebView/PWA wrapper is added.
- No second SwiftUI implementation is created.
- No PWA renderer is modified.

The staging project container is delivery infrastructure, not a second app architecture.
