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
         verb = "V"
    
    var description: String {
        switch self {
        case .noun: return "noun"
        case .verb: return "verb"
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

private func notLineEnding(_ c: UTF8.CodeUnit) -> Bool {
    c != .init(ascii: "\r") && c != .init(ascii: "\n")
}

struct Definition: Equatable, Identifiable {
    /// We assume a definition is uniquely identifiable by its principle parts and part of speech.
    var id: String {
        expansion.pos.rawValue + ":" + expansion.principleParts
    }
    
    internal init(possibilities: [String], expansion: Expansion, meaning: String, truncated: Bool = false) {
        self.possibilities = possibilities
        self.expansion = expansion
        self.meaning = meaning
        self.truncated = truncated
    }
    
    let possibilities: [String]
    let expansion: Expansion
    let meaning: String
    // Whether or not extra unlikely possibilities were excluded from the list of results.
    let truncated: Bool
}

enum Expansion: Equatable {
    case noun(String, Declension, Gender)
    case verb(String, Conjugation)
    
    var principleParts: String {
        switch self {
        case .noun(let pp, _, _), .verb(let pp, _): return pp
        }
    }
    
    var pos: PartOfSpeech {
        switch self {
        case .noun: return .noun
        case .verb: return .verb
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
let conj = Prefix(1).compactMap { (substr: String.SubSequence) -> Conjugation? in
    guard let raw = Int(String(substr)),
          let conj = Conjugation(rawValue: raw) else {
        return nil
    }
    return conj
}
let gend = Prefix(1).compactMap { (substr: String.SubSequence) -> Gender? in
    Gender(rawValue: String(substr))
}

let nounExpansion = principleParts
    .skip(StartsWith("  "))
    .skip(StartsWith(PartOfSpeech.noun.rawValue))
    .skip(StartsWith(" ("))
    .take(decl)
    .skip(Prefix(2))
    .skip(StartsWith(") "))
    .take(gend)
    .skip(PrefixThrough("\n"))
    .map(Expansion.noun)

let verbExpansion = principleParts
    .skip(StartsWith("  "))
    .skip(StartsWith(PartOfSpeech.verb.rawValue))
    .skip(StartsWith(" ("))
    .take(conj)
    .skip(Prefix(2))
    .skip(StartsWith(") "))
    .skip(PrefixThrough("\n"))
    .map(Expansion.verb)

let possibility = PrefixUpTo("\n")

let result = nounExpansion.orElse(verbExpansion)
    .take(Rest())

func parse(_ str: String) -> Definition? {
    let lines = str.split(whereSeparator: \.isNewline)
    let possibilities = lines.lazy
        .prefix { substr in
            substr.count == 56 && !substr.contains("]")
        }
        .map(String.init(_:))
    let rest = lines[possibilities.count...].joined(separator: "\n")
    guard let (expansion, meaning) = result.parse(rest) else {
        return nil
    }
    return Definition(
        possibilities: Array(possibilities),
        expansion: expansion,
        meaning: meaning.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: ["*"]),
        truncated: meaning.last == "*"
    )
}
