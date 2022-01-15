//
//  ServiceProvider.swift
//  words (macOS)
//
//  Created by Dan Weiner on 10/23/21.
//

import AppKit

@objc
class ServiceProvider: NSObject {
    func lookUp(_ text: String, direction: Dictionary.Direction) {
        let frontmostWindow = NSApp.orderedWindows.first ?? {
            let newWindow = LookupWindowController.newController().window!

            if let keyWindow = NSApp.keyWindow {
                let newPoint = newWindow.cascadeTopLeft(from: keyWindow.topLeft)
                newWindow.setFrameTopLeftPoint(newPoint)
            } else {
                newWindow.center()
            }
            return newWindow
        }()

        NSApp.activate(ignoringOtherApps: true)

        guard let windowController = frontmostWindow.windowController as? LookupWindowController else {
            return
        }

        let query = SearchQuery(sanitized(query: text), direction)
        windowController.setSearchQuery(query, withAlternativeNavigation: false)
    }

    @objc
    func lookUp(_ pasteboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        func setError(localizedDescription: String) {
            let userInfo = [NSLocalizedDescriptionKey: localizedDescription]
            error?.pointee = NSError(domain: "org.danielweiner.org",
                                     code: 1,
                                     userInfo: userInfo)
        }

        guard let text = pasteboard.string(forType: .string) else {
            setError(localizedDescription: "Could not retrieve text from the pasteboard.")
            return
        }

        lookUp(text, direction: getDirection(fromUserData: userData))
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
