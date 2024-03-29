//
//  ResultParser.swift
//  words (macOS)
//
//  Created by Dan Weiner on 4/24/21.
//

#if DEBUG

import Foundation
import Parsing
import DWUtils

// NOTE: this parser is currently unused. Instead, the parser in `DictionaryParser` (simpler, based
// on Pearse codes output by WORDS) is used instead.
// The parser in this file is more powerful and can parse every piece of a definition into a
// highly structured output, but is less stable and requires a lot of manual work to handle edge
// cases.

enum PartOfSpeech: String, CustomStringConvertible, Codable {
    case noun = "N",
         verb = "V",
         adjective = "ADJ",
         adverb = "ADV",
         pronoun = "PRON",
         preposition = "PREP",
         conjunction = "CONJ",
         verbParticiple = "VPAR"
    
    var description: String {
        switch self {
        case .noun: return "n."
        case .verb: return "v."
        case .adjective: return "adj."
        case .adverb: return "adv."
        case .pronoun: return "pron."
        case .preposition: return "prep."
        case .conjunction: return "conj."
        case .verbParticiple: return "vpart."
        }
    }
}

enum Gender: String, CustomStringConvertible, Codable {
    case masculine = "M",
         feminine = "F",
         neuter = "N",
         common = "C"
//         any = "X"
    
    var description: String {
        switch self {
        case .masculine: return "masc."
        case .feminine: return "fem."
        case .neuter: return "neut."
        case .common: return "common"
//        case .any: return "any"
        }
    }

    static let parser = Parsing.Prefix(1).compactMap { (substr: String.SubSequence) -> Gender? in
        Gender(rawValue: String(substr))
    }
}

extension Optional where Wrapped == Gender {
    static let parser = Parsing.Prefix(1).map { (substr: String.SubSequence) -> Gender? in
        Gender(rawValue: String(substr))
    }
}

enum Declension: Int, CustomStringConvertible, Parseable, Codable {
    case first = 1,
         second,
         third,
         fourth,
         fifth
    
    var description: String {
        switch self {
        case .first: return "1st decl."
        case .second: return "2nd decl."
        case .third: return "3rd decl."
        case .fourth: return "4th decl."
        case .fifth: return "5th decl."
        }
    }
}

enum Conjugation: Int, CustomStringConvertible, Codable {
    case first = 1,
         second,
         third,
         fourth
    
    var description: String {
        switch self {
        case .first: return "1st conj."
        case .second: return "2nd conj."
        case .third: return "3rd conj."
        case .fourth: return "4th conj."
        }
    }

    static let parser = Parsing.Prefix(1).compactMap { (substr: String.SubSequence) -> Conjugation? in
        guard let raw = Int(String(substr)),
              let conj = Conjugation(rawValue: raw) else {
                  return nil
              }
        return conj
    }
}

enum Case: String, CustomStringConvertible, Parseable, Codable {
    case nominative = "NOM"
    case accusative = "ACC"
    case ablative = "ABL"
    case dative = "DAT"
    case genitive = "GEN"
    case locative = "LOC"
    case vocative = "VOC"

    var description: String {
        switch self {
        case .nominative:
            return "nom."
        case .accusative:
            return "acc."
        case .ablative:
            return "abl."
        case .dative:
            return "dat."
        case .genitive:
            return "gen."
        case .locative:
            return "loc."
        case .vocative:
            return "voc."
        }
    }
}

private func notLineEnding(_ c: UTF8.CodeUnit) -> Bool {
    c != .init(ascii: "\r") && c != .init(ascii: "\n")
}

struct Word: Equatable, Codable {
    let expansion: Expansion?
    let meaning: String
}

struct Definition: Equatable, Identifiable, Codable {
    var id: String {
        possibilities.description + words.description
    }

    internal init(
        possibilities: [Parse],
        words: [Word],
        truncated: Bool = false
    ) {
        self.possibilities = possibilities
        self.words = words
        self.truncated = truncated
    }
    
    let possibilities: [Parse]
    let words: [Word]
    // Whether or not extra unlikely possibilities were excluded from the list of results.
    let truncated: Bool
}

