//
//  DictionaryParser.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/7/22.
//

import Foundation

// 01 qu.o                 PRON   1 0 ABL S M
// 01 qu.o                 PRON   1 0 ABL S N
// 02
// 03 who; that; which, what; of which kind/degree; person/thing/time/point that;
// 03 who/what/which?, what/which one/man/person/thing? what kind/type of?;
// 03 who/whatever, everyone who, all that, anything that;
// 03 any; anyone/anything, any such; unspecified some; (after si/sin/sive/ne);
// 03 who?, which?, what?; what kind of?;
// 01 quo                  ADV    POS
// 02 quo  ADV    lesser
// 03 where, to what place; to what purpose; for which reason, therefore;
// 01 quo                  CONJ
// 02 quo  CONJ    lesser
// 03 whither, in what place, where;

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
