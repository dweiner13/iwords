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
            let inflections: [String]
            let dictionaryForm: String
            let meaning: String

            var raw: String {
                let text = [inflections.joined(separator: "\n"), dictionaryForm, meaning].joined(separator: "\n")
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
        var currentDictionaryForm: String = ""
        var currentMeaning: String = ""

        var currentResults: [Result] = []

        for line in str.split(whereSeparator: \.isNewline) {
            let endOfCode = line.index(line.startIndex, offsetBy: 3)
            let code = line[line.startIndex..<endOfCode]
            let restOfLine = String(line[endOfCode...])

            switch code {
            case "01 ":
                if !currentMeaning.isEmpty {
                    currentResults.append(.word(.init(inflections: currentInflections,
                                                      dictionaryForm: currentDictionaryForm,
                                                      meaning: currentMeaning)))
                    currentInflections = []
                    currentDictionaryForm = ""
                    currentMeaning = ""
                }
                currentInflections.append(restOfLine)
            case "02 ":
                currentDictionaryForm += restOfLine
            case "03 ":
                currentMeaning += restOfLine
            case "04 ":
                if !currentMeaning.isEmpty {
                    currentResults.append(.word(.init(inflections: currentInflections,
                                                      dictionaryForm: currentDictionaryForm,
                                                      meaning: currentMeaning)))
                    currentInflections = []
                    currentDictionaryForm = ""
                    currentMeaning = ""
                }
                currentResults.append(.unknown(restOfLine))
            case "05 ":
                if !currentMeaning.isEmpty {
                    currentResults.append(.word(.init(inflections: currentInflections,
                                                      dictionaryForm: currentDictionaryForm,
                                                      meaning: currentMeaning)))
                    currentInflections = []
                    currentDictionaryForm = ""
                    currentMeaning = ""
                }
                currentResults.append(.addon(restOfLine))
            case "06 ":
                if !currentMeaning.isEmpty {
                    currentResults.append(.word(.init(inflections: currentInflections,
                                                      dictionaryForm: currentDictionaryForm,
                                                      meaning: currentMeaning)))
                    currentInflections = []
                    currentDictionaryForm = ""
                    currentMeaning = ""
                }
                currentResults.append(.trick(restOfLine))
            default:
                throw DWError("Encountered unparseable line: \(line)")
            }
        }

        if !currentMeaning.isEmpty {
            currentResults.append(.word(.init(inflections: currentInflections,
                                              dictionaryForm: currentDictionaryForm,
                                              meaning: currentMeaning)))
            currentInflections = []
            currentDictionaryForm = ""
            currentMeaning = ""
        }

        let json = try! JSONEncoder().encode(currentResults)
        let string = String(data: json, encoding: .utf8)!
        print(string)

        return currentResults
    }
}
