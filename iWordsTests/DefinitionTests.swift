import Foundation
import Darwin
import AppKit
import Intents
import Testing
@testable import iWords

@MainActor
@Suite(.serialized)
struct ServicesAndShortcutsTests {
    private func response(to intent: LookUpIntent) async -> LookUpIntentResponse {
        let handler = LookUpIntentHandler()
        return await withCheckedContinuation { continuation in
            handler.handle(intent: intent) { continuation.resume(returning: $0) }
        }
    }

    @Test(arguments: [Direction.latinToEnglish, .englishToLatin])
    func shortcutsAcceptMultipleWordsAndPreserveContinuation(direction: Direction) async throws {
        let intent = LookUpIntent()
        intent.direction = direction
        intent.query = direction == .latinToEnglish ? [" amo\nsum "] : [" love\tbe "]
        let result = await response(to: intent)
        #expect(result.code == .success)
        let definitions = try #require(result.definition)
        #expect(definitions.count == 2)
        #expect(definitions[0].contains(direction == .latinToEnglish ? "love" : "amo"))
        let activity = try #require(result.userActivity)
        #expect(activity.activityType == "LookUpIntent")
        #expect(activity.userInfo?["query"] as? [String] ==
                (direction == .latinToEnglish ? ["amo", "sum"] : ["love", "be"]))
        #expect(activity.userInfo?["direction"] as? Int ==
                (direction == .latinToEnglish ? 0 : 1))
    }

    @Test(arguments: [[], [" \n\t"], [String(repeating: "a", count: 257)], ["a\u{0000}b"]])
    func shortcutsRejectUnusableInput(query: [String]) async {
        let intent = LookUpIntent()
        intent.direction = .latinToEnglish
        intent.query = query
        let result = await response(to: intent)
        #expect(result.code == .failure)
    }

    @Test func missingQueryRequestsResolution() {
        let intent = LookUpIntent()
        LookUpIntentHandler().resolveQuery(for: intent) { results in
            #expect(results.count == 1)
        }
    }

    @Test func serviceReportsMissingAndBlankPasteboardText() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let provider = ServiceProvider()
        var error: NSString?
        provider.lookUp(pasteboard, userData: "0", error: &error)
        #expect(error == "Could not retrieve text from the pasteboard.")
        pasteboard.setString(" \n", forType: .string)
        error = nil
        provider.lookUp(pasteboard, userData: "1", error: &error)
        #expect(error == "Please select a word to look up.")
    }

    private func waitForLookup(_ query: SearchQuery, in controller: LookupWindowController) async throws {
        let deadline = ContinuousClock.now + .seconds(10)
        while controller.backForwardController.currentSearchQuery != query && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(controller.backForwardController.currentSearchQuery == query)
    }

    @Test func serviceAndContinuationUseLookupWindowBehindAnotherWindow() async throws {
        let lookup = LookupWindowController.newController()
        let window = try #require(lookup.window)
        window.makeKeyAndOrderFront(nil)
        let otherWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                                   styleMask: [.titled], backing: .buffered, defer: false)
        otherWindow.isReleasedWhenClosed = false
        defer {
            otherWindow.close()
            lookup.close()
        }
        otherWindow.makeKeyAndOrderFront(nil)
        #expect(NSApp.orderedWindows.first === otherWindow)

        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString(" love\n", forType: .string)
        var error: NSString?
        ServiceProvider().lookUp(pasteboard, userData: "1", error: &error)
        #expect(error == nil)
        try await waitForLookup(SearchQuery("love", .englishToLatin), in: lookup)
        #expect(window.isVisible)

        let delegate = try #require(NSApp.delegate as? AppDelegate)
        let activity = NSUserActivity(activityType: "LookUpIntent")
        activity.userInfo = ["query": ["amo", "sum"], "direction": 0]
        otherWindow.makeKeyAndOrderFront(nil)
        #expect(delegate.application(NSApp, continue: activity, restorationHandler: { _ in }))
        try await waitForLookup(SearchQuery("amo sum", .latinToEnglish), in: lookup)

        activity.userInfo = ["query": ["amo"], "direction": 99]
        #expect(!delegate.application(NSApp, continue: activity, restorationHandler: { _ in }))
        #expect(!delegate.application(NSApp, willContinueUserActivityWithType: "unrelated"))
    }
}

