//
//  PerseusService.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/2/22.
//

import Foundation

enum PerseusUtils {
    static func urlForLookUpInPerseus(searchText text: String) -> URL? {
        wordForPerseusLookUp(inSearchText: text).flatMap(PerseusUtils.url(for:))
    }

    static func canLookUpInPerseus(searchText text: String) -> Bool {
        wordForPerseusLookUp(inSearchText: text) != nil
    }

    private static func wordForPerseusLookUp(inSearchText text: String) -> String? {
        return text.split(whereSeparator: \.isNewline).first.map(String.init(_:))
    }

    // http://www.perseus.tufts.edu/hopper/morph?l=viribus&la=la
    private static func url(for word: String) -> URL? {
        var components = URLComponents(string: "https://www.perseus.tufts.edu/hopper/morph?la=la")!
        components.queryItems!.append(.init(name: "l", value: word))
        return components.url
    }
}
