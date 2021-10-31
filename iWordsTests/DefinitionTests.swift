//
//  DefinitionTests.swift
//  Tests macOS
//
//  Created by Dan Weiner on 4/24/21.
//

import XCTest
@testable import iWords

class DefinitionTests: XCTestCase {
    func testNouns() {
        var example: String
        example = "vir                  N      2 3 NOM S M                 \n" +
        "vir                  N      2 3 VOC S M                 \n" +
        "vir, viri  N (2nd) M            \n" +
        "man; husband; hero; person of courage, honor, and nobility;"
        var expected = iWords.Definition(
            possibilities: [.noun(Noun(text: "vir", declension: .second, variety: 3, case: .nominative, number: .singular, gender: .masculine)),
                            .noun(Noun(text: "vir", declension: .second, variety: 3, case: .vocative, number: .singular, gender: .masculine))],
            words: [Word(
            expansion: iWords.Expansion.noun("vir, viri",
                                             iWords.Declension.second,
                                             iWords.Gender.masculine,
                                             []),
            meaning: "man; husband; hero; person of courage, honor, and nobility;")])
        XCTAssertEqual(parse(example)?.0, [expected])

        example = "vi.a                 N      1 1 NOM S F                 \n" +
        "vi.a                 N      1 1 VOC S F                 \n" +
        "vi.a                 N      1 1 ABL S F                 \n" +
        "via, viae  N (1st) F            \n" +
        "way, road, street; journey;"
        expected = iWords.Definition(
            possibilities: [.noun(Noun(text: "vi.a", declension: .first, variety: 1, case: .nominative, number: .singular, gender: .feminine)),
                            .noun(Noun(text: "vi.a", declension: .first, variety: 1, case: .vocative,   number: .singular, gender: .feminine)),
                            .noun(Noun(text: "vi.a", declension: .first, variety: 1, case: .ablative,   number: .singular, gender: .feminine))],
            words: [Word(expansion: iWords.Expansion.noun("via, viae",
                                             iWords.Declension.first,
                                             iWords.Gender.feminine,
                                             []),
                         meaning: "way, road, street; journey;")]);
        XCTAssertEqual(parse(example)?.0.first, expected)

        example = "res                  N      9 9 X   X N                 \n" +
        "res, undeclined  N N    Late  uncommon\n" +
        "res; (20th letter of Hebrew alphabet); (transliterate as R);\n" +
        "*\n"

        expected = iWords.Definition(
            possibilities: [.noun(Noun(text: "res", declension: nil, variety: 9, case: nil, number: nil, gender: .neuter))],
            words: [Word(expansion: .noun("res, undeclined", nil, .neuter, ["Late", "uncommon"]),
            meaning: "res; (20th letter of Hebrew alphabet); (transliterate as R);")])
        XCTAssertEqual(parse(example)?.0.first, expected)
    }

    func testAdjectives() {
        var example: String
        example = "cops                 ADJ    3 1 NOM S X POS             \n" +
        "cops                 ADJ    3 1 VOC S X POS             \n" +
        "cops                 ADJ    3 1 ACC S N POS             \n" +
        "cops, (gen.), copis  ADJ    uncommon\n" +
        "well/abundantly equipped/supplied; rich; swelling (of chest with pride);"
        var expected = iWords.Definition(
            possibilities: [.adjective(Adjective(text: "cops", declension: .third, variety: 1, case: .nominative, number: .singular, gender: nil,     degree: .positive)),
                            .adjective(Adjective(text: "cops", declension: .third, variety: 1, case: .vocative,   number: .singular, gender: nil,     degree: .positive)),
                            .adjective(Adjective(text: "cops", declension: .third, variety: 1, case: .accusative, number: .singular, gender: .neuter, degree: .positive))],
            words: [Word(expansion: .adj("cops, (gen.), copis", ["uncommon"]),
            meaning: "well/abundantly equipped/supplied; rich; swelling (of chest with pride);")])
        XCTAssertEqual(parse(example)?.0.first, expected)

        example = "ali.a                ADJ    1 5 NOM S F POS             \n" +
        "ali.a                ADJ    1 5 VOC S F POS             \n" +
        "ali.a                ADJ    1 5 ABL S F POS             \n" +
        "ali.a                ADJ    1 5 NOM P N POS             \n" +
        "ali.a                ADJ    1 5 VOC P N POS             \n" +
        "ali.a                ADJ    1 5 ACC P N POS             \n" +
        "alius, alia, aliud  ADJ  \n" +
        "other, another; different, changed; [alii...alii => some...others]; (A+G);"

        expected = iWords.Definition(
            possibilities: [.adjective(Adjective(text: "ali.a", declension: .first, variety: 5, case: .nominative, number: .singular, gender: .feminine, degree: .positive)),
                            .adjective(Adjective(text: "ali.a", declension: .first, variety: 5, case: .vocative, number: .singular, gender: .feminine, degree: .positive)),
                            .adjective(Adjective(text: "ali.a", declension: .first, variety: 5, case: .ablative, number: .singular, gender: .feminine, degree: .positive)),
                            .adjective(Adjective(text: "ali.a", declension: .first, variety: 5, case: .nominative, number: .plural, gender: .neuter, degree: .positive)),
                            .adjective(Adjective(text: "ali.a", declension: .first, variety: 5, case: .vocative, number: .plural, gender: .neuter, degree: .positive)),
                            .adjective(Adjective(text: "ali.a", declension: .first, variety: 5, case: .accusative, number: .plural, gender: .neuter, degree: .positive))],
            words: [Word(expansion: .adj("alius, alia, aliud", []),
            meaning: "other, another; different, changed; [alii...alii => some...others]; (A+G);")])
        XCTAssertEqual(parse(example)?.0.first, expected)

        example = "re.i                 ADJ    1 1 GEN S M POS             \n" +
        "reus, rea, reum  ADJ    Medieval  uncommon\n" +
        "liable to (penalty of); guilty; [mens rea => guilty mind (modern legal term)];"

        expected = iWords.Definition(
            possibilities: [.adjective(Adjective(text: "re.i", declension: .first, variety: 1, case: .genitive, number: .singular, gender: .masculine, degree: .positive))],
            words: [Word(expansion: .adj("reus, rea, reum", ["Medieval", "uncommon"]),
            meaning: "liable to (penalty of); guilty; [mens rea => guilty mind (modern legal term)];")])
        XCTAssertEqual(parse(example)?.0.first, expected)
    }