struct DefinitionTests {
    @Test func `Pearse records preserve forms meanings and addons`() throws {
        let output = "01 am.o V 1 1 PRES ACTIVE IND 1 S\n02 amo, amare, amavi, amatus\n03 love; like;\n05 -que = and\n06 spelling variant"
        let results = try DictionaryParser.parse(output, direction: .latinToEnglish)
        #expect(results.count == 3)
        guard case .word(let word) = results.first else {
            Issue.record("Expected a word record")
            return
        }
        #expect(word.forms.count == 1)
        #expect(word.forms.first?.dictionaryForms == ["amo, amare, amavi, amatus"])
        #expect(word.meaning.contains("love"))
        #expect(results[1].raw == "-que = and")
    }

    @Test func `English results remain readable`() throws {
        let output = "amo love\ncaritas affection"
        let results = try DictionaryParser.parse(output, direction: .englishToLatin)
        #expect(results.map(\.raw) == ["amo love", "caritas affection"])
    }

    @Test func `Unexpected output reports a parsing error`() {
        #expect(throws: DWError.self) {
            try DictionaryParser.parse("99 unexpected", direction: .latinToEnglish)
        }
    }
}

@MainActor
struct EngineIntegrationTests {
    private func lookup(_ word: String, direction: Dictionary.Direction,
                        engine: Dictionary) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            engine.getDefinition(word, direction: direction) { result in
                continuation.resume(with: result.map { $0 ?? "" }.mapError { $0 as Error })
            }
        }
    }

    @Test func `Bundled engine supports both directions and repeated requests`() async throws {
        let engine = Dictionary()
        for _ in 0..<3 {
            let latin = try await lookup("amo", direction: .latinToEnglish, engine: engine)
            #expect(latin.contains("03 love"))
            let parsed = try DictionaryParser.parse(latin, direction: .latinToEnglish)
            #expect(!parsed.isEmpty)
            let english = try await lookup("love", direction: .englishToLatin, engine: engine)
            #expect(english.contains("amo, amare"))
        }
    }

    @Test(arguments: ["a", "e", "sum", "multusque", "xyzzy"])
    func `Single letters irregular forms enclitics and unknowns complete`(word: String) async throws {
        let engine = Dictionary()
        let result = try await lookup(word, direction: .latinToEnglish, engine: engine)
        #expect(!result.isEmpty)
        if word == "xyzzy" {
            #expect(result.contains("UNKNOWN") || result.contains("No Match"))
        } else {
            #expect(result.contains("03 "))
        }
    }

    @Test func `Fresh processes answer subsequent requests`() async throws {
        let engine = Dictionary()
        _ = try await lookup("amo", direction: .latinToEnglish, engine: engine)
        let result = try await lookup("sum", direction: .latinToEnglish, engine: engine)
        #expect(result.contains("03 "))
    }
}

