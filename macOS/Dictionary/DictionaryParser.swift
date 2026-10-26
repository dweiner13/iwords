//
//  DictionaryParser.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/7/22.
//

import Foundation

enum DictionaryParser {

    static func parse(_ str: String, direction: Dictionary.Direction) throws -> [DefinitionRecord] {
        let lines = str.split(whereSeparator: \.isNewline)

        guard direction == .latinToEnglish else {
            return lines.map(String.init(_:)).map(DefinitionRecord.unknown)
        }

        var currentInflections: [String] = []
        var currentDictionaryForms: [String] = []

        var currentForms: [DefinitionRecord.Word.Form] = []

        var currentMeaning: String = ""

        var currentResults: [DefinitionRecord] = []

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

        for line in lines {
            guard line.count >= 3 else {
                currentResults.append(.unknown(String(line)))
                continue
            }
            guard line != "No Match" else {
                currentResults.append(.unknown(String(line)))
                continue
            }
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
                currentMeaning += "\n" + restOfLine
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

        return currentResults
    }
}
