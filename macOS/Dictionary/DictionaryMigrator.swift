//
//  RelocateDictionaryOperation.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/6/22.
//

import Foundation

enum DictionaryMigrator {
    private(set) static var dictionarySupportURL: URL!

    // Migrate dictionary to local user storage if necessary.
    static func relocateDictionaryToApplicationSupport() throws {
        let fileManager = FileManager.default

        let appSupportURL = try fileManager.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)

        dictionarySupportURL = appSupportURL.appendingPathComponent("Dictionary Support",
                                                                    isDirectory: true)

        try fileManager.createDirectory(at: dictionarySupportURL, withIntermediateDirectories: true)

        let filesToMigrate = [
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

        for file in filesToMigrate {
            guard let srcURL = Bundle.main.url(forResource: file, withExtension: nil) else {
                throw DWError(description: "Unable to get URL for dictionary file \(file)")
            }

            let dstURL = dictionarySupportURL.appendingPathComponent(file, isDirectory: false)

            do {
                try fileManager.copyItem(at: srcURL, to: dstURL)
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                print("Not migrating \(file) because it already exists in destination")
            }
        }
    }

}
