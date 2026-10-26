# Architecture

Last reviewed: 2026-10-27.

iWords is an AppKit macOS app with a small SwiftUI loading view. The stabilization work and migration to native text results are complete; the app does not need a full SwiftUI rewrite.

## How a lookup works

The UI asks `Dictionary` to look up words. This adapter runs on the main actor and connects the existing storyboard and callback-based code to the asynchronous `DictionaryEngine` interface. Tests can supply a replacement engine through the same interface.

`WordsEngine` runs the bundled dictionary executable. It starts a fresh process for each word and handles requests one at a time, in the order they arrive. An actor owns the processes, and an explicit queue keeps requests from overlapping even while an operation is suspended.

Each response has a five-second deadline and a four-MiB limit on combined output. Both queued and active requests can be cancelled; closing a window cancels its lookup batch. During cleanup, the engine asks the process to terminate, escalates if necessary, and waits asynchronously for it to exit before allowing the next request to run. Launch, I/O, process-exit, timeout, and output-limit errors are passed back to `Dictionary`.

Starting a process for each word keeps requests isolated and lets preference changes take effect on the next batch without restart notifications. The tradeoff is extra launch overhead compared with the previous persistent process. Large multiword workloads have not been benchmarked.

## Dictionary data and preferences

Dictionary data stays bundled with the app. User preferences are stored separately in Application Support, alongside a record of migrations. The preferences have a schema version so migration code can recognize their format.

Each lookup batch gets its own temporary workspace and a fixed snapshot of the preferences. Migration from older versions preserves supported settings without importing generated dictionary data. It leaves legacy dictionaries untouched and does not overwrite unsupported preference schema versions.

Turning off custom dictionary settings preserves the user's saved choices. See [engine and migration details](ENGINE.md) for more information.

## Results and the interface

Parsing, display, export, and restoration share two value models: `LookupResult` and `DefinitionRecord`. Both conform to `Codable` for encoding and decoding and `Sendable` for use across concurrency boundaries. They preserve raw English output and Latin messages that have no codes.

Results appear in an `NSTextView` using attributed text, replacing the previous HTML and `WKWebView` display. Formatting, inflection controls, Perseus links, text selection, Find, font scaling, and printing use native controls and rendering.

UI-facing controllers and their delegates run on the main actor. The app keeps each window controller alive until its window closes, avoiding a retain cycle through the delegate.

## Restoring windows and history

The app uses secure state restoration. Each window has its own identifier and explicitly saves its lookup direction, result data, and back/forward history. When a window is restored, its search text comes from the current history entry.

## Experimental code

Experimental parser and SwiftUI sources are excluded from the shipping target. Historical test fixtures remain in `Experiments`. Parsing and Difference are not application dependencies.

## Tests and validation

The validation recorded for this review includes a macOS build, 23 Swift Testing cases, three UI automation tests, and `git diff --check` for whitespace errors.

The Swift Testing suite covers parsing, the bundled engine, the adapter with an injected engine, and engine behavior: request ordering, split prompts, cancellation, output limits, timeouts, and cleanup. It also covers migration, invalid history, archives, and print rendering.

A separate XCUIAutomation target tests searches, back/forward navigation, selection and Copy, Find, independent windows, and restoration of results and history after quitting and relaunching. Its shared `iWords UI Tests` scheme uses a separate bundle identifier to isolate the tests.

The print-rendering test checks the content and verifies that interactive links are omitted. The suite does not automate physical printer output, invoking Services from another app, or every keyboard and menu combination. Those integrations remain in place.
