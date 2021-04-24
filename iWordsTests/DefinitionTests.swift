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
        var input: String;
        var expected: [Token<String>];
        input = "vi.a                 N      1 1 NOM S F"
        expected = [
            .root("vi"), .ending("a"), .pos(.noun), .declension(.first), .variant(1), .case(.nominative), .number(.singular), .gender(.feminine)
        ]
        XCTAssertEqual(parse(line: input), expected)

        input = "testamentari.um      N      2 1 GEN P M                   uncommon"
        expected = [
            .root("testamentari"), .ending("um"), .pos(.noun), .declension(.second), .variant(1), .case(.genitive), .number(.plural), .gender(.masculine)
        ]
        XCTAssertEqual(parse(line: input), expected)
    }

    func testExampleVerbs() throws {
        var input: String;
        var expected: [Token<String>];
        input = "consul.ere           V      3 1 PRES ACTIVE  INF 0 X"
        expected = [
            .root("consul"), .ending("ere"), .pos(.verb), .conjugation(.third), .variant(1), .tense(.present), .voice(.active), .mood(.infinitive), .person(.none), .number(.invalid)
        ]
        XCTAssertEqual(parse(line: input), expected)
    }

}
