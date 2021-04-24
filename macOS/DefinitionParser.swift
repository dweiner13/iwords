//
//  ResultParser.swift
//  words (macOS)
//
//  Created by Dan Weiner on 4/24/21.
//

import Foundation
import Parsing

enum PartOfSpeech: String {
    case noun = "N",
         verb = "V"
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

enum Conjugation: Int {
    case first = 1,
         second,
         third,
         four
}

let output = """
vi.a                 N      1 1 NOM S F
vi.a                 N      1 1 VOC S F
vi.a                 N      1 1 ABL S F
via, viae  N (1st) F   [XXXAX]
way, road, street; journey;
"""

private func notLineEnding(_ c: UTF8.CodeUnit) -> Bool {
    c != .init(ascii: "\r") && c != .init(ascii: "\n")
}

struct Definition: Equatable {
    let possibilities: [String]
    let expansion: Expansion
    let meaning: String
}

struct Expansion: Equatable {
    let principleParts: String
    let pos: PartOfSpeech
    let declension: Declension
    let gender: Gender?
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
let gend = Prefix(1).map { (substr: String.SubSequence) -> Gender? in
    Gender(rawValue: String(substr))
}

let expansion = principleParts
    .skip(StartsWith("  "))
    .take(pos)
    .skip(StartsWith(" ("))
    .take(decl)
    .skip(Prefix(2))
    .skip(StartsWith(") "))
    .take(gend)
    .skip(PrefixThrough("\n"))
    .map(Expansion.init)

let possibility = PrefixUpTo("\n")

let result = expansion
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
        meaning: meaning.replacingOccurrences(of: "\n", with: " ")
    )
}
