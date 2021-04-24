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

struct Definition {
    let possibilities: [String]
    let expansion: Expansion
    let definition: String
}

struct Expansion: Equatable {
    let principleParts: String
    let pos: PartOfSpeech
    let declension: Declension
    let gender: Gender
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
let gend = Prefix(1).compactMap { (substr: String.SubSequence) -> Gender? in
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
    .map(Expansion.init)

let possibility = PrefixUpTo("\n")

let result = Prefix { str in
        return str.count == 57
    }
    .take(expansion)
    .take(Rest())
