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

protocol Word {}

struct Noun: Word {
    struct Expansion {
        var principalParts: String
        var declension: Declension
        var gender: Gender // TODO: handle "Uncommon" here and for DeclinedNoun

        init?(line: Line) {
            
        }
    }

    let possibilities: [DeclinedNoun]
    let expansion: Expansion
    let definition: String

    init?(_ lines: [String]) {
        for line in lines {
            if let DeclinedNoun =
        }
    }
}

struct DeclinedNoun: Equatable {
    internal init(root: String, ending: String, declension: Declension, variant: Int, case: Case, number: Number, gender: Gender) {
        self.root = root
        self.ending = ending
        self.declension = declension
        self.variant = variant
        self.case = `case`
        self.number = number
        self.gender = gender
    }

    let root: String
    let ending: String
    let pos: PartOfSpeech = .noun

    let declension: Declension
    let variant: Int
    let `case`: Case
    let number: Number
    let gender: Gender

    init?(_ partial: PartialWord) {
        guard partial.pos == .noun,
              let root       = partial.root,
              let ending     = partial.ending,
              let declension = partial.declension,
              let variant    = partial.variant,
              let `case`     = partial.case,
              let number     = partial.number,
              let gender     = partial.gender else {
            return nil
        }
        self.root = root
        self.ending = ending
        self.declension = declension
        self.variant = variant
        self.case = `case`
        self.number = number
        self.gender = gender
    }
}


struct ConjugatedVerb: Equatable {
    internal init(root: String, ending: String, conjugation: Conjugation, variant: Int, tense: Tense, voice: Voice, mood: Mood, person: Person, number: Number) {
        self.root = root
        self.ending = ending
        self.conjugation = conjugation
        self.variant = variant
        self.tense = tense
        self.voice = voice
        self.mood = mood
        self.person = person
        self.number = number
    }

    let root: String
    let ending: String
    let pos: PartOfSpeech = .verb

    let conjugation: Conjugation
    let variant: Int
    let tense: Tense
    let voice: Voice
    let mood: Mood
    let person: Person
    let number: Number

    init?(_ partial: PartialWord) {
        guard partial.pos == .verb,
              let root        = partial.root,
              let ending      = partial.ending,
              let conjugation = partial.conjugation,
              let variant     = partial.variant,
              let tense       = partial.tense,
              let voice       = partial.voice,
              let mood        = partial.mood,
              let person      = partial.person,
              let number      = partial.number else {
            return nil
        }
        self.root = root
        self.ending = ending
        self.conjugation = conjugation
        self.variant = variant
        self.tense = tense
        self.voice = voice
        self.mood = mood
        self.person = person
        self.number = number
    }
}

struct PartialWord {
    var root: String?
    var ending: String?
    var pos: PartOfSpeech?

    var declension: Declension?
    var variant: Int?
    var `case`: Case?
    var number: Number?
    var gender: Gender?

    var conjugation: Conjugation?
    var tense: Tense?
    var voice: Voice?
    var mood: Mood?
    var person: Person?

    init() {}
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

func _parse(line: String) -> PartialWord? {
    let split = line.split(whereSeparator: { $0.isWhitespace || $0 == "." })
    var tokens: [Token] = []

    var linePOS: PartOfSpeech?
    
    loop: for s in split {
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
            break

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
            break loop

        default:
            return nil
        }
    }

    var partial = PartialWord()
    for token in tokens {
        switch token {
        case .case(let `case`): partial.case = `case`
        case .conjugation(let conjugation): partial.conjugation = conjugation
        case .declension(let declension): partial.declension = declension
        case .ending(let ending): partial.ending = String(ending)
        case .gender(let gender): partial.gender = gender
        case .mood(let mood): partial.mood = mood
        case .number(let number): partial.number = number
        case .person(let person): partial.person = person
        case .pos(let pos): partial.pos = pos
        case .root(let root): partial.root = String(root)
        case .tense(let tense): partial.tense = tense
        case .variant(let variant): partial.variant = variant
        case .voice(let voice): partial.voice = voice
        }
    }

    return partial
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
