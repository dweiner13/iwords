//
//  DictionaryController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/8/22.
//

import Cocoa

protocol DictionaryControllerDelegate: DictionaryDelegate {
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

        static func allRawStyled(_ results: [Result], font: NSFont) -> NSAttributedString {
            let attrString = results
                .map { result in
                    NSMutableAttributedString(string: result.input,
                                              attributes: [
                                                .font: NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask),
                                                .paragraphStyle: NSMutableParagraphStyle().then { $0.paragraphSpacing = 4; $0.paragraphSpacingBefore = 20 }]).then {
                        $0.append(.init(string: "\n", attributes: [.font: font]))
                                                    $0.append(.init(string: result.raw ?? "No result", attributes: [.font: font, .paragraphStyle: NSMutableParagraphStyle().then { $0.firstLineHeadIndent = 16; $0.headIndent = 32 }]))
                    }
                }
                .reduce(into: NSMutableAttributedString(string: "", attributes: [.font: font])) { partialResult, styledDefinition in
                    partialResult.append(styledDefinition)
                    partialResult.append(.init(string: "\n", attributes: [.font: font]))
                }
            if attrString.length == 0 {
                return NSAttributedString(string: "No results.", attributes: [.font: font])
            } else {
                return attrString
            }
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

    internal init(dictionary: Dictionary = Dictionary(),
                  direction: Dictionary.Direction) {
        self.dictionary = dictionary
        self.direction = direction
        super.init()
        dictionary.delegate = self
    }

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

extension DictionaryController: DictionaryDelegate {
    func dictionary(_ dictionary: Dictionary, progressChangedTo progress: Double) {
        delegate?.dictionary(dictionary, progressChangedTo: progress)
    }
}
