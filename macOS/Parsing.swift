//
//  Parsing.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 4/24/21.
//

import Foundation
import Parsing

private func isNotDot(_ c: UTF8.CodeUnit) -> Bool {
    c != .init(ascii: ".")
}

private func isNotSpace(_ c: UTF8.CodeUnit) -> Bool {
    c != .init(ascii: " ")
}

func parse() -> DeclinedNoun? {
    let example = "vi.a                 N      1 1 NOM S F"
    let declinedNoun = PrefixUpTo(
        .skip(StartsWith<Substring>(".").orElse(Whitespace<Substring>()))
}
