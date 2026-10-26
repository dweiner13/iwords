# iWords arm-dev
With macOS 28 looming and Rosetta sunsetting, this dev branch updates iWords for Apple silicon and out of convenience, it targets macOS 14 or later with an eye towards adding iOS 14+ support later. The Ada engine is rebuilt from the latest source (https://github.com/mk270/whitakers-words) for ARM and included; Rosetta and Ada compilers are not needed to build or run.\*
The codebase has been updated to match modern macOS security/notarization requirements and generally stabilized- see [architecture review](docs/ARCHITECTURE.md). Most of these changes are back end, but most visibly, the results window has been updated from HTML to AppKit. iWords remains more or less a wrapper around Words, but we now use actor-based process management to make the engine swappable and fully abstract the engine with `DictionaryEngine`. This also helps stabilize lookups through auxiliary system services / Shortcuts access.
This branch is locally tested and built for macOS 27 Golden Gate. From manual testing, it runs great on Apple Silicon without Rosetta and pretty much works like the current release.

 This branch does not (yet):
- provide backwards compatibility with Intel macs
- include architecture for iOS
- have developer signing

I haven't looked at creating a universal build or backporting architectural changes with the swappable engine for a new Intel iWords release (yet). It might not be that bad and I suspect the dispersed iWords userbase might appreciate having an up-to-date application on older macs. Because the Words engine constitutes the bulk of the application size, I'd prefer not to bundle two engines and maintain separate Intel/ARM releases, but I'm not sure how that works with Sparkle. It *should* be as simple as swapping the engine, as described, but I don't have an Intel mac to test on.


## Architecture and dependencies

Swift AppKit controllers manage windows, settings and lookup history. `Dictionary` is a main-actor adapter to the `DictionaryEngine` interface. The `WordsEngine` actor serializes requests, starts a fresh WORDS subprocess for each word, and handles cancellation, bounded output, timeout and cleanup; `DictionaryParser` converts Pearse-coded output into structured results. An AppKit text view renders results directly as attributed text, with native selection, links, text scaling and printing. The Ada engine remains separate, so its linguistic behavior can be preserved and tested independently of the Swift UI.

| Dependency | Purpose | Version/source |
| --- | --- | --- |
| Sparkle | App updates | 2.10.0, Swift Package Manager |
| swift-collections | History collection support | 1.7.4, Swift Package Manager |
| WORDS | Latin morphology and dictionary | Pinned source, rebuilt ARM64- [newly built engine documentation](docs/ENGINE.md) |

DWUtils and Flow helpers have been replaced with standard Swift, Foundation and AppKit code. The unused Parsing and Difference dependencies and bundled Lodash were removed. Experimental parser/SwiftUI files are excluded from the shipping target under [Experiments](Experiments/README.md). 


## Build from a clean checkout

1. Clone this repository and open `iWords.xcodeproj` in Xcode. Use Xcode 26 or later for actor-isolated conformances and Swift Testing; this branch was verified in the current Xcode environment with the macOS 27 SDK.
2. Select the **iWords (macOS)** scheme and **My Mac** destination. Allow Swift Package Manager to resolve the checked-in package versions.
3. Build and run. Signing defaults to local **ad-hoc signing** without a developer account. The minimum OS is set centrally in `Config/macOS.xcconfig`.
4. Parser, engine, migration and archive tests are available under **iWords UI Tests** as an XCUIAutomation suite. Its UITesting configuration uses a separate app identifier, isolating test history and window restoration from the normal app.

Optional personal signing overrides belong in `Config/Local.xcconfig`, which is ignored by Git (DEVELOPMENT_TEAM,  CODE_SIGN_IDENTITY).
For a fresh build after switching from an older branch, use Product → Clean Build Folder. No sibling DWUtils checkout or global Ada installation is needed. (-> Initial package resolution requires network access.)

\*Note that the engine does include a patch for auto-generated trampoline code, which I was not previously needed. This patch is necessary because the Ada engine as written fails hardened runtime standards for modern macOS, thereby precluding eventual notarization and signing.
