//
//  DictionarySettingsViewController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/6/22.
//

import Cocoa
import OrderedCollections

let SETTINGS_WINDOW_WIDTH: CGFloat = 500

class DictionarySettingsViewController: NSViewController {

    @objc dynamic
    var doMedievalTricks = false {
        didSet {
            attemptToSetValue(doMedievalTricks, for: .doMedievalTricks)
        }
    }

    @objc dynamic
    var doTwoWords = false {
        didSet {
            attemptToSetValue(doTwoWords, for: .doTwoWords)
        }
    }

    @objc dynamic
    var includeArchaicWords = false {
        didSet {
            attemptToSetValue(!includeArchaicWords, for: .omitArchaic)
        }
    }

    @objc dynamic
    var includeMedievalWords = false {
        didSet {
            attemptToSetValue(!includeMedievalWords, for: .omitMedieval)
        }
    }

    @objc dynamic
    var includeUncommonWords = false {
        didSet {
            attemptToSetValue(!includeUncommonWords, for: .omitUncommon)
        }
    }

    func attemptToSetValue(_ value: Bool, for key: DictionarySettings.Key) {
        do {
            try manager.setValue(value, for: key)
        } catch {
            self.presentError(error)
        }
    }

    // TODO: DictoinarySettings is firing an event when settings i opened
    var manager: DictionarySettings!

    @IBOutlet weak var doMedievalTricksButton: NSButton!
    @IBOutlet weak var doTwoWordsButton: NSButton!
    @IBOutlet weak var includeArchaicWordsButton: NSButton!
    @IBOutlet weak var includeMedievalWordsButton: NSButton!
    @IBOutlet weak var includeUncommonWordsButton: NSButton!

    @IBOutlet weak var errorStackView: NSStackView!
    @IBOutlet weak var errorLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        let url = DictionaryMigrator.dictionarySupportURL.appendingPathComponent("WORD.MDV", isDirectory: false)
        do {
            manager = try DictionarySettings(url: url)
        } catch {
            errorStackView.isHidden = false
            errorLabel.stringValue = "Error reading dictionary settings: \(error.localizedDescription)"
            return
        }

        errorStackView.isHidden = true

        preferredContentSize = view.fittingSize.then {
            $0.width = SETTINGS_WINDOW_WIDTH
        }

        readValuesFromSettings()

        [
            doMedievalTricksButton,
            doTwoWordsButton,
            includeArchaicWordsButton,
            includeMedievalWordsButton,
            includeUncommonWordsButton
        ].forEach {
            $0.isEnabled = true
        }
    }

    private func readValuesFromSettings() {
        doMedievalTricks = manager.value(for: .doMedievalTricks)
        doTwoWords = manager.value(for: .doTwoWords)
        includeArchaicWords = !manager.value(for: .omitArchaic)
        includeMedievalWords = !manager.value(for: .omitMedieval)
        includeUncommonWords = !manager.value(for: .omitUncommon)
    }
}

extension DictionarySettingsViewController: DictionarySettingsDelegate {
    func settingsDidChange(_ settings: DictionarySettings) {
        readValuesFromSettings()
    }
}

extension NSNotification.Name {
    static let dictionarySettingsDidChange = NSNotification.Name("dictionarySettingsDidChange")
}

class DictionarySettings {
    // Only keys for settings managed by iWords are listed here
    struct Key {
        static let doMedievalTricks = Key("DO_MEDIEVAL_TRICKS")
        static let doTwoWords = Key("DO_TWO_WORDS")
        static let omitArchaic = Key("OMIT_ARCHAIC")
        static let omitMedieval = Key("OMIT_MEDIEVAL")
        static let omitUncommon = Key("OMIT_UNCOMMON")

        let rawValue: String

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    private let url: URL

    /// Always represents current settings in file. Should not be altered except when read from file.
    private var settings: OrderedDictionary<String, String> = [:] {
        didSet {
            print("settings.count:", settings.count)
        }
    }

    weak var delegate: DictionarySettingsDelegate?

    /// - Parameter url: URL of WORDS.MDV file to read and write
    init(url: URL) throws {
        self.url = url
        try readSettings()
    }

    func value(for key: Key) -> Bool {
        settings[key.rawValue] == "Y"
    }

    func setValue(_ value: Bool, for key: Key) throws {
        precondition(settings[key.rawValue] != nil)

        let stringValue = value ? "Y" : "N"

        guard settings[key.rawValue] != stringValue else {
            return
        }

        var newSettings = settings
        newSettings[key.rawValue] = stringValue

        do {
            try writeSettings(newSettings)
        } catch {
            // If we encounter an error writing, try to read from to keep us in sync with whatever is in file
            try readSettings()
            throw error
        }
        try readSettings()
    }

    private func readSettings() throws {
        var newSettings: OrderedDictionary<String, String> = [:]

        let data = try Data(contentsOf: url)
        guard let string = String(data: data, encoding: .utf8) else {
            throw DWError("Could not read WORD.MDV")
        }

        for line in string.split(whereSeparator: \.isNewline) {
            let pair = line.split(whereSeparator: \.isWhitespace)
            guard pair.count == 2 else {
                throw DWError("Invalid count when splitting line \"\(line)\"")
            }
            let key = String(pair[0])
            let value = String(pair[1])
            newSettings[key] = value
        }

        if newSettings != settings {
            settings = newSettings

            NotificationCenter.default.post(name: .dictionarySettingsDidChange, object: self)
            delegate?.settingsDidChange(self)
        }
    }

    private func writeSettings(_ settings: OrderedDictionary<String, String>) throws {
        guard !settings.isEmpty else {
            throw DWError("No settings to write")
        }
        let longestKeyLength = settings.keys.max { $0.count <= $1.count }!.count
        var stringToWrite = ""
        for (key, value) in settings {
            let spacer = String(repeating: " ", count: longestKeyLength + 2 - key.count - (value.count / 2))
            stringToWrite += key + spacer + value + "\n"
        }
        guard let data = stringToWrite.data(using: .utf8) else {
            throw DWError("Could not convert string to data")
        }
        try data.write(to: url)
    }
}

protocol DictionarySettingsDelegate: AnyObject {
    func settingsDidChange(_ settings: DictionarySettings)
}