    func testAdverbs() {
        var example: String
        example = "alias                ADV    POS                         \n" +
        "alias  ADV  \n" +
        "at/in another time/place; previously, subsequently; elsewhere; otherwise;\n"
        var expected = iWords.Definition(
            possibilities: [.adverb(Adverb(text: "alias", degree: .positive))],
            words: [Word(expansion: .adv("alias", []),
            meaning: "at/in another time/place; previously, subsequently; elsewhere; otherwise;")])
        XCTAssertEqual(parse(example)?.0.first, expected)
    }

    func testVerbs() {
        var example: String
        example = "consul.ere           V      3 1 PRES ACTIVE  INF 0 X    \n" +
            "consul.ere           V      3 1 PRES PASSIVE IMP 2 S    \n" +
            "consul.ere           V      3 1 FUT  PASSIVE IND 2 S    \n" +
            "consulo, consulere, consului, consultus  V (3rd)            \n" +
            "ask information/advice of; consult, take counsel; deliberate/consider; advise;\n" +
            "decide upon, adopt; look after/out for (DAT), pay attention to; refer to;"
        XCTAssertEqual(
            parse(example)?.0.first,
            iWords.Definition(
                possibilities: [.verb(Verb(text: "consul.ere", conjugation: .third, variety: 1, tense: .present, voice: .active, mood: .infinitive, person: nil, number: nil)),
                                .verb(Verb(text: "consul.ere", conjugation: .third, variety: 1, tense: .present, voice: .passive, mood: .imperative, person: .second, number: .singular)),
                                .verb(Verb(text: "consul.ere", conjugation: .third, variety: 1, tense: .future, voice: .passive, mood: .indicative, person: .second, number: .singular))],
                words: [Word(expansion: iWords.Expansion.verb(
                    "consulo, consulere, consului, consultus",
                    iWords.Conjugation.third,
                    []),
                meaning: "ask information/advice of; consult, take counsel; deliberate/consider; advise;\ndecide upon, adopt; look after/out for (DAT), pay attention to; refer to;")])
        )

        example = "ven.i                N      2 2 GEN S N                 \n" +
        "ven.i                N      2 2 LOC S N                 \n" +
        "venum, veni  N (2nd) N  \n" +
        "sale, purchase; (only sg. ACC/DAT w/dare); [venum dare => put up for sale];\r\n" +
        "veni                 V      6 1 PRES ACTIVE  IMP 2 S    \n" +
        "veneo, venire, venivi(ii), venitus  V  \n" +
        "go for sale, be sold (as slave), be disposed of for (dishonorable/venal) gain;\r\n" +
        "ven.i                V      4 1 PRES ACTIVE  IMP 2 S    \n" +
        "ven.i                V      4 1 PERF ACTIVE  IND 1 S    \n" +
        "venio, venire, veni, ventus  V (4th)  \n" +
        "come;\r\n" +
        "*\n"

        XCTAssertEqual(
            parse(example)?.0,
            [
                iWords.Definition(
                    possibilities: [.noun(Noun(text: "ven.i", declension: .second, variety: 2, case: .genitive, number: .singular, gender: .neuter)),
                                    .noun(Noun(text: "ven.i", declension: .second, variety: 2, case: .locative, number: .singular, gender: .neuter))],
                    words: [Word(expansion: iWords.Expansion.noun(
                        "venum, veni",
                        .second,
                        .neuter,
                        []),
                    meaning: "sale, purchase; (only sg. ACC/DAT w/dare); [venum dare => put up for sale];")]),
                iWords.Definition(
                    possibilities: [.verb(Verb(text: "veni", conjugation: nil, variety: 1, tense: .present, voice: .active, mood: .imperative, person: .second, number: .singular)),],
                    words: [Word(expansion: iWords.Expansion.verb(
                        "veneo, venire, venivi(ii), venitus",
                        nil,
                        []),
                    meaning: "go for sale, be sold (as slave), be disposed of for (dishonorable/venal) gain;")]),
                iWords.Definition(
                    possibilities: [.verb(Verb(text: "ven.i", conjugation: .fourth, variety: 1, tense: .present, voice: .active, mood: .imperative, person: .second, number: .singular)),
                                    .verb(Verb(text: "ven.i", conjugation: .fourth, variety: 1, tense: .perfect, voice: .active, mood: .indicative, person: .first, number: .singular)),],
                    words: [Word(expansion: iWords.Expansion.verb(
                        "venio, venire, veni, ventus",
                        .fourth,
                        []),
                    meaning: "come;")])
            ]
        )

        example = "incub.at             V      1 1 PRES ACTIVE  IND 3 S    \n" +
        "incubo, incubare, incubavi, incubatus  V (1st) INTRANS    veryrare\n" +
        "brood; (rare alt. perf/vpar for incubo);\n" +
        "incubo, incubare, incubui, incubitus  V (1st)  \n" +
        "lie in or on (w/DAT); sit upon; brood over; keep a jealous watch (over);"
        XCTAssertEqual(parse(example)?.0, [
            iWords.Definition(possibilities: [.verb(Verb(text: "incub.at", conjugation: .first, variety: 1, tense: .present, voice: .active, mood: .indicative, person: .third, number: .singular))],
                              words: [Word(expansion: .verb("incubo, incubare, incubavi, incubatus", .first, ["intrans.", "very rare"]), meaning: "brood; (rare alt. perf/vpar for incubo);"),
                                      Word(expansion: .verb("incubo, incubare, incubui, incubitus", .first, []), meaning: "lie in or on (w/DAT); sit upon; brood over; keep a jealous watch (over);")]),
        ])

        example = String(data: NSDataAsset(name: "queries/orietur")!.data, encoding: .utf8)!
        XCTAssertEqual(parse(example)?.0, [
            iWords.Definition(possibilities: [.verb(Verb(text: "ori.etur", conjugation: .third, variety: 1, tense: .future, voice: nil, mood: .indicative, person: .third, number: .singular))],
                              words: [Word(expansion: .verb("orior, ori, oritus sum", .third, ["dep."]), meaning: "rise (sun/river); arise/emerge, crop up; get up (wake); begin; originate from;\nbe born/created; be born of, descend/spring from; proceed/be derived (from);")]),
            iWords.Definition(possibilities: [.verb(Verb(text: "ori.etur", conjugation: .fourth, variety: 1, tense: .future, voice: nil, mood: .indicative, person: .third, number: .singular))],
                              words: [Word(expansion: .verb("orior, oriri, ortus sum", .fourth, ["dep."]), meaning: "rise (sun/river); arise/emerge, crop up; get up (wake); begin; originate from;\nbe born/created; be born of, descend/spring from; proceed/be derived (from);")])
        ])
    }

