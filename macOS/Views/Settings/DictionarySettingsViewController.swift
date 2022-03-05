//
//  DictionarySettingsViewController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/6/22.
//

import Cocoa
import OrderedCollections

let SETTINGS_WINDOW_WIDTH: CGFloat = 575

class DictionarySettingsViewController: NSViewController {

    @objc dynamic
    var doMedievalTricks = true {
        didSet {
            do {
                try attemptToSetValue(doMedievalTricks, for: .doMedievalTricks)
            } catch {
                DispatchQueue.main.async {
                    self.readValuesFromSettings()
                }
            }
        }
    }

    @objc dynamic
    var doTwoWords = true {
        didSet {
            do {
                try attemptToSetValue(doTwoWords, for: .doTwoWords)
            } catch {
                DispatchQueue.main.async {
                    self.doTwoWords.toggle()
                }
            }
        }
    }

    @objc dynamic
    var includeArchaicWords = true {
        didSet {
            do {
                try attemptToSetValue(!includeArchaicWords, for: .omitArchaic)
            } catch {
                DispatchQueue.main.async {
                    self.includeArchaicWords.toggle()
                }
            }
        }
    }

    @objc dynamic
    var includeMedievalWords = true {
        didSet {
            do {
                try attemptToSetValue(!includeMedievalWords, for: .omitMedieval)
            } catch {
                DispatchQueue.main.async {
                    self.includeMedievalWords.toggle()
                }
            }
        }
    }

    @objc dynamic
    var includeUncommonWords = true {
        didSet {
            do {
                try attemptToSetValue(!includeUncommonWords, for: .omitUncommon)
            } catch {
                DispatchQueue.main.async {
                    self.includeUncommonWords.toggle()
                }
            }
        }
    }

    func attemptToSetValue(_ value: Bool, for key: DictionarySettings.Key) throws {
        guard let settings = settings else {
            return
        }
        do {
            try settings.setValue(value, for: key)
        } catch {
            self.presentError(error)
            updateView()
            throw error
        }
    }

    var settings: DictionarySettings?

    @IBOutlet weak var doMedievalTricksButton: NSButton!
    @IBOutlet weak var doTwoWordsButton: NSButton!
    @IBOutlet weak var includeArchaicWordsButton: NSButton!
    @IBOutlet weak var includeMedievalWordsButton: NSButton!
    @IBOutlet weak var includeUncommonWordsButton: NSButton!

    @IBOutlet weak var installStackView: NSStackView!

    override func viewDidLoad() {
        super.viewDidLoad()

        preferredContentSize = view.fittingSize.then {
            $0.width = SETTINGS_WINDOW_WIDTH
        }

        updateView()
    }

    private func updateView() {
        do {
            guard DictionaryRelocator.wasRelocationPerformed() else {
                // Just throw so it gets caught by guard
                throw DWError("mockError", recoverySuggestion: nil)
            }
            let url = try DictionaryRelocator.dictionarySupportURL()
                .appendingPathComponent("WORD.MDV", isDirectory: false)
            settings = try DictionarySettings(url: url)
        } catch {
            installStackView.isHidden = false
            setCheckboxesEnabled(false)
            return
        }

        installStackView.isHidden = true

        readValuesFromSettings()

        setCheckboxesEnabled(true)
    }

    private func setCheckboxesEnabled(_ enabled: Bool) {
        [
            doMedievalTricksButton,
            doTwoWordsButton,
            includeArchaicWordsButton,
            includeMedievalWordsButton,
            includeUncommonWordsButton
        ].forEach {
            $0.isEnabled = enabled
        }
    }

    private func readValuesFromSettings() {
        guard let settings = settings else {
            return
        }

        doMedievalTricks = settings.value(for: .doMedievalTricks)
        doTwoWords = settings.value(for: .doTwoWords)
        includeArchaicWords = !settings.value(for: .omitArchaic)
        includeMedievalWords = !settings.value(for: .omitMedieval)
        includeUncommonWords = !settings.value(for: .omitUncommon)
    }

    @IBAction
    private func installFiles(_ sender: Any?) {
        do {
            try DictionaryRelocator.relocateDictionaryToApplicationSupport()
            
        } catch {
            self.presentError(error)
        }
        updateView()
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

    private var didAlreadyRead = false

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

            settings = newSettings

            NotificationCenter.default.post(name: .dictionarySettingsDidChange, object: self)
        } catch {
            // If we encounter an error writing, try to read from to keep us in sync with whatever is in file
            throw error
        }
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

            // Don't post notifications on initialization
            if didAlreadyRead {
                NotificationCenter.default.post(name: .dictionarySettingsDidChange, object: self)
                delegate?.settingsDidChange(self)
            }
        }

        didAlreadyRead = true
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
        print("Wrote new settings to \(url)")
    }
}

protocol DictionarySettingsDelegate: AnyObject {
    func settingsDidChange(_ settings: DictionarySettings)
}