struct EngineFailureTests {
    private func fixture(_ body: String) throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("engine")
        try ("#!/bin/sh\n" + body).write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return (directory, executable)
    }

    @Test(arguments: 0..<4)
    func timeoutAndCancellationReapProcesses(iteration: Int) async throws {
        let (directory, executable) = try fixture("echo $$ > pid\nexec /bin/sleep 30\n")
        defer { try? FileManager.default.removeItem(at: directory) }
        let engine = WordsEngine(executable: executable, timeout: .seconds(1))
        await #expect(throws: EngineError.self) {
            try await engine.lookup("amo", direction: .latinToEnglish, directory: directory)
        }
        let pid = try #require(Int32(String(contentsOf: directory.appendingPathComponent("pid"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
        #expect(kill(pid, 0) == -1)
        let longEngine = WordsEngine(executable: executable, timeout: .seconds(30))
        try FileManager.default.removeItem(at: directory.appendingPathComponent("pid"))
        let active = Task { try await longEngine.lookup("amo", direction: .latinToEnglish, directory: directory) }
        for _ in 0..<100 where !FileManager.default.fileExists(atPath: directory.appendingPathComponent("pid").path) {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("pid").path))
        let queued = Task { try await longEngine.lookup("sum", direction: .latinToEnglish, directory: directory) }
        try await Task.sleep(for: .milliseconds(20))
        queued.cancel()
        await #expect(throws: CancellationError.self) { try await queued.value }
        active.cancel()
        await #expect(throws: CancellationError.self) { try await active.value }
        let cancelledPID = try #require(Int32(String(contentsOf: directory.appendingPathComponent("pid"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
        #expect(kill(cancelledPID, 0) == -1)
    }

    @Test func outputLimitExitAndMissingExecutableAreErrors() async throws {
        let (directory, executable) = try fixture("while :; do printf '012345678901234567890123456789\\n'; done\n")
        defer { try? FileManager.default.removeItem(at: directory) }
        let engine = WordsEngine(executable: executable, outputLimit: 128)
        await #expect(throws: EngineError.self) { try await engine.lookup("amo", direction: .latinToEnglish, directory: directory) }
        try "#!/bin/sh\nexit 7\n".write(to: executable, atomically: false, encoding: .utf8)
        await #expect(throws: EngineError.self) { try await engine.lookup("amo", direction: .latinToEnglish, directory: directory) }
        let missing = WordsEngine(executable: directory.appendingPathComponent("missing"))
        await #expect(throws: (any Error).self) { try await missing.lookup("amo", direction: .latinToEnglish, directory: directory) }
    }

    @Test func concurrentRequestsAreSerializedAndRecoverAfterFailure() async throws {
        let (directory, executable) = try fixture("""
        read direction
        read word
        if ! /bin/mkdir lock; then exit 9; fi
        printf '%s\\n' "$word" >> requests
        /bin/rmdir lock
        printf 'Language changed to LATIN_TO_ENGLISH\\n\\n=>'
        /bin/sleep 0.05
        printf '03 %s\\n=>' "$word"
        exec /bin/sleep 30
        """)
        defer { try? FileManager.default.removeItem(at: directory) }
        let engine = WordsEngine(executable: executable)
        await #expect(throws: EngineError.self) { try await engine.lookup("two words", direction: .latinToEnglish, directory: directory) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for word in ["amo", "sum", "a", "e", "multus"] {
                group.addTask {
                    let result = try await engine.lookup(word, direction: .latinToEnglish, directory: directory)
                    #expect(result == "03 \(word)")
                }
            }
            try await group.waitForAll()
        }
        let requests = try String(contentsOf: directory.appendingPathComponent("requests"), encoding: .utf8)
        #expect(requests.split(separator: "\n").count == 5)
    }
}

struct MigrationTests {
    @Test func migrationPreservesOnlyPreferencesAndIsRepeatable() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let resources = root.appendingPathComponent("Bundle")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try "DO_TWO_WORDS Y\nOMIT_ARCHAIC N\nOTHER Y\n".write(to: resources.appendingPathComponent("WORD.MDV"), atomically: true, encoding: .utf8)
        for name in DictionaryStorage.resourceNames {
            try Data("bundled".utf8).write(to: resources.appendingPathComponent(name))
        }
        let legacy = root.appendingPathComponent("Dictionary Support/Engine-1f2f0fb-arm64-v1")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try "DO_TWO_WORDS N\nOMIT_ARCHAIC invalid\nOTHER N\n".write(to: legacy.appendingPathComponent("WORD.MDV"), atomically: true, encoding: .utf8)
        let storage = DictionaryStorage(root: root, resources: resources)
        #expect(try storage.initialize())
        let migrated = try String(contentsOf: storage.settingsURL, encoding: .utf8)
        #expect(migrated.contains("DO_TWO_WORDS                     N"))
        #expect(migrated.contains("OMIT_ARCHAIC N"))
        #expect(migrated.contains("OTHER Y"))
        #expect(try storage.initialize())
        #expect(try String(contentsOf: storage.settingsURL, encoding: .utf8) == migrated)
        let workspace = try storage.workspace(enabled: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        #expect(try String(contentsOf: workspace.appendingPathComponent("WORD.MDV"), encoding: .utf8) == migrated)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: workspace.appendingPathComponent("DICTFILE.GEN").path) == resources.appendingPathComponent("DICTFILE.GEN").path)
        try storage.disable()
        #expect(try !storage.initialize())
        try storage.enable()
        #expect(try String(contentsOf: storage.settingsURL, encoding: .utf8) == migrated)
    }

