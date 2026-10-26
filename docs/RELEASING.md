# Test builds and release work

The default build is ARM64-only with macOS 14 as its deployment target. Ad-hoc signing is portable and appropriate for this local test build. `Config/Local.xcconfig` is ignored and may override signing for an individual developer. The bundled helper is copied into Contents/MacOS and signed with the app's selected identity before app signing.

Sparkle is updated to 2.10.0; existing appcast settings remain in place. Before distributing a release, establish ownership of that feed and its signing keys, configure the intended release channel and verify an end-to-end signed update. Do not publish this test build to the existing feed. Distribution additionally requires Developer ID signing, notarization and validation on a separate Mac.

Validation here covers the ARM engine's upstream fixtures and app integration tests on the current development Mac. A macOS 14 deployment target and Mach-O minimum version are not a substitute for running the app on macOS 14. Verify that OS explicitly before claiming release compatibility, plus settings migration, printing, accessibility, history navigation and updates. UI device automation in this Xcode integration does not support macOS.

The Swift/AppKit UI is retained while replacing deprecated WebView with WKWebView. Experimental parser and SwiftUI prototypes are excluded from the build. Further SwiftUI adoption can proceed by screen while preserving the tested engine boundary. This branch is a modernization test build, not a declaration that every historical alpha-quality issue has been resolved.
