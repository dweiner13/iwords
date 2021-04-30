//
//  DefinitionTests.swift
//  Tests macOS
//
//  Created by Dan Weiner on 4/24/21.
//

import XCTest
@testable import iWords

class DefinitionTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNouns() {
        var example: String
        example = "vir                  N      2 3 NOM S M                 \n" +
        "vir                  N      2 3 VOC S M                 \n" +
        "vir, viri  N (2nd) M   [XXXAX]  \n" +
        "man; husband; hero; person of courage, honor, and nobility;"
        XCTAssertEqual(
            parse(example),
            iWords.Definition(
                possibilities: ["vir                  N      2 3 NOM S M                 ",
                                "vir                  N      2 3 VOC S M                 "],
                expansion: iWords.Expansion.noun("vir, viri",
                                            iWords.Declension.second,
                                            iWords.Gender.masculine),
                meaning: "man; husband; hero; person of courage, honor, and nobility;")
        )
        example = "vi.a                 N      1 1 NOM S F                 \n" +
        "vi.a                 N      1 1 VOC S F                 \n" +
        "vi.a                 N      1 1 ABL S F                 \n" +
        "via, viae  N (1st) F   [XXXAX]  \n" +
        "way, road, street; journey;"
        XCTAssertEqual(
            parse(example),
            iWords.Definition(
                possibilities: ["vi.a                 N      1 1 NOM S F                 ",
                                "vi.a                 N      1 1 VOC S F                 ",
                                "vi.a                 N      1 1 ABL S F                 "],
                expansion: iWords.Expansion.noun("via, viae",
                                            iWords.Declension.first,
                                            iWords.Gender.feminine),
                meaning: "way, road, street; journey;")
        )
        // Why dopes this not work
        example = "copi.a               N      1 1 NOM S F                 \n" +
        "copi.a               N      1 1 VOC S F                 \n" +
        "copi.a               N      1 1 ABL S F                 \n" +
        "copia, copiae  N (1st) F   [XXXAO]  \n" +
        "plenty, abundance, supply; troops (pl.), supplies; forces; resources; wealth;\n" +
        "number/amount/quantity; sum/whole amount; means, opportunity; access/admission;"
        XCTAssertEqual(
            parse(example),
            iWords.Definition(possibilities: ["copi.a               N      1 1 NOM S F                 ", "copi.a               N      1 1 VOC S F                 ", "copi.a               N      1 1 ABL S F                 "], expansion: iWords.Expansion.noun("copia, copiae", .first, .feminine), meaning: "plenty, abundance, supply; troops (pl.), supplies; forces; resources; wealth; number/amount/quantity; sum/whole amount; means, opportunity; access/admission;")
        )
    }
    
    func testVerbs() {
        var example: String
        example = "consul.ere           V      3 1 PRES ACTIVE  INF 0 X    \n" +
            "consul.ere           V      3 1 PRES PASSIVE IMP 2 S    \n" +
            "consul.ere           V      3 1 FUT  PASSIVE IND 2 S    \n" +
            "consulo, consulere, consului, consultus  V (3rd)   [XXXAO]  \n" +
            "ask information/advice of; consult, take counsel; deliberate/consider; advise;\n" +
            "decide upon, adopt; look after/out for (DAT), pay attention to; refer to;" +
            "*"
        XCTAssertEqual(
            parse(example),
            iWords.Definition(
                possibilities: ["consul.ere           V      3 1 PRES ACTIVE  INF 0 X    ", 
                                "consul.ere           V      3 1 PRES PASSIVE IMP 2 S    ",
                                "consul.ere           V      3 1 FUT  PASSIVE IND 2 S    "], 
                expansion: iWords.Expansion.verb(
                    "consulo, consulere, consului, consultus", 
                    iWords.Conjugation.third), 
                meaning: "ask information/advice of; consult, take counsel; deliberate/consider; advise; decide upon, adopt; look after/out for (DAT), pay attention to; refer to;*",
                truncated: true)
        )
    }
}