enum Expansion: Equatable, Codable {
    case noun(String, Declension?, Gender, [String])
    case adj(String, [String])
    case adv(String, [String])
    case verb(String, Conjugation?, [String])
    case pron(String, [String])
    case prep(String, Case?, [String])
    case conj(String, [String])
    case vpar(String, Conjugation?, [String])
    
    var principleParts: String {
        switch self {
        case .noun(let pp, _, _, _), .verb(let pp, _, _), .adj(let pp, _), .adv(let pp, _), .pron(let pp, _), .prep(let pp, _, _), .conj(let pp, _), .vpar(let pp, _, _): return pp
        }
    }
    
    var pos: PartOfSpeech {
        switch self {
        case .noun: return .noun
        case .verb: return .verb
        case .adj: return .adjective
        case .adv: return .adverb
        case .pron: return .pronoun
        case .prep: return .preposition
        case .conj: return .conjunction
        case .vpar: return .verbParticiple
        }
    }

    var notes: [String] {
        switch self {
        case .noun(_, _, _, let notes):
            return notes
        case .adj(_, let notes):
            return notes
        case .adv(_, let notes):
            return notes
        case .verb(_, _, let notes):
            return notes
        case .pron(_, let notes):
            return notes
        case .prep(_, _, let notes):
            return notes
        case .conj(_, let notes):
            return notes
        case .vpar(_, _, let notes):
            return notes
        }
    }

    static let parser: AnyParser<Substring, Expansion> = {
        let principleParts = PrefixUpTo("  ").map(String.init(_:))

        let nounExpansion = principleParts
            .skip(StartsWith("  "))
            .skip(StartsWith(PartOfSpeech.noun.rawValue))
            .take(StartsWith(" (")
                    .take(Declension?.parser)
                    .skip(Parsing.Prefix(2))
                    .skip(StartsWith(") "))
                    .orElse(Skip(StartsWith(" ")).map { Declension?.none }))
            .take(Gender.parser)
            .take(Rest())
            .map {
                Expansion.noun($0.0.0, $0.0.1, $0.0.2, getNotes($0.1))
            }
            .eraseToAnyParser()

        let adjExpansion = principleParts
            .skip(StartsWith("  "))
            .skip(StartsWith(PartOfSpeech.adjective.rawValue))
            .take(Rest())
            .map {
                Expansion.adj($0.0, getNotes($0.1))
            }
            .eraseToAnyParser()

        let advExpansion = principleParts
            .skip(StartsWith("  "))
            .skip(StartsWith(PartOfSpeech.adverb.rawValue))
            .take(Rest())
            .map {
                Expansion.adv($0.0, getNotes($0.1))
            }
            .eraseToAnyParser()

        let pronExpansion = principleParts
            .skip(StartsWith("  "))
            .skip(StartsWith(PartOfSpeech.pronoun.rawValue))
            .take(Rest())
            .map {
                Expansion.pron($0.0, getNotes($0.1))
            }
            .eraseToAnyParser()

        let verbExpansion = principleParts
            .skip(StartsWith("  "))
            .skip(StartsWith(PartOfSpeech.verb.rawValue))
            .take(StartsWith(" (")
                    .take(Conjugation?.parser)
                    .skip(Parsing.Prefix(2))
                    .skip(StartsWith(") "))
                    .orElse(Skip(StartsWith(" ")).map { Conjugation?.none }))
            .take(Rest())
            .map {
                Expansion.verb($0.0.0, $0.0.1, getNotes($0.1))
            }
            .eraseToAnyParser()

        let prepExpansion = principleParts
            .skip(StartsWith("  "))
            .skip(StartsWith(PartOfSpeech.preposition.rawValue))
            .skip(StartsWith("  "))
            .take(Case?.parser)
            .take(Rest())
            .map {
                Expansion.prep($0.0.0, $0.0.1, getNotes($0.1))
            }
            .eraseToAnyParser()

        let conjExpansion = principleParts
            .skip(StartsWith("  "))
            .skip(StartsWith(PartOfSpeech.conjunction.rawValue))
            .take(Rest())
            .map {
                Expansion.conj($0.0, getNotes($0.1))
            }
            .eraseToAnyParser()

        let vparExpansion = principleParts
            .skip(StartsWith("  "))
            .skip(StartsWith(PartOfSpeech.verbParticiple.rawValue))
            .take(StartsWith(" (")
                    .take(Conjugation?.parser)
                    .skip(Parsing.Prefix(2))
                    .skip(StartsWith(") "))
                    .orElse(Skip(StartsWith(" ")).map { Conjugation?.none }))
            .take(Rest())
            .map {
                Expansion.vpar($0.0.0, $0.0.1, getNotes($0.1))
            }
            .eraseToAnyParser()

        return OneOfMany([nounExpansion,
                          adjExpansion,
                          advExpansion,
                          verbExpansion,
                          pronExpansion,
                          prepExpansion,
                          conjExpansion,
                          vparExpansion]).eraseToAnyParser()
    }()
}

