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

