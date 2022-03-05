//
//  DictionaryParser.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/7/22.
//

import Foundation

enum DictionaryParser {

    enum Result: Codable {
        case word(Word)
        case unknown(String)
        case addon(String)
        case trick(String)

        struct Word: Codable {
            struct Form: Codable {
                let inflections: [String]
                let dictionaryForms: [String]

                var raw: String {
                    let text = [inflections.joined(separator: "\n"), dictionaryForms.joined(separator: "\n")].joined(separator: "\n")
                    return "\(text)"
                }
            }

            let forms: [Form]
            let meaning: String

            var raw: String {
                let text = [forms.map(\.raw).joined(separator: "\n"), meaning].joined(separator: "\n")
                return "\(text)"
            }
        }

        var raw: String {
            switch self {
            case .word(let word):
                return word.raw
            case .unknown(let str), .addon(let str), .trick(let str):
                return str
            }
        }
    }

    static func parse(_ str: String) throws -> [Result] {
        var currentInflections: [String] = []
        var currentDictionaryForms: [String] = []

        var currentForms: [Result.Word.Form] = []

        var currentMeaning: String = ""

        var currentResults: [Result] = []

        func addPendingWord() {
            if !currentDictionaryForms.isEmpty || !currentInflections.isEmpty {
                addPendingForm()
            }
            currentResults.append(.word(.init(forms: currentForms,
                                              meaning: currentMeaning)))
            currentForms = []
            currentMeaning = ""
        }

        func addPendingForm() {
            currentForms.append(.init(inflections: currentInflections,
                                      dictionaryForms: currentDictionaryForms))
            currentInflections = []
            currentDictionaryForms = []
        }

        for line in str.split(whereSeparator: \.isNewline) {
            let endOfCode = line.index(line.startIndex, offsetBy: 3)
            let code = line[line.startIndex..<endOfCode]
            let restOfLine = String(line[endOfCode...])

            switch code {
            case "01 ":
                if !currentMeaning.isEmpty {
                    addPendingWord()
                }
                if !currentDictionaryForms.isEmpty || !currentInflections.isEmpty {
                    addPendingForm()
                }
                currentInflections.append(restOfLine)
            case "02 ":
                currentDictionaryForms.append(restOfLine)
            case "03 ":
                currentMeaning += restOfLine
            case "04 ":
                if !currentMeaning.isEmpty {
                    addPendingWord()
                }
                currentResults.append(.unknown(restOfLine))
            case "05 ":
                if !currentMeaning.isEmpty {
                    addPendingWord()
                }
                currentResults.append(.addon(restOfLine))
            case "06 ":
                if !currentMeaning.isEmpty {
                    addPendingWord()
                }
                currentResults.append(.trick(restOfLine))
            default:
                throw DWError("Encountered unparseable line: \(line)")
            }
        }

        if !currentMeaning.isEmpty {
            addPendingWord()
        }

        let json = try! JSONEncoder().encode(currentResults)
        let string = String(data: json, encoding: .utf8)!
        print(string)

        return currentResults
    }
}