enum Number: String, CaseIterable, CustomStringConvertible, Parseable, Codable {
    case singular = "S"
    case plural = "P"

    var description: String {
        switch self {
        case .singular:
            return "sing."
        case .plural:
            return "pl."
        }
    }
}

// A fully declined instance of a noun
struct Noun: Equatable, CustomDebugStringConvertible, CustomStringConvertible, Codable {
    let text: String
    let declension: Declension?
    let variety: Int
    let `case`: Case?
    let number: Number?
    let gender: Gender

    var debugDescription: String {
        "Noun: \(text), \(declension), \(variety), \(`case`), \(number), \(gender)"
    }

    var description: String {
        "\(`case`?.description.appending(" ") ?? "")\(number?.description ?? "")"
    }
}

enum Degree: String, CustomStringConvertible, Codable {
    case positive = "POS"
    case comparative = "COMP"
    case superlative = "SUPER"

    var description: String {
        switch self {
        case .positive: return "pos."
        case .comparative: return "comp."
        case .superlative: return "super."
        }
    }

    static let parser = Parsing.Prefix(5).compactMap { (substr: String.SubSequence) -> Degree? in
        Degree(rawValue: substr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct Adjective: Equatable, CustomDebugStringConvertible, CustomStringConvertible, Codable {
    let text: String
    let declension: Declension?
    let variety: Int
    let `case`: Case?
    let number: Number?
    let gender: Gender?
    let degree: Degree

    var debugDescription: String {
        "Adjective: \(text), \(declension), \(variety), \(`case`), \(number), \(String(describing: gender)), \(degree)"
    }

    var description: String {
        "\(declension?.description.appending(" ") ?? "")\(`case`?.description.appending(" ") ?? "")\(number?.description.appending(" ") ?? "")\(gender?.description.appending(" ") ?? "")\(degree)"
    }
}

struct Adverb: Equatable, CustomDebugStringConvertible, CustomStringConvertible, Codable {
    let text: String
    let degree: Degree

    var debugDescription: String {
        "Adverb: \(text) \(degree)"
    }

    var description: String {
        "\(degree)"
    }
}

struct Pronoun: Equatable, CustomDebugStringConvertible, CustomStringConvertible, Codable {
    let text: String
    let declension: Declension?
    let variety: Int
    let `case`: Case
    let number: Number
    let gender: Gender?

    var debugDescription: String {
        "Pronoun: \(text), \(declension), \(variety), \(`case`), \(number), \(gender)"
    }

    var description: String {
        "\(`case`), \(number), \(gender?.description ?? "")"
    }
}

struct Preposition: Equatable, CustomDebugStringConvertible, CustomStringConvertible, Codable {
    let text: String
    let `case`: Case?

    var debugDescription: String {
        "Pronoun: \(text), \(`case`)"
    }

    var description: String {
        "\(`case`?.description ?? "")"
    }
}

protocol Parseable: CaseIterable, RawRepresentable {
    static var parser: AnyParser<String.SubSequence, Self> { get }
}

extension Parseable where RawValue == Int {
    static var parser: AnyParser<String.SubSequence, Self> {
        Parsing.Prefix(1).compactMap { (substr: String.SubSequence) -> Self? in
            guard let raw = Int(String(substr)),
                  let value = Self.init(rawValue: raw) else {
                      return nil
                  }
            return value
        }.eraseToAnyParser()
    }
}

extension Optional where Wrapped: RawRepresentable, Wrapped.RawValue == Int {
    static var parser: AnyParser<String.SubSequence, Self> {
        Parsing.Prefix(1).map { (substr: String.SubSequence) -> Self in
            guard let raw = Int(String(substr)),
                  let value = Wrapped.init(rawValue: raw) else {
                      return nil
                  }
            return value
        }.eraseToAnyParser()
    }
}

extension Parseable where RawValue == String {
    static var parser: AnyParser<String.SubSequence, Self> {
        let max = allCases.reduce(0) { partialResult, element in
            element.rawValue.count > partialResult ? element.rawValue.count : partialResult
        }
        return Parsing.Prefix(max).compactMap { (substr: String.SubSequence) -> Self? in
            Self.init(rawValue: substr.trimmingCharacters(in: .whitespacesAndNewlines))
        }.eraseToAnyParser()
    }
}

extension Optional where Wrapped: RawRepresentable, Wrapped: CaseIterable, Wrapped.RawValue == String {
    static var parser: AnyParser<String.SubSequence, Self> {
        let max = Wrapped.allCases.reduce(0) { partialResult, element in
            element.rawValue.count > partialResult ? element.rawValue.count : partialResult
        }
        return Parsing.Prefix(max).map { (substr: String.SubSequence) -> Self in
            Wrapped.init(rawValue: substr.trimmingCharacters(in: .whitespacesAndNewlines))
        }.eraseToAnyParser()
    }
}

enum Tense: String, CustomStringConvertible, Codable {
    case present = "PRES"
    case imperfect = "IMPF"
    case future = "FUT"
    case perfect = "PERF"
    case pluperfect = "PLUP"
    case futurePerfect = "FUTP"

    var description: String {
        switch self {
        case .present:
            return "pres."
        case .imperfect:
            return "impf."
        case .future:
            return "fut."
        case .perfect:
            return "perf."
        case .pluperfect:
            return "plup."
        case .futurePerfect:
            return "fut. perf."
        }
    }

    static let parser = Parsing.Prefix(4).compactMap { (substr: String.SubSequence) -> Tense? in
        Tense(rawValue: substr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

enum Voice: String, CustomStringConvertible, Parseable, Codable {
    case active = "ACTIVE"
    case passive = "PASSIVE"
    case middle = "MIDDLE" // ? do we need this ?

    var description: String {
        switch self {
        case .active:
            return "active"
        case .passive:
            return "passive"
        case .middle:
            return "middle"
        }
    }
}

enum Mood: String, CustomStringConvertible, Parseable, Codable {
    case indicative = "IND"
    case infinitive = "INF"
    case subjunctive = "SUB"
    case imperative = "IMP"

    var description: String {
        switch self {
        case .indicative:
            return "ind."
        case .infinitive:
            return "inf."
        case .subjunctive:
            return "sub."
        case .imperative:
            return "imp."
        }
    }
}

enum Person: Int, CustomStringConvertible, Parseable, Codable {
    case first = 1
    case second = 2
    case third = 3

    var description: String {
        switch self {
        case .first:
            return "1st person"
        case .second:
            return "2nd person"
        case .third:
            return "3rd person"
        }
    }
}

// TODO: create a protocol for more DRY
struct Verb: Equatable, CustomDebugStringConvertible, CustomStringConvertible, Codable {
    let text: String
    let conjugation: Conjugation?
    let variety: Int
    let tense: Tense
    let voice: Voice? // Voice can be nil for deponent verbs
    let mood: Mood
    let person: Person?
    let number: Number?

    var debugDescription: String {
        "Verb: \(text) \(conjugation) \(variety) \(tense) \(voice) \(mood) \(person) \(number)"
    }

    var description: String {
        "\(conjugation?.description.appending(" ") ?? "")\(tense) \(voice?.description.appending(" ") ?? "")\(mood) \(person?.description.appending(" ") ?? "")\(number?.description ?? "")"
    }
}

struct VerbParticiple: Equatable, CustomDebugStringConvertible, CustomStringConvertible, Codable {
    let text: String
    let conjugation: Conjugation?
    let variety: Int
    let `case`: Case?
    let number: Number?
    let gender: Gender?
    let tense: Tense
    let voice: Voice

    var debugDescription: String {
        "Participle: \(text), \(conjugation), \(variety), \(`case`), \(number), \(String(describing: gender)), \(tense), \(voice)"
    }

    var description: String {
        "\(conjugation?.description.appending(" ") ?? "")\(`case`?.description.appending(" ") ?? "")\(number?.description.appending(" ") ?? "")\(gender?.description.appending(" ") ?? "")\(tense) \(voice) participle"
    }
}

struct Supine: Equatable, CustomDebugStringConvertible, CustomStringConvertible, Codable {
    let text: String
    let conjugation: Conjugation?
    let variety: Int
    let `case`: Case?
    let number: Number?
    let gender: Gender?

    var debugDescription: String {
        "Supine: \(text), \(conjugation), \(variety), \(`case`), \(number), \(String(describing: gender))"
    }

    var description: String {
        "\(conjugation?.description.appending(" ") ?? "")\(`case`?.description.appending(" ") ?? "")\(number?.description.appending(" ") ?? "")\(gender?.description.appending(" ") ?? "")supine"
    }
}

enum Parse: Equatable, CustomDebugStringConvertible, Codable {
    case noun(Noun)
    case adjective(Adjective)
    case adverb(Adverb)
    case verb(Verb)
    case pronoun(Pronoun)
    case preposition(Preposition)
    case prefix(String)
    case suffix(String)
    case tackon(String)
    case conjunction(String)
    case verbParticiple(VerbParticiple)
    case supine(Supine)

    var debugDescription: String {
        switch self {
        case .noun(let noun):
            return noun.debugDescription
        case .adjective(let adj):
            return adj.debugDescription
        case .adverb(let adv):
            return adv.debugDescription
        case .verb(let verb):
            return verb.debugDescription
        case .pronoun(let pronoun):
            return pronoun.debugDescription
        case .preposition(let preposition):
            return preposition.debugDescription
        case .prefix(let text):
            return "Prefix: \(text)"
        case .suffix(let text):
            return "Suffix: \(text)"
        case .tackon(let text):
            return "Tackon: \(text)"
        case .conjunction(let text):
            return "Conjunction: \(text)"
        case .verbParticiple(let vpar):
            return vpar.debugDescription
        case .supine(let supine):
            return supine.debugDescription
        }
    }

    var word: String {
        switch self {
        case .noun(let noun):
            return noun.text
        case .adjective(let adj):
            return adj.text
        case .adverb(let adv):
            return adv.text
        case .verb(let verb):
            return verb.text
        case .pronoun(let pronoun):
            return pronoun.text
        case .preposition(let preposition):
            return preposition.text
        case .prefix(let text):
            return text
        case .suffix(let text):
            return text
        case .tackon(let text):
            return text
        case .conjunction(let text):
            return text
        case .verbParticiple(let vpar):
            return vpar.text
        case .supine(let supine):
            return supine.text
        }
    }

    var description: String {
        switch self {
        case .noun(let noun):
            return noun.description
        case .adjective(let adj):
            return adj.description
        case .adverb(let adv):
            return adv.description
        case .verb(let verb):
            return verb.description
        case .pronoun(let pronoun):
            return pronoun.description
        case .preposition(let preposition):
            return preposition.description
        case .prefix(_):
            return "prefix"
        case .suffix(_):
            return "suffix"
        case .tackon(_):
            return "tackon"
        case .conjunction(_):
            return "conjunction"
        case .verbParticiple(let vpar):
            return vpar.description
        case .supine(let supine):
            return supine.description
        }
    }

    static let parser: AnyParser<Substring, Parse> = {
        let nounPossibility = Parsing.Prefix<Substring>(21).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
            .skip(StartsWith("N      "))
            .take(Declension?.parser)
            .skip(StartsWith(" "))
            .take(variety)
            .skip(StartsWith(" "))
            .take(Case?.parser)
            .skip(StartsWith(" "))
            .take(Number?.parser)
            .skip(StartsWith(" "))
            .take(Gender.parser)
            .skip(Rest())
            .map {
                ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1)
            }
            .map(Noun.init)
            .map(Parse.noun)
            .eraseToAnyParser()

        let adjPossibility = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("ADJ    "))
            .take(Declension?.parser)
            .skip(StartsWith(" "))
            .take(variety)
            .skip(StartsWith(" "))
            .take(Case?.parser)
            .skip(StartsWith(" "))
            .take(Number?.parser)
            .skip(StartsWith(" "))
            .take(Gender?.parser)
            .skip(StartsWith(" "))
            .take(Degree.parser)
            .skip(Rest())
            .map {
                ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1, $0.2)
            }
            .map(Adjective.init)
            .map(Parse.adjective)
            .eraseToAnyParser()

        let advPossibility = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("ADV    "))
            .take(Degree.parser)
            .skip(Rest())
            .map {
                ($0.0, $0.1)
            }
            .map(Adverb.init)
            .map(Parse.adverb)
            .eraseToAnyParser()

        // ambulav.issem        V      1 1 PLUP ACTIVE  SUB 1 S
        let verbPossibility: AnyParser<Substring, Parse> = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("V      "))
            .take(Conjugation?.parser)
            .skip(StartsWith(" "))
            .take(variety)
            .skip(StartsWith(" "))
            .take(Tense.parser)
            .skip(StartsWith(" "))
            .take(Voice?.parser)
            .skip(StartsWith(" "))
            .take(Mood.parser)
            .skip(StartsWith(" "))
            .take(Person?.parser)
            .skip(StartsWith(" "))
            .take(Number?.parser)
            .skip(Rest())
            .map {
                Verb(text: $0.0.0, conjugation: $0.0.1, variety: $0.0.2, tense: $0.0.3, voice: $0.0.4, mood: $0.1, person: $0.2, number: $0.3)
            }
            .map(Parse.verb)
            .eraseToAnyParser()

        let pronounPossibility: AnyParser<Substring, Parse> = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("PRON   "))
            .take(Declension?.parser)
            .skip(StartsWith(" "))
            .take(variety)
            .skip(StartsWith(" "))
            .take(Case.parser)
            .skip(StartsWith(" "))
            .take(Number.parser)
            .skip(StartsWith(" "))
            .take(Gender?.parser)
            .skip(Rest())
            .map {
                Pronoun(text: $0.0.0, declension: $0.0.1, variety: $0.0.2, case: $0.0.3, number: $0.0.4, gender: $0.1)
            }
            .map(Parse.pronoun)
            .eraseToAnyParser()

        let prepositionPossibility: AnyParser<Substring, Parse> = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("PREP   "))
            .take(Case?.parser)
            .skip(Rest())
            .map {
                Preposition(text: $0.0, case: $0.1)
            }
            .map(Parse.preposition)
            .eraseToAnyParser()

