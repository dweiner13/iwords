//
//  ServiceProvider.swift
//  words (macOS)
//
//  Created by Dan Weiner on 10/23/21.
//

import AppKit

@objc
@MainActor
class ServiceProvider: NSObject {
    @discardableResult
    func lookUp(_ text: String, direction: Dictionary.Direction) -> Bool {
        let windowController = NSApp.orderedWindows
            .compactMap { $0.windowController as? LookupWindowController }
            .first ?? LookupWindowController.newController()

        guard let window = windowController.window else { return false }
        if !window.isVisible {
            window.center()
        }

        let query = SearchQuery(sanitized(query: text), direction)
        windowController.setSearchQuery(query, withAlternativeNavigation: false)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    @objc
    func lookUp(_ pasteboard: NSPasteboard, userData: String,
                error: AutoreleasingUnsafeMutablePointer<NSString?>?) {
        guard let text = pasteboard.string(forType: .string) else {
            error?.pointee = "Could not retrieve text from the pasteboard."
            return
        }

        guard !sanitized(query: text).isEmpty else {
            error?.pointee = "Please select a word to look up."
            return
        }

        if !lookUp(text, direction: getDirection(fromUserData: userData)) {
            error?.pointee = "Could not open a lookup window."
        }
    }

    func getDirection(fromUserData userData: String) -> Dictionary.Direction {
        Int(userData).flatMap(Dictionary.Direction.init(rawValue:)) ?? .latinToEnglish
    }

    func sanitized(query: String) -> String {
        var result = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Replace newlines with spaces
        while let range = result.rangeOfCharacter(from: .newlines) {
            result.replaceSubrange(range, with: " ")
        }
        return result
    }
}
