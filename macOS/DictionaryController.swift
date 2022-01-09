//
//  DictionaryController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/8/22.
//

import Cocoa

protocol DictionaryControllerDelegate: AnyObject {
    func dictionaryController(_ controller: DictionaryController,
                              didChangeDirectionTo direction: Dictionary.Direction)
}

/// This should:
/// provide a higher-level wrapper around Dictionary to do parsing etc.
class DictionaryController: NSObject, NSSecureCoding {

    class Result: Codable {
        internal init(input: String, raw: String?, parsed: [ResultItem]?) {
            self.input = input
            self.raw = raw
            self.parsed = parsed
        }
        
        let input: String
        let raw: String?
        let parsed: [ResultItem]?

        static func allRaw(_ results: [Result]) -> String {
            results.compactMap(\.raw).joined(separator: "\n\n")
        }
    }

    static let supportsSecureCoding = true

    var delegate: DictionaryControllerDelegate?
    var direction: Dictionary.Direction {
        didSet {
            delegate?.dictionaryController(self,
                                           didChangeDirectionTo: direction)
        }
    }

    private var dictionary: Dictionary

    internal init(dictionary: Dictionary = .shared,
                  direction: Dictionary.Direction) {
        self.dictionary = dictionary
        self.direction = direction
    }

    required init?(coder: NSCoder) {
        dictionary = .shared
        direction = Dictionary.Direction(rawValue: coder.decodeInteger(forKey: "direction")) ?? .latinToEnglish
    }

    // Required for storyboard initialization
    override init() {
        dictionary = .shared
        direction = .latinToEnglish
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(direction.rawValue, forKey: "direction")
    }

    /// - throws: DWError
    func search(text: String) async throws -> [Result] {
        let split = text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init(_:))
        let dictionaryResults = try await dictionary.getDefinitions(split,
                                                                    direction: direction,
                                                                    options: UserDefaults.standard.dictionaryOptions)

        let parsedResults: [[ResultItem]?] = dictionaryResults
            .map(\.1)
            .map {
                if let rawResult = $0,
                   let (results, _) = parse(rawResult) {
                    return results
                } else {
                    return nil
                }
            }

        return zip(dictionaryResults, parsedResults)
            .map { (dictionaryResult, parsedResult) -> Result in
                Result(input: dictionaryResult.0, raw: dictionaryResult.1, parsed: parsedResult)
            }
    }
}
