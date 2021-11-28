//
//  String+.swift
//  iWordsTests
//
//  Created by Dan Weiner on 10/31/21.
//

import Foundation

extension StringProtocol {
    func ifNotEmptyAfterTrimmingCharactersIn(_ set: CharacterSet) -> String? {
        let trimmed = self.trimmingCharacters(in: set)
        return trimmed.isEmpty ? nil : trimmed
    }
}
