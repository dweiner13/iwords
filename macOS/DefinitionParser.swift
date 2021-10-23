//
//  ResultParser.swift
//  words (macOS)
//
//  Created by Dan Weiner on 4/24/21.
//

import Foundation
import Parsing

enum PartOfSpeech: String, CustomStringConvertible {
    case noun = "N",
         verb = "V",
         adjective = "ADJ"
    
    var description: String {
        switch self {
        case .noun: return "noun"
        case .verb: return "verb"
        case .adjective: return "adjective"
        }
    }
}

enum Gender: String {
    case masculine = "M",
         feminine = "F",
         neuter = "N"
    
    var description: String {
        switch self {
        case .masculine: return "masculine"
        case .feminine: return "feminine"
        case .neuter: return "neuter"
        }
    }
}

enum Declension: Int, CustomStringConvertible {
    case first = 1,
         second,
         third,
         fourth,
         fifth
    
    var description: String {
        switch self {
        case .first: return "1st declension"
        case .second: return "2nd declension"
        case .third: return "3rd declension"
        case .fourth: return "4th declension"
        case .fifth: return "5th declension"
        }
    }
}

enum Conjugation: Int, CustomStringConvertible {
    case first = 1,
         second,
         third,
         fourth
    
    var description: String {
        switch self {
        case .first: return "1st conjugation"
        case .second: return "2nd conjugation"
        case .third: return "3rd conjugation"
        case .fourth: return "4th conjugation"
        }
    }
}

enum Case: String {
    case nominative = "NOM"
    case accusative = "ACC"
    case ablative = "ABL"
    case dative = "DAT"
    case genitive = "GEN"
    case locative = "LOC"
    case vocative = "VOC"
}

private func notLineEnding(_ c: UTF8.CodeUnit) -> Bool {
    c != .init(ascii: "\r") && c != .init(ascii: "\n")
}

struct Definition: Equatable, Identifiable {
    var id: String {
        return expansion.principleParts + expansion.pos.description
    }

    internal init(possibilities: [Possibility], expansion: Expansion, meaning: String, truncated: Bool = false) {
        self.possibilities = possibilities
        self.expansion = expansion
        self.meaning = meaning
        self.truncated = truncated
    }
    
    let possibilities: [Possibility]
    let expansion: Expansion
    let meaning: String
    // Whether or not extra unlikely possibilities were excluded from the list of results.
    let truncated: Bool
}

enum Expansion: Equatable {
    case noun(String, Declension, Gender)
    case adj(String)
    case verb(String, Conjugation)
    
    var principleParts: String {
        switch self {
        case .noun(let pp, _, _), .verb(let pp, _), .adj(let pp): return pp
        }
    }
    
    var pos: PartOfSpeech {
        switch self {
        case .noun: return .noun
        case .verb: return .verb
        case .adj: return .adjective
        }
    }
}

enum Number: String {
    case singular = "S"
    case plural = "P"
}

// A fully declined instance of a noun
struct Noun: Equatable, CustomDebugStringConvertible, CustomStringConvertible {
    let text: String
    let declension: Declension
    let variety: Int
    let `case`: Case
    let number: Number
    let gender: Gender

    var debugDescription: String {
        "Noun: \(text), \(declension), \(variety), \(`case`), \(number), \(gender)"
    }

    var description: String {
        "\(text) (\(declension)"
    }
}

enum Degree: String {
    case positive = "POS"
    case comparative = "COMP"
    case superlative = "SUPER"
}

struct Adjective: Equatable, CustomDebugStringConvertible {
    let text: String
    let declension: Declension
    let variety: Int
    let `case`: Case
    let number: Number
    let gender: Gender
    let degree: Degree

    var debugDescription: String {
        return "Adjective: \(text), \(declension), \(variety), \(`case`), \(number), \(gender), \(degree)"
    }
}

enum Possibility: Equatable, CustomDebugStringConvertible {
    case noun(Noun)
    case adjective(Adjective)

    var debugDescription: String {
        switch self {
        case .noun(let noun):
            return noun.debugDescription
        case .adjective(let adj):
            return adj.debugDescription
        }
    }
}

let principleParts = PrefixUpTo("  ").map(String.init(_:))

let pos = Prefix(1).compactMap { (substr: String.SubSequence) -> PartOfSpeech? in
    PartOfSpeech(rawValue: String(substr))
}

let decl = Prefix(1).compactMap { (substr: String.SubSequence) -> Declension? in
    guard let raw = Int(String(substr)),
          let decl = Declension(rawValue: raw) else {
        return nil
    }
    return decl
}
let `case` = Prefix(3).compactMap { (substr: String.SubSequence) -> Case? in
    guard let decl = Case(rawValue: String(substr)) else {
        return nil
    }
    return decl
}
let conj = Prefix(1).compactMap { (substr: String.SubSequence) -> Conjugation? in
    guard let raw = Int(String(substr)),
          let conj = Conjugation(rawValue: raw) else {
        return nil
    }
    return conj
}
let number = Prefix(1).compactMap { (substr: String.SubSequence) -> Number? in
    Number(rawValue: String(substr))
}
let gend = Prefix(1).compactMap { (substr: String.SubSequence) -> Gender? in
    Gender(rawValue: String(substr))
}
let degr = Prefix(5).compactMap { (substr: String.SubSequence) -> Degree? in
    Degree(rawValue: substr.trimmingCharacters(in: .whitespacesAndNewlines))
}

