//
//  PerseusService.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/2/22.
//

import Foundation

enum PerseusUtils {
    static func urlsForLookUpInPerseus(searchText text: String) -> [URL] {
        text.split(whereSeparator: \.isWhitespace).compactMap(PerseusUtils.url(for:))
    }

    static func canLookUpInPerseus(searchText text: String) -> Bool {
        text.split(whereSeparator: \.isWhitespace).count > 0
    }

    // http://www.perseus.tufts.edu/hopper/morph?l=viribus&la=la
    private static func url<S: StringProtocol>(for word: S) -> URL? {
        var components = URLComponents(string: "https://www.perseus.tufts.edu/hopper/morph?la=la")!
        components.queryItems!.append(.init(name: "l", value: String(word)))
        return components.url
    }
}