    @Test func futureMigrationVersionsAreNotOverwritten() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data(#"{"version":99,"enabled":true}"#.utf8)
        try data.write(to: root.appendingPathComponent("migration.json"))
        let storage = DictionaryStorage(root: root, resources: root)
        #expect(throws: DWError.self) { try storage.initialize() }
        #expect(throws: DWError.self) { try storage.enable() }
        #expect(try Data(contentsOf: root.appendingPathComponent("migration.json")) == data)
    }
}

@MainActor
struct ModelAndRestorationTests {
    @Test func resultArchiveAndBackForwardHistoryRoundTrip() throws {
        let results = [LookupResult(input: "amo", raw: "love", parsed: [.unknown("love")])]
        let restored = try JSONDecoder().decode([LookupResult].self, from: JSONEncoder().encode(results))
        #expect(restored.first?.input == "amo")
        #expect(restored.first?.parsed?.first?.raw == "love")
        let history = BackForwardController()
        history.recordVisit(to: SearchQuery("amo", .latinToEnglish))
        history.recordVisit(to: SearchQuery("love", .englishToLatin))
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        history.encode(with: coder)
        coder.finishEncoding()
        let decoder = try NSKeyedUnarchiver(forReadingFrom: coder.encodedData)
        let restoredHistory = BackForwardController()
        restoredHistory.decode(with: decoder)
        #expect(restoredHistory.currentSearchQuery?.searchText == "love")
        restoredHistory.goBack(nil)
        #expect(restoredHistory.currentSearchQuery?.searchText == "amo")
        restoredHistory.goForward(nil)
        #expect(restoredHistory.currentSearchQuery?.direction == .englishToLatin)
    }
}

private struct FixedResponseEngine: DictionaryEngine {
    let response: String
    func lookup(_ input: String, direction: Dictionary.Direction, directory: URL) async throws -> String? {
        response
    }
}

@MainActor
struct AdapterAndRenderingTests {
    @Test(arguments: [Dictionary.Direction.latinToEnglish, .englishToLatin])
    func rawExportPreservesUncodedText(direction: Dictionary.Direction) async throws {
        let response = direction == .latinToEnglish ? "No Match" : "amo love"
        let controller = DictionaryController(dictionary: Dictionary(engine: FixedResponseEngine(response: response)), direction: direction)
        let results: [LookupResult] = try await withCheckedThrowingContinuation { continuation in
            controller.search(text: "example") { continuation.resume(with: $0) }
        }
        #expect(LookupResult.allRaw(results) == response)
    }

    @Test func nativeRenderingRetainsContentAndOmitsPrintActions() throws {
        let parsed = try DictionaryParser.parse("01 am.o V\n02 amo, amare\n03 love;", direction: .latinToEnglish)
        let results = [LookupResult(input: "amo", raw: "amo love", parsed: parsed)]
        let display = ResultsRenderer.render(results, scale: 1, formatted: true, showInflections: false)
        #expect(display.string.contains("Show inflections"))
        #expect(!display.string.contains("am.o V"))
        let print = ResultsRenderer.render(results, scale: 1, formatted: true, showInflections: true, includeActions: false)
        #expect(print.string.contains("am.o V"))
        #expect(print.string.contains("love;"))
        #expect(!print.string.contains("Look up in Perseus"))
        #expect(!print.string.contains("Show inflections"))
    }

    @Test func invalidHistoryEntriesAreIgnored() {
        #expect(SearchQuery(fromPropertyListRepresentation: "invalid") == nil)
        #expect(SearchQuery(fromPropertyListRepresentation: ["searchText": "amo", "direction": 99]) == nil)
    }
}
