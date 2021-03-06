//
//  Utils.swift
//  iWordsTests
//
//  Created by Dan Weiner on 10/30/21.
//

import XCTest
import Difference

public func XCTAssertEqual<T: Equatable>(_ received: @autoclosure () throws -> T, _ expected: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do {
        let expected = try expected()
        let received = try received()
        XCTAssertTrue(expected == received, "Found difference for \n" + diff(expected, received).joined(separator: ", "), file: file, line: line)
    }
    catch {
        XCTFail("Caught error while testing: \(error)", file: file, line: line)
    }
}