        let prefixPossibility: AnyParser<Substring, Parse> = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("PREFIX "))
            .skip(Rest())
            .map {
                $0
            }
            .map(Parse.prefix)
            .eraseToAnyParser()

        let suffixPossibility: AnyParser<Substring, Parse> = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("SUFFIX "))
            .skip(Rest())
            .map {
                $0
            }
            .map(Parse.suffix)
            .eraseToAnyParser()

        let tackonPossibility: AnyParser<Substring, Parse> = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("TACKON "))
            .skip(Rest())
            .map {
                $0
            }
            .map(Parse.tackon)
            .eraseToAnyParser()

        let conjunctionPossibility: AnyParser<Substring, Parse> = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("CONJ   "))
            .skip(Rest())
            .map {
                $0
            }
            .map(Parse.conjunction)
            .eraseToAnyParser()

        // dat.us               VPAR   1 1 NOM S M PERF PASSIVE PPL
        let vparPossibility = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("VPAR   "))
            .take(Conjugation?.parser)
            .skip(StartsWith(" "))
            .take(variety)
            .skip(StartsWith(" "))
            .take(Case?.parser)
            .skip(StartsWith(" "))
            .take(Number?.parser)
            .skip(StartsWith(" "))
            .take(Gender?.parser)
            .skip(StartsWith(" "))
            .take(Tense.parser)
            .skip(StartsWith(" "))
            .take(Voice.parser)
            .skip(Rest())
            .map { test in
                VerbParticiple(text: test.0.0,
                               conjugation: test.0.1,
                               variety: test.0.2,
                               case: test.0.3,
                               number: test.0.4,
                               gender: test.1,
                               tense: test.2,
                               voice: test.3)
            }
            .map(Parse.verbParticiple)
            .eraseToAnyParser()

        // act.um               SUPINE 3 1 ACC S N
        let supinePossibility = Parsing.Prefix<Substring>(21)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .skip(StartsWith("SUPINE "))
            .take(Conjugation?.parser)
            .skip(StartsWith(" "))
            .take(variety)
            .skip(StartsWith(" "))
            .take(Case?.parser)
            .skip(StartsWith(" "))
            .take(Number?.parser)
            .skip(StartsWith(" "))
            .take(Gender?.parser)
            .skip(Rest())
            .map { test in
                Supine(text: test.0.0,
                               conjugation: test.0.1,
                               variety: test.0.2,
                               case: test.0.3,
                               number: test.0.4,
                               gender: test.1)
            }
            .map(Parse.supine)
            .eraseToAnyParser()



        return OneOfMany([
            nounPossibility,
            adjPossibility,
            advPossibility,
            verbPossibility,
            pronounPossibility,
            prepositionPossibility,
            prefixPossibility,
            suffixPossibility,
            tackonPossibility,
            conjunctionPossibility,
            vparPossibility,
            supinePossibility
        ])
            .eraseToAnyParser()
    }()
}

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

