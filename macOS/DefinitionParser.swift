//
//  ResultParser.swift
//  words (macOS)
//
//  Created by Dan Weiner on 4/24/21.
//

import Foundation

enum PartOfSpeech: String {
    case noun = "N"
}

enum Case: String {
    case nominative = "NOM",
         accusative = "ACC",
         dative = "DAT",
         ablative = "ABL",
         genitive = "GEN",
         locative = "LOC",
         vocative = "VOC"
}

enum Number: String {
    case singular = "S",
         plural = "P"
}

enum Gender: String {
    case masculine = "M",
         feminine = "F",
         neuter = "N"
}

enum Declension: Int {
    case first = 1,
         second,
         third,
         fourth,
         fifth
}

struct Definition {
    let text: String
}

struct Noun<S: StringProtocol> {
    let root: S
    let ending: S

    let pos: PartOfSpeech
    let declension: Declension
    let variant: Int
    let `case`: Case
    let number: Number
    let gender: Gender
}

enum Token<S: StringProtocol>: Equatable {
    case root(S.SubSequence),
         ending(S.SubSequence),
         pos(PartOfSpeech),
         declension(Declension),
         variant(Int),
         `case`(Case),
         number(Number),
         gender(Gender)
}

func parse<S: StringProtocol>(line: S) -> [Token<S>]? {
    let split = line.split(whereSeparator: { $0.isWhitespace || $0 == "." })
    var tokens: [Token<S>] = []
    
    for s in split {
        switch tokens.last {
        case .none:
            tokens.append(.root(s))
        case .root:
            if s.allSatisfy(\.isLowercase) {
                tokens.append(.ending(s))
            } else if let pos = PartOfSpeech(rawValue: String(s)) {
                tokens.append(.pos(pos))
            } else {
                return nil
            }
        case .ending:
            guard let pos = PartOfSpeech(rawValue: String(s)) else { return nil }
            tokens.append(.pos(pos))
        case .pos:
            guard let raw = Int(String(s)), let declension = Declension(rawValue: raw) else {
                return nil
            }
            tokens.append(.declension(declension))
        case .declension:
            guard let variant = Int(String(s)) else { return nil }
            tokens.append(.variant(variant))
        case .variant:
            guard let `case` = Case(rawValue: String(s)) else { return nil }
            tokens.append(.case(`case`))
        case .case:
            guard let number = Number(rawValue: String(s)) else { return nil }
            tokens.append(.number(number))
        case .number:
            guard let gender = Gender(rawValue: String(s)) else { return nil }
            tokens.append(.gender(gender))
        case .gender:
            break
        }
    }

    fatalError()
}

//enum TokenType {
//    case root, ending, pos, declension, variant, `case`, number, gender
//}

//func oldParse<S: StringProtocol>(line: S) -> [S.SubSequence] {
//    var result: [S.SubSequence] = []
//    var tokenStart: S.Index = line.startIndex
//    var type: TokenType? = .root
//    var index: String.Index = line.startIndex
//    let advance = { index = line.index(after: index) }
//    while type != nil {
//        let c = line[index]
//
//        let newTokenAndAdvance = { (t: TokenType) in
//            let tokenString = line[tokenStart...index]
//            result.append(tokenString)
//            tokenStart = index
//            type = t
//            advance()
//        }
//
//        guard c.isASCII else {
//            fatalError("not ascii: \(c)")
//        }
//
//        switch type {
//        case .root:
//            if let pos = PartOfSpeech(rawValue: String(c)) {
//                type = .case
//                // Don't advance. In case there is no . separator, we may encounter POS
//                // identifier
//            } else if c == "." {
//                advance()
//                newTokenAndAdvance(.ending)
//            } else if c.isWhitespace {
//                advance()
//            }
//        case .ending:
//            if let pos = PartOfSpeech(rawValue: String(c)) {
//                type = .case
//                // Don't advance. In case there is no . separator, we may encounter POS
//                // identifier
//            }
//        }
//    }
//    return result
//}
