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
        var example = "vi.a                 N      1 1 NOM S F"
        XCTAssertEqual(parse(line: example), DeclinedNoun(root: "vi", ending: "a", declension: .first, variant: 1, case: .nominative, number: .singular, gender: .feminine))
    }
}
