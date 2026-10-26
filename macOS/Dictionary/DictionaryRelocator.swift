import Foundation

extension NSNotification.Name {
    static let dictionaryRelocationComplete = NSNotification.Name("dictionaryRelocationComplete")
}

/// User preferences outlive engine upgrades. Generated dictionaries always come
/// from the signed bundle, never from Intel-era or user-writable copies.
struct DictionaryStorage {
    let root: URL
    let resources: URL
    private let manager = FileManager.default
    static let resourceNames = ["ADDONS.LAT", "DICTFILE.GEN", "EWDSFILE.GEN", "INDXFILE.GEN",
                                "INFLECTS.LAT", "INFLECTS.SEC", "STEMFILE.GEN", "UNIQUES.LAT"]
    static let preferenceKeys: Set<String> = ["DO_MEDIEVAL_TRICKS", "DO_TWO_WORDS", "OMIT_ARCHAIC",
                                             "OMIT_MEDIEVAL", "OMIT_UNCOMMON"]
    struct State: Codable {
        var version = 1
        var enabled: Bool
    }
    var settingsDirectory: URL { root.appendingPathComponent("Settings-v1", isDirectory: true) }
    var settingsURL: URL { settingsDirectory.appendingPathComponent("WORD.MDV") }
    private var stateURL: URL { root.appendingPathComponent("migration.json") }

    func state() throws -> State? {
        guard manager.fileExists(atPath: stateURL.path) else { return nil }
        let state = try JSONDecoder().decode(State.self, from: Data(contentsOf: stateURL))
        guard state.version == 1 else { throw DWError("Unsupported dictionary settings version.") }
        return state
    }

    func initialize() throws -> Bool {
        if let state = try state() {
            if state.enabled { _ = try String(contentsOf: settingsURL, encoding: .utf8) }
            return state.enabled
        }
        let legacyRoot = root.appendingPathComponent("Dictionary Support")
        let candidates = [legacyRoot.appendingPathComponent("Engine-1f2f0fb-arm64-v1/WORD.MDV"),
                          legacyRoot.appendingPathComponent("WORD.MDV")]
        if let legacy = candidates.first(where: { manager.fileExists(atPath: $0.path) }) {
            try enable(legacy: legacy)
            return true
        }
        try saveState(enabled: false)
        return false
    }

    func enable(legacy: URL? = nil) throws {
        _ = try state() // Never overwrite settings written by a newer application.
        try manager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        if !manager.fileExists(atPath: settingsURL.path) {
            let defaults = try String(contentsOf: resources.appendingPathComponent("WORD.MDV"), encoding: .utf8)
            let old = try legacy.map { try String(contentsOf: $0, encoding: .utf8) }
            let merged = Self.merge(defaults: defaults, legacy: old ?? "")
            try merged.write(to: settingsURL, atomically: true, encoding: .utf8)
        }
        // Commit last: interrupted migrations are safe to retry.
        try saveState(enabled: true)
    }

    func disable() throws {
        _ = try state()
        // Preserve preferences for re-enabling, and prevent legacy re-import on launch.
        try saveState(enabled: false)
    }

    private func saveState(enabled: Bool) throws {
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(State(enabled: enabled)).write(to: stateURL, options: .atomic)
    }

    static func merge(defaults: String, legacy: String) -> String {
        var values: [String: String] = [:]
        for line in legacy.split(whereSeparator: \.isNewline) {
            let pair = line.split(whereSeparator: \.isWhitespace)
            if pair.count == 2, preferenceKeys.contains(String(pair[0])), ["Y", "N"].contains(String(pair[1])) {
                values[String(pair[0])] = String(pair[1])
            }
        }
        return defaults.split(whereSeparator: \.isNewline).map { line in
            guard let key = line.split(whereSeparator: \.isWhitespace).first,
                  let value = values[String(key)] else { return String(line) }
            return String(key).padding(toLength: 33, withPad: " ", startingAt: 0) + value
        }.joined(separator: "\n") + "\n"
    }

    /// Each request gets an immutable settings snapshot and links to bundled data.
    /// The caller removes this directory when its requests finish.
    func workspace(enabled: Bool) throws -> URL {
        let directory = manager.temporaryDirectory.appendingPathComponent("iWords-" + UUID().uuidString)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            for name in Self.resourceNames {
                let source = resources.appendingPathComponent(name)
                guard manager.fileExists(atPath: source.path) else { throw EngineError.missingResources }
                try manager.createSymbolicLink(at: directory.appendingPathComponent(name), withDestinationURL: source)
            }
            try manager.copyItem(at: enabled ? settingsURL : resources.appendingPathComponent("WORD.MDV"),
                                 to: directory.appendingPathComponent("WORD.MDV"))
            return directory
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }
}

@MainActor
enum DictionaryRelocator {
    private(set) static var dictionarySupportURL: URL?
    private static func storage() throws -> DictionaryStorage {
        guard let resources = Bundle.main.url(forResource: "WORD", withExtension: "MDV")?.deletingLastPathComponent() else {
            throw EngineError.missingResources
        }
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true).appendingPathComponent("iWords")
        return DictionaryStorage(root: root, resources: resources)
    }

    static func initialize() {
        do {
            let storage = try storage()
            dictionarySupportURL = try storage.initialize() ? storage.settingsDirectory : nil
        } catch {
            dictionarySupportURL = nil
            NSLog("Dictionary settings migration failed: %@", error.localizedDescription)
        }
    }

    static func relocateDictionaryToApplicationSupport() throws {
        let storage = try storage()
        try storage.enable()
        dictionarySupportURL = storage.settingsDirectory
        NotificationCenter.default.post(name: .dictionaryRelocationComplete, object: nil)
    }

    static func uninstall() throws {
        try storage().disable()
        dictionarySupportURL = nil
        NotificationCenter.default.post(name: .dictionaryRelocationComplete, object: nil)
    }

    static func makeWorkspace() throws -> URL {
        try storage().workspace(enabled: dictionarySupportURL != nil)
    }
}
