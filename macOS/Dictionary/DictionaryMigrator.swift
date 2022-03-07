//
//  RelocateDictionaryOperation.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/6/22.
//

import Foundation

extension NSNotification.Name {
    static let dictionaryRelocationComplete = NSNotification.Name("dictionaryRelocationComplete")
}

enum DictionaryRelocator {

    static func relocateDictionaryToApplicationSupport() throws {
        try _relocate()
    }

    /// Will only exist after migration has been performed.
    static var dictionarySupportURL: URL?

    static func uninstall() throws {
        guard let dictionarySupportURL = dictionarySupportURL else {
            throw DWError("Unable to get dictionary support path.", recoverySuggestion: nil)
        }

        let fileManager = FileManager.default

        try fileManager.removeItem(at: dictionarySupportURL)

        Self.dictionarySupportURL = nil

        print("Removed items at \(dictionarySupportURL)")

        NotificationCenter.default.post(name: .dictionaryRelocationComplete, object: nil)
    }

    // TODO: This is gross, fix it later
    static func initialize() {
        if wasRelocationPerformed() {
            dictionarySupportURL = _dictionarySupportURL
        }
    }

    private static func wasRelocationPerformed() -> Bool {
        do {
            guard let dictionarySupportURL = _dictionarySupportURL else {
                throw DWError("Unable to get dictionary support path.", recoverySuggestion: nil)
            }
            return fileNamesToMigrate
                .allSatisfy {
                    let dstURL = dictionarySupportURL.appendingPathComponent($0, isDirectory: false)
                    return FileManager.default.fileExists(atPath: dstURL.path)
                }
        } catch {
            return false
        }
    }

    private static let fileNamesToMigrate = [
        "WORD.MDV",
        "ADDONS.LAT",
        "CHECKEWD.",
        "DICTFILE.GEN",
        "DICTLINE.GEN",
        "EWDSFILE.GEN",
        "EWDSLIST.GEN",
        "INDXFILE.GEN",
        "INFLECTS.LAT",
        "INFLECTS.SEC",
        "STEMFILE.GEN",
        "STEMLIST.GEN",
        "UNIQUES.LAT"
    ]

    private static let _dictionarySupportURL: URL? = {
        let fileManager = FileManager.default

        let appSupportURL = try? fileManager.url(for: .applicationSupportDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: nil,
                                                    create: true)

        return appSupportURL?
            .appendingPathComponent("iWords",
                                    isDirectory: true)
            .appendingPathComponent("Dictionary Support",
                                    isDirectory: true)
    }()

    // Migrate dictionary to local user storage if necessary.
    private static func _relocate() throws {
        guard let dictionarySupportURL = _dictionarySupportURL else {
            throw DWError("Unable to get dictionary support path.", recoverySuggestion: nil)
        }

        let fileManager = FileManager.default

        try fileManager.createDirectory(at: dictionarySupportURL, withIntermediateDirectories: true)

        for file in fileNamesToMigrate {
            guard let srcURL = Bundle.main.url(forResource: file, withExtension: nil) else {
                throw DWError("Unable to get URL for dictionary file \(file)")
            }

            let dstURL = dictionarySupportURL.appendingPathComponent(file, isDirectory: false)

#if DEBUG
            if file == "WORD.MDV" {
                try? fileManager.removeItem(at: dstURL)
            }
#endif

            do {
                try fileManager.copyItem(at: srcURL, to: dstURL)
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                print("Not migrating \(file) because it already exists in destination")
            }
        }

        Self.dictionarySupportURL = _dictionarySupportURL

        NotificationCenter.default.post(name: .dictionaryRelocationComplete, object: nil)
    }

}
