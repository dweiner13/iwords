//
//  DictionaryParser.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/7/22.
//

import Foundation

enum ResultPiece {
    case word(WordResult)
    case unknown
    case addons
    
}

enum DictionaryParser {
    struct WordResult {
        let parse: String
        let expansion: String
        let meaning: String
    }

    static func parse(_ str: Substring) throws -> [WordResult] {
        var currentParse = ""
        var currentExpansion = ""
        var currentMeaning = ""
        var currentResults: [WordResult] = []
        for line in str.split(whereSeparator: \.isNewline) {
            let endOfCode = str.index(str.startIndex, offsetBy: 3)
            switch line[str.startIndex...endOfCode] {
            case "01 ":
                if !currentMeaning.isEmpty {
                    currentResults.append(WordResult(parse: currentParse, expansion: currentExpansion, meaning: currentMeaning))
                    currentParse = ""
                    currentExpansion = ""
                    currentMeaning = ""
                }
                currentParse += line[endOfCode...] + "\n"
            case "02 ":
                currentExpansion += line[endOfCode...] + "\n"
            case "03 ":
                currentMeaning += line[endOfCode...]
            default:
                throw DWError("Encountered unparseable line: \(str)")
            }
        }

        return currentResults
    }
}
