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
    }

    let possibilities: [DeclinedNoun]
    let expansion: Expansion
    let definition: String
}

class RangeParser {
    let string: String

    private func errorParsing<T>(type: T, start: Int, length: Int) -> DWError {
        var msg = """
        Failed to parse type \(T.self) from substring:
        \(string)
        """
        msg += "\n"
        msg += String(repeating: " ", count: start)
        msg += "^"
        msg += String(repeating: "-", count: max(0, length - 2))
        if length > 1 {
            msg += "^"
        }
        return DWError(description: msg)
    }

    init(_ string: String) {
        self.string = string
    }

    func parse<T: LosslessStringConvertible>(from: Int, length: Int) throws -> T {
        let start = string.index(string.startIndex, offsetBy: from)
        let end = string.index(start, offsetBy: length)
        let substr = string[start..<end]
        guard let t = T(String(substr).trimmingCharacters(in: .whitespaces)) else {
            throw errorParsing(type: T.self, start: from, length: length)
        }
        return t
    }

    func parse<T: RawRepresentable>(from: Int, length: Int) throws -> T where T.RawValue == String {
        let start = string.index(string.startIndex, offsetBy: from)
        let end = string.index(start, offsetBy: length)
        let substr = string[start..<end]
        guard let t = T(rawValue: String(substr).trimmingCharacters(in: .whitespaces)) else {
            throw errorParsing(type: T.self, start: from, length: length)
        }
        return t
    }

    func parse<T: RawRepresentable>(from: Int, length: Int) throws -> T where T.RawValue == Int {
        let start = string.index(string.startIndex, offsetBy: from)
        let end = string.index(start, offsetBy: length)
        let substr = string[start..<end]
        guard let raw = Int(String(substr).trimmingCharacters(in: .whitespaces)), let t = T(rawValue: raw) else {
            throw errorParsing(type: T.self, start: from, length: length)
        }
        return t
    }
}

protocol RangeParseable {
    init(parser: RangeParser) throws
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
    let ending: String?
    let pos: PartOfSpeech = .noun

    let declension: Declension
    let variant: Int
    let `case`: Case
    let number: Number
    let gender: Gender
}

func parse(line: String) -> DeclinedNoun {
    let parser = RangeParser(line)
    do {
        return try DeclinedNoun(parser: parser)
    } catch {
        fatalError(error.localizedDescription)
    }
}

extension DeclinedNoun: RangeParseable {
    init(parser: RangeParser) throws {
        let rootAndEnding: String = try parser.parse(from: 0, length: 21)
        let rootAndEndingSplit = rootAndEnding.split(separator: ".")
        root = String(rootAndEndingSplit[0])
        if rootAndEndingSplit.count >= 1 {
            ending = String(rootAndEndingSplit[1])
        } else {
            ending = nil
        }

        declension = try parser.parse(from: 28, length: 1)
        variant = try parser.parse(from: 30, length: 1)
        `case` = try parser.parse(from: 32, length: 3)
        number = try parser.parse(from: 36, length: 1)
        gender = try parser.parse(from: 38, length: 1)
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
}

