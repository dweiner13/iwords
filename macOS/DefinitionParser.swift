//
//  ResultParser.swift
//  words (macOS)
//
//  Created by Dan Weiner on 4/24/21.
//

import Foundation

enum PartOfSpeech: String {
    case noun = "N",
         verb = "V"
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
    case invalid = "X",
         singular = "S",
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

enum Conjugation: Int {
    case first = 1,
         second,
         third,
         four
}

enum Tense: String {
    case present = "PRES",
         future = "FUT" // TODO: fill in all tesnes
}

enum Voice: String {
    case active = "ACTIVE",
         passive = "PASSIVE"
}

enum Mood: String {
    case infinitive = "INF",
         indicative = "IND",
         imperative = "IMP"
}

enum Person: Int {
    case none,
         first,
         second,
         third
}

protocol Word {
    var root: String { get }
    var ending: String { get }

    var pos: PartOfSpeech { get }

    init?(_ line: String)
}

struct Noun: Word {
    let root: String
    let ending: String
    let pos: PartOfSpeech

    let declension: Declension
    let variant: Int
    let `case`: Case
    let number: Number
    let gender: Gender

    init?(_ line: String) {
        guard let tokens: [Token] = parse(line: line) else {
            return nil
        }
        let valid = tokens.allSatisfy {
            switch $0 {
            case .root, .ending, .pos, .declension, .variant, .case, .number, .gender:
                return true
            default:
                return false
            }
        }
        if !valid {
            return nil
        }

        for token in tokens {
            switch token {
            case .root(let root): self.root = String(root)
            case .ending(let ending): self.ending = String(ending)
            case .pos(let pos): self.pos = pos
            case .declension(let declension): self.declension = declension
            case .variant(let variant): self.variant = variant
            case .case(let `case`): self.case = `case`
            case .number(let number): self.number = number
            case .gender(let gender): self.gender = gender
            default:
                return nil
            }
        }
    }
}

struct Verb: Word {
    let root: String
    let ending: String
    let pos: PartOfSpeech

    let conjugation: Conjugation
    let variant: Int
    let tense: Tense
    let voice: Voice
    let mood: Mood
    let person: Person
    let number: Number

    init?(_ line: String) {
        guard let tokens: [Token] = parse(line: line) else {
            return nil
        }
        let valid = tokens.allSatisfy {
            switch $0 {
            case .root, .ending, .pos, .conjugation, .variant, .tense, .voice, .mood, .person, .number:
                return true
            default:
                return false
            }
        }
        if !valid {
            return nil
        }

        for token in tokens {
            switch token {
            case .root(let root): self.root = String(root)
            case .ending(let ending): self.ending = String(ending)
            case .pos(let pos): self.pos = pos
            case .conjugation(let conjugation): self.conjugation = conjugation
            case .variant(let variant): self.variant = variant
            case .tense(let tense): self.tense = tense
            case .voice(let voice): self.voice = voice
            case .mood(let mood): self.mood = mood
            case .person(let person): self.person = person
            case .number(let number): self.number = number
            default:
                return nil
            }
        }
    }
}

struct PartialWord {
    let root: String?
    let ending: String?
    let pos: PartOfSpeech?

    let declension: Declension?
    let variant: Int?
    let `case`: Case?
    let number: Number?
    let gender: Gender?

    let conjugation: Conjugation?
    let tense: Tense?
    let voice: Voice?
    let mood: Mood?
    let person: Person?
}

enum Token: Equatable, Hashable {
    case root(String.SubSequence),
         ending(String.SubSequence),
         pos(PartOfSpeech),
         declension(Declension),
         variant(Int),
         `case`(Case),
         number(Number),
         gender(Gender),
         conjugation(Conjugation),
         tense(Tense),
         voice(Voice),
         mood(Mood),
         person(Person)
}

func parse(line: String) -> Word? {
    guard let tokens: [Token] = parse(line: line) else {
        print("Failed to parse \(line)")
        return  nil
    }
    return nil
}

func parse(line: String) -> [Token]? {
    let split = line.split(whereSeparator: { $0.isWhitespace || $0 == "." })
    var tokens: [Token] = []

    var linePOS: PartOfSpeech?
    
    for s in split {
        switch (tokens.last, linePOS) {
        case (.none, _):
            tokens.append(.root(s))
        case (.root, _):
            if s.allSatisfy(\.isLowercase) {
                tokens.append(.ending(s))
            } else if let pos = PartOfSpeech(rawValue: String(s)) {
                linePOS = pos
                tokens.append(.pos(pos))
            } else {
                return nil
            }
        case (.ending, _):
            guard let pos = PartOfSpeech(rawValue: String(s)) else { return nil }
            linePOS = pos
            tokens.append(.pos(pos))

        // Noun path
        case (.pos, .noun):
            guard let raw = Int(String(s)), let declension = Declension(rawValue: raw) else {
                return nil
            }
            tokens.append(.declension(declension))
        case (.declension, _):
            guard let variant = Int(String(s)) else { return nil }
            tokens.append(.variant(variant))
        case (.variant, .noun):
            guard let `case` = Case(rawValue: String(s)) else { return nil }
            tokens.append(.case(`case`))
        case (.case, _):
            guard let number = Number(rawValue: String(s)) else { return nil }
            tokens.append(.number(number))
        case (.number, .noun):
            guard let gender = Gender(rawValue: String(s)) else { return nil }
            tokens.append(.gender(gender))
        case (.gender, _):
            print("Encountered extra text: \(s)")
            return tokens

        // Verb path:
        case (.pos, .verb):
            guard let raw = Int(String(s)), let conjugation = Conjugation(rawValue: raw) else {
                return nil
            }
            tokens.append(.conjugation(conjugation))
        case (.conjugation, _):
            guard let variant = Int(String(s)) else { return nil }
            tokens.append(.variant(variant))
        case (.variant, .verb):
            guard let tense = Tense(rawValue: String(s)) else { return nil }
            tokens.append(.tense(tense))
        case (.tense, _):
            guard let voice = Voice(rawValue: String(s)) else { return nil }
            tokens.append(.voice(voice))
        case (.voice, _):
            guard let mood = Mood(rawValue: String(s)) else { return nil }
            tokens.append(.mood(mood))
        case (.mood, .verb):
            guard let raw = Int(String(s)), let person = Person(rawValue: raw) else { return nil }
            tokens.append(.person(person))
        case (.person, _):
            guard let number = Number(rawValue: String(s)) else { return nil }
            tokens.append(.number(number))
        case (.number, .verb):
            return tokens

        default:
            return nil
        }
    }

    return tokens
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