    func testPronouns() {
        var example = String(data: NSDataAsset(name: "queries/ego")!.data, encoding: .utf8)!
        XCTAssertEqual(parse(example)?.0, [
            iWords.Definition(possibilities: [.pronoun(Pronoun(text: "ego", declension: .fifth, variety: 1, case: .nominative, number: .singular, gender: .common))],
                              words: [Word(expansion: nil, meaning: "I, me (PERS); myself (REFLEX);")])
        ])

        example = String(data: NSDataAsset(name: "queries/ille")!.data, encoding: .utf8)!
        XCTAssertEqual(parse(example)?.0, [
            iWords.Definition(possibilities: [.pronoun(Pronoun(text: "ill.e", declension: nil, variety: 1, case: .nominative, number: .singular, gender: .masculine))],
                              words: [Word(expansion: .pron("ille, illa, illud", []),
                                           meaning: "that; those (pl.); also DEMONST; that person/thing; the well known; the former;")])
        ])
    }

    func testPrepositions() {
        var example = String(data: NSDataAsset(name: "queries/ab")!.data, encoding: .utf8)!
        XCTAssertEqual(parse(example)?.0, [
            iWords.Definition(possibilities: [.preposition(Preposition(text: "ab", case: .ablative))],
                              words: [Word(expansion: .prep("ab", .ablative, []),
                                           meaning: "by (agent), from (departure, cause, remote origin/time); after (reference);")])
        ])
    }

    func testCombined() {
        testQueryExpectedAssetPair(asset: "facile")
        testQueryExpectedAssetPair(asset: "prae")
    }

    private func testQueryExpectedAssetPair(asset name: String) {
        let raw = String(data: NSDataAsset(name: "queries/\(name)")!.data, encoding: .utf8)!
        let expected = try! JSONDecoder().decode([Definition].self, from: NSDataAsset(name: "expected/\(name)")!.data)
        XCTAssertNotNil(raw)
        XCTAssertNotNil(expected)
        XCTAssertEqual(parse(raw)?.0, expected)
    }
}
