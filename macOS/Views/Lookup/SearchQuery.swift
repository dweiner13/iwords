//
//  SearchQuery.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 5/7/22.
//

import Foundation

@objc
class SearchQuery: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool {
        true
    }

    let searchText: String
    let direction: Dictionary.Direction

    override var debugDescription: String {
        "<\"\(searchText)\" (\(direction.debugDescription))>"
    }

    override var description: String {
        "\(searchText) (\(direction))"
    }

    func propertyListRepresentation() -> Any {
        ["searchText": searchText, "direction": direction.rawValue]
    }

    func displaySearchText() -> String {
        if searchText.count > 100 {
            return searchText.prefix(100).appending("…")
        } else {
            return searchText
        }
    }

    init?(fromPropertyListRepresentation obj: Any) {
        guard let obj = obj as? [String: Any] else {
            return nil
        }
        guard let searchText = obj["searchText"] as? String,
              let rawDirection = obj["direction"] as? Int,
              let direction = Dictionary.Direction(rawValue: rawDirection) else {
                  return nil
              }
        self.searchText = searchText
        self.direction = direction
    }

    required init?(coder: NSCoder) {
        guard let searchText = coder.decodeObject(of: NSString.self, forKey: "searchText") as String? else {
            return nil
        }
        self.searchText = searchText
        guard let direction = Dictionary.Direction(rawValue: coder.decodeInteger(forKey: "direction")) else {
            return nil
        }
        self.direction = direction
        super.init()
    }

    init(_ searchText: String, _ direction: Dictionary.Direction) {
        self.searchText = searchText
        self.direction = direction
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? SearchQuery else { return false }
        return searchText == object.searchText &&
        direction == object.direction
    }

    func encode(with coder: NSCoder) {
        coder.encode(searchText, forKey: "searchText")
        coder.encode(direction.rawValue, forKey: "direction")
    }

    func withDirection(_ direction: Dictionary.Direction) -> SearchQuery {
        SearchQuery(searchText, direction)
    }
}