let variety = Parsing.Prefix<Substring>(1).map(String.init(_:)).compactMap(Int.init(_:))

func getNotes(_ str: Substring) -> [String] {
    str
        .nonEmptyString(afterTrimmingCharactersIn: .whitespacesAndNewlines)?
        .components(separatedBy: "  ")
        .compactMap { $0.nonEmptyString(afterTrimmingCharactersIn: .whitespacesAndNewlines) }
        .map(prettifyNote)
    ?? []
}

func prettifyNote(_ note: String) -> String {
    let replacements: [String: String] = [
        "veryrare": "very rare",
        "INTRANS": "intrans.",
        "DEP": "dep.",
        "TRANS": "trans.",
    ]
    return replacements[note] ?? note
}

enum ResultItem: Equatable, Codable, Identifiable {
    case definition(Definition)
    case text(String)

    var id: String {
        switch self {
        case .definition(let def): return def.id
        case .text(let text): return text
        }
    }

    var definition: Definition? {
        if case .definition(let def) = self {
            return def
        } else {
            return nil
        }
    }
}

func parse(_ str: String) -> ([ResultItem], Bool)? {
    #if !DEBUG
    return nil // Don't waste time parsing in release
    #endif

    var results: [ResultItem] = []
    var lines = str
        .split(whereSeparator: \.isNewline)
        .makeIterator()

    var truncated = false

    var possibilities: [Parse] = []

    var exp: Expansion?
    var meaning: String?
    var words: [Word] = []
    let appendNewDefinition = {
        guard !words.isEmpty else { return }
        let definition = Definition(possibilities: possibilities,
                                    words: words)
        results.append(.definition(definition))
        print("Appended new definition", definition)
        possibilities = []
        words = []
    }
    let appendNewWord = {
        guard let _meaning = meaning else { return }
        let word = Word(expansion: exp, meaning: _meaning)
        words.append(word)
        print("Appended new word", word)
        exp = nil
        meaning = nil
    }
    while let line = lines.next() {
        print("🔎 Examining line:", line)
        if let p = Parse.parser.parse(line) {
            appendNewWord()
            appendNewDefinition()
            possibilities.append(p)
            print("Found new possibility", p)
        } else if let e = Expansion.parser.parse(line) {
            appendNewWord()
            exp = e
            print("Found new expansion", e)
        } else if exp != nil || !possibilities.isEmpty {
            if line == "*" {
                // TODO: this is incorrect, truncation asterisk appears per-word, not for an entire query
                truncated = true
                appendNewWord()
                appendNewDefinition()
                print("Line indicates truncation")
            } else if line.reversed().starts(with: "========   UNKNOWN    ".reversed()) {
                appendNewWord()
                appendNewDefinition()
                results.append(.text(String(line)))
            } else if meaning == nil {
                meaning = String(line)
                print("Line is first line of meaning")
            } else {
                meaning! += "\n\(line)"
                print("Line is second+ line of meaning")
            }
        } else {
            print("🚨 Parsing failed at line:")
            print(line)
            results.append(.text(String(line)))
        }
    }

    appendNewWord()
    appendNewDefinition()

    return (results, truncated)
}

#endif
