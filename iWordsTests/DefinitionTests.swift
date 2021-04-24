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

    func testExampleNouns() throws {
        func test(_ input: String, _ output: DeclinedNoun) {
            guard let word = _parse(line: input) else {
                XCTFail()
                return
            }
            XCTAssertEqual(DeclinedNoun(word), output)
        }

        var input: String;
        input = "vi.a                 N      1 1 NOM S F"
        test(input, DeclinedNoun(root: "vi", ending: "a", declension: .first, variant: 1, case: .nominative, number: .singular, gender: .feminine))

        input = "testamentari.um      N      2 1 GEN P M                   uncommon"
        test(input, DeclinedNoun(root: "testamentari", ending: "um", declension: .second, variant: 1, case: .genitive, number: .plural, gender: .masculine))
    }

    func testExampleVerbs() throws {
        func test(_ input: String, _ output: ConjugatedVerb) {
            guard let word = _parse(line: input) else {
                XCTFail()
                return
            }
            XCTAssertEqual(ConjugatedVerb(word), output)
        }
        var input: String;
        input = "consul.ere           V      3 1 PRES ACTIVE  INF 0 X"
        test(input, ConjugatedVerb(root: "consul", ending: "ere", conjugation: .third, variant: 1, tense: .present, voice: .active, mood: .infinitive, person: .none, number: .invalid))
    }

}
