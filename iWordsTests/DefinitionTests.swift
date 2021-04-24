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

    func test() {
        var example: String
        example = "via, viae  N (1st) F   [XXXAX]  "
        XCTAssertEqual(expansion.parse(example), iWords.Expansion(principleParts: "via, viae", pos: iWords.PartOfSpeech.noun, declension: iWords.Declension.first, gender: iWords.Gender.feminine))

        example = "vir, viri  N (2nd) M   [XXXAX]  "
        XCTAssertEqual(
            expansion.parse(example),
            iWords.Expansion(
                principleParts: "vir, viri",
                pos: iWords.PartOfSpeech.noun,
                declension: iWords.Declension.second,
                gender: iWords.Gender.masculine
            )
        )

        example = """
        vir                  N      2 3 NOM S M
        vir                  N      2 3 VOC S M
        vir, viri  N (2nd) M   [XXXAX]
        man; husband; hero; person of courage, honor, and nobility;
        """
        XCTFail("\(result.parse(example))")
    }
}
