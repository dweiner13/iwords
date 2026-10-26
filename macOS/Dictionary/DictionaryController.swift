//
//  DictionaryController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/8/22.
//

import Cocoa

protocol DictionaryControllerDelegate: DictionaryDelegate {}

/// Main-actor bridge from engine responses to the shared display and restoration models.
@MainActor
class DictionaryController: NSObject, @MainActor NSSecureCoding {

    nonisolated static let supportsSecureCoding = true

    weak var delegate: DictionaryControllerDelegate?

    @objc
    dynamic var direction: Dictionary.Direction

    private var dictionary: Dictionary

    init(dictionary: Dictionary? = nil,
                  direction: Dictionary.Direction) {
        self.dictionary = dictionary ?? Dictionary()
        self.direction = direction
        super.init()
        self.dictionary.delegate = self
    }

    func cancel() { dictionary.cancel() }

    required init?(coder: NSCoder) {
        dictionary = Dictionary()
        direction = Dictionary.Direction(rawValue: coder.decodeInteger(forKey: "direction")) ?? .latinToEnglish
        super.init()
        dictionary.delegate = self
    }

    // Required for storyboard initialization
    override init() {
        dictionary = Dictionary()
        direction = .latinToEnglish
        super.init()
        dictionary.delegate = self
    }

    func encode(with coder: NSCoder) {
        coder.encode(direction.rawValue, forKey: "direction")
    }

    /// Completes on the main actor.
    func search(text: String, completion: @escaping (Swift.Result<[LookupResult], DWError>) -> Void) {
        let split = text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init(_:))
        search(terms: split, completion: completion)
    }

    /// Completes on the main actor.
    func search(terms: [String], completion: @escaping (Swift.Result<[LookupResult], DWError>) -> Void) {
        let direction = direction
        dictionary.getDefinitions(terms,
                                  direction: direction) { result in
            completion(result.map {
                self.transformDictionaryResults($0, direction: direction)
            })
        }
    }

    private func transformDictionaryResults(_ dictionaryResults: [(input: String, output: String?)],
                                            direction: Dictionary.Direction) -> [LookupResult] {
        dictionaryResults.map { dictionaryResult in
            let parsed = try? dictionaryResult.output.map {
                try DictionaryParser.parse($0, direction: direction)
            }

            return LookupResult(input: dictionaryResult.input,
                          raw: dictionaryResult.output.map { direction == .latinToEnglish ? trimPearseCodes(fromRawOutput: $0) : $0 },
                          parsed: parsed)
        }
    }

    private func trimPearseCodes(fromRawOutput raw: String) -> String {
        let trimmed = raw.split(whereSeparator: \.isNewline)
            .map {
                ["01 ", "02 ", "03 ", "04 ", "05 ", "06 "].contains(String($0.prefix(3))) ? $0.dropFirst(3) : $0
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
