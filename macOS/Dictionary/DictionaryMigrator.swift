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

    /// URL that relocated dictionary support files would live after relocation. Note that this may
    /// return a valid URL even if relocation has not been performed and there are no files at
    /// the URL.
    static func dictionarySupportURL() throws -> URL {
        let fileManager = FileManager.default

        let appSupportURL = try fileManager.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)

        return appSupportURL
            .appendingPathComponent("iWords",
                                    isDirectory: true)
            .appendingPathComponent("Dictionary Support",
                                    isDirectory: true)
    }

    static func wasRelocationPerformed() -> Bool {
        do {
            let dictionarySupportURL = try dictionarySupportURL()
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

    // Migrate dictionary to local user storage if necessary.
    private static func _relocate() throws {
        let dictionarySupportURL = try dictionarySupportURL()

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

        NotificationCenter.default.post(name: .dictionaryRelocationComplete, object: nil)
    }

}
