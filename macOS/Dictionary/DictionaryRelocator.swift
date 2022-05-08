//
//  DictionaryRelocator.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/6/22.
//

import Foundation

extension NSNotification.Name {
    static let dictionaryRelocationComplete = NSNotification.Name("dictionaryRelocationComplete")
}

enum DictionaryRelocator {

    // MARK: Properties

    /// Will be non-nil if migration has been performed.
    static var dictionarySupportURL: URL?

    // MARK: Private properties

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

    // MARK: Methods

    static func relocateDictionaryToApplicationSupport() throws {
        try _relocate()
    }

    static func initialize() {
        if wasRelocationPerformed() {
            dictionarySupportURL = _dictionarySupportURL
        }
    }

    static func uninstall() throws {
        guard let dictionarySupportURL = dictionarySupportURL else {
            throw DWError("Unable to get dictionary support path.", recoverySuggestion: nil)
        }

        let fileManager = FileManager.default

        try fileManager.removeItem(at: dictionarySupportURL)

        Self.dictionarySupportURL = nil

        NotificationCenter.default.post(name: .dictionaryRelocationComplete, object: nil)
    }

    // MARK: Private methods

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
            // If in DEBUG mode, always overwrite WORD.MDV instead of leaving the existing copy, so
            // that we can easily tweak it for development purposes.
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
