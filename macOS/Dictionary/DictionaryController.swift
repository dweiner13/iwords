//
//  DictionaryController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/8/22.
//

import Cocoa

protocol DictionaryControllerDelegate: DictionaryDelegate {}

/// This should provide a higher-level wrapper around Dictionary to do parsing etc.
class DictionaryController: NSObject, NSSecureCoding {

    class Result: Codable {
        internal init(input: String, raw: String?, parsed: [DictionaryParser.Result]?) {
            self.input = input
            self.raw = raw
            self.parsed = parsed
        }
        
        let input: String
        let raw: String?
        let parsed: [DictionaryParser.Result]?

        static func allRaw(_ results: [Result]) -> String {
            results.compactMap(\.raw).joined(separator: "\n\n")
        }
    }

    static let supportsSecureCoding = true

    var delegate: DictionaryControllerDelegate?

    @objc
    dynamic var direction: Dictionary.Direction

    private var dictionary: Dictionary

    private var settingsObservation: Any?
    private var relocationObservation: Any?

    internal init(dictionary: Dictionary = Dictionary(),
                  direction: Dictionary.Direction) {
        self.dictionary = dictionary
        self.direction = direction
        super.init()
        dictionary.delegate = self

        startObserving()
    }

    private func startObserving() {
        settingsObservation = NotificationCenter.default.addObserver(forName: .dictionarySettingsDidChange,
                                                                     object: nil,
                                                                     queue: nil) { [weak self] _ in
            self?.dictionary.setNeedsRestart()
        }
        relocationObservation = NotificationCenter.default.addObserver(forName: .dictionaryRelocationComplete,
                                                                       object: nil,
                                                                       queue: nil) { [weak self] _ in
            self?.dictionary.setNeedsRestart()
        }
    }

    required init?(coder: NSCoder) {
        dictionary = Dictionary()
        direction = Dictionary.Direction(rawValue: coder.decodeInteger(forKey: "direction")) ?? .latinToEnglish
        super.init()
        dictionary.delegate = self
        startObserving()
    }

    // Required for storyboard initialization
    override init() {
        dictionary = Dictionary()
        direction = .latinToEnglish
        super.init()
        dictionary.delegate = self
        startObserving()
    }

    func encode(with coder: NSCoder) {
        coder.encode(direction.rawValue, forKey: "direction")
    }

    /// - throws: DWError
    func search(text: String, completion: @escaping (Swift.Result<[Result], DWError>) -> Void) {
        let split = text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init(_:))
        search(terms: split, completion: completion)
    }

    /// - throws: DWError
    func search(terms: [String], completion: @escaping (Swift.Result<[Result], DWError>) -> Void) {
        let direction = direction
        dictionary.getDefinitions(terms,
                                  direction: direction,
                                  options: UserDefaults.standard.dictionaryOptions) { result in
            completion(result.map {
                self.transformDictionaryResults($0, direction: direction)
            })
        }
    }

    private func transformDictionaryResults(_ dictionaryResults: [(input: String, output: String?)],
                                            direction: Dictionary.Direction) -> [Result] {
        dictionaryResults.map { dictionaryResult in
            let parsed = try? dictionaryResult.output.map {
                try DictionaryParser.parse($0, direction: direction)
            }

            dictionaryResult.output.map { print($0) }

            return Result(input: dictionaryResult.input,
                          raw: dictionaryResult.output.map(trimPearseCodes(fromRawOutput:)),
                          parsed: parsed)
        }
    }

    private func trimPearseCodes(fromRawOutput raw: String) -> String {
        let trimmed = raw.split(whereSeparator: \.isNewline)
            .map {
                $0.count > 3 ? $0.suffix(from: $0.startIndex.advanced(by: 3)) : $0
            }
            .joined(separator: "\n")
        return String(trimmed)
    }
}

extension DictionaryController: DictionaryDelegate {
    func dictionary(_ dictionary: Dictionary, progressChangedTo progress: Double) {
        delegate?.dictionary(dictionary, progressChangedTo: progress)
    }
}