let nounExpansion = principleParts
    .skip(StartsWith("  "))
    .skip(StartsWith(PartOfSpeech.noun.rawValue))
    .skip(StartsWith(" ("))
    .take(decl)
    .skip(Prefix(2))
    .skip(StartsWith(") "))
    .take(gend)
    .skip(Rest())
    .map(Expansion.noun)
    .eraseToAnyParser()

let adjExpansion = principleParts
    .skip(StartsWith("  "))
    .skip(StartsWith(PartOfSpeech.adjective.rawValue))
    .skip(Rest())
    .map(Expansion.adj)
    .eraseToAnyParser()

let verbExpansion = principleParts
    .skip(StartsWith("  "))
    .skip(StartsWith(PartOfSpeech.verb.rawValue))
    .skip(StartsWith(" ("))
    .take(conj)
    .skip(Prefix(2))
    .skip(StartsWith(") "))
    .skip(Rest())
    .map(Expansion.verb)
    .eraseToAnyParser()

let expansion = OneOfMany([nounExpansion, adjExpansion, verbExpansion])

// Parses a string with a given total length N. First M characters <= N must be non-whitespace, and
// will be returned.
struct Padded<Input>: Parser where Input: Collection,
                                   Input.SubSequence == Input,
                                   Input.Element == UTF8.CodeUnit {
    let length: Int

    func parse(_ input: inout Input) -> Input? {
        guard input.count >= length else { return nil }

        for i in input.indices {
            let c = Character(Unicode.Scalar(input[i]))
            guard input.distance(from: input.startIndex, to: i) > 0 || !c.isWhitespace else {
                return nil
            }
            if c.isWhitespace {
                return input[...i]
            }
        }
        return input
    }
}

let variety = Prefix<Substring>(1).map(String.init(_:)).compactMap(Int.init(_:))

let nounPossibility = Prefix<Substring>(21).map {
        $0.trimmingCharacters(in: .whitespaces)
    }
    .skip(StartsWith("N      "))
    .take(decl)
    .skip(StartsWith(" "))
    .take(variety)
    .skip(StartsWith(" "))
    .take(`case`)
    .skip(StartsWith(" "))
    .take(number)
    .skip(StartsWith(" "))
    .take(gend)
    .skip(Rest())
    .map {
        ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1)
    }
    .map(Noun.init)
    .map(Possibility.noun)

let adjPossibility = Prefix<Substring>(21)
    .map {
        $0.trimmingCharacters(in: .whitespaces)
    }
    .skip(StartsWith("ADJ    "))
    .take(decl)
    .skip(StartsWith(" "))
    .take(variety)
    .skip(StartsWith(" "))
    .take(`case`)
    .skip(StartsWith(" "))
    .take(number)
    .skip(StartsWith(" "))
    .take(gend)
    .skip(StartsWith(" "))
    .take(degr)
    .skip(Rest())
    .map {
        ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1, $0.2)
    }
    .map(Adjective.init)
    .map(Possibility.adjective)

let possibility = nounPossibility.orElse(adjPossibility)

let result = nounExpansion.orElse(verbExpansion)
    .take(Rest())

func parse(_ str: String) -> ([Definition], Bool)? {
    var definitions: [Definition] = []
    var lines = str
        .split(whereSeparator: \.isNewline)
        .makeIterator()

    var truncated = false

    var possibilities: [Possibility] = []
    var exp: Expansion? = nil
    var meaning: String? = nil
    let appendNewDefinition = {
        guard !possibilities.isEmpty, let e = exp, let m = meaning else { return }
        definitions.append(.init(possibilities: possibilities,
                                 expansion: e,
                                 meaning: m))
        possibilities = []
        exp = nil
        meaning = nil
    }
    while let line = lines.next() {
        if let p = possibility.parse(line) {
            appendNewDefinition()
            possibilities.append(p)
        } else if exp == nil {
            guard let e = expansion.parse(line) else {
                return nil
            }
            exp = e
        } else {
            if line == "*" {
                truncated = true
            } else if meaning == nil {
                meaning = String(line)
            } else {
                meaning! += "\n\(line)"
            }
        }
    }

    appendNewDefinition()

    return (definitions, truncated)
}

//func parse(_ str: String) -> Definition? {
//    let lines = str.split(whereSeparator: \.isNewline)
//    let possibilities = lines.lazy
//        .prefix { substr in
//            substr.count == 56 && !substr.contains("]")
//        }
//        .compactMap(possibility.parse)
//    let rest = lines[possibilities.count...].joined(separator: "\n")
//    guard let (expansion, meaning) = result.parse(rest) else {
//        return nil
//    }
//    return Definition(
//        possibilities: Array(possibilities.map { "\($0)" }),
//        expansion: expansion,
//        meaning: meaning.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: ["*"]),
//        truncated: meaning.last == "*"
//    )
//}
