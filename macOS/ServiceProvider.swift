//
//  ServiceProvider.swift
//  words (macOS)
//
//  Created by Dan Weiner on 10/23/21.
//

import AppKit

@objc
class ServiceProvider: NSObject {
    @objc
    func lookUp(_ pasteboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        func setError(localizedDescription: String) {
            let userInfo = [NSLocalizedDescriptionKey: localizedDescription]
            error?.pointee = NSError(domain: "org.danielweiner.org",
                                     code: 1,
                                     userInfo: userInfo)
        }

        guard let string = pasteboard.string(forType: .string) else {
            setError(localizedDescription: "Could not retrieve text from the pasteboard.")
            return
        }

        let frontmostWindow = NSApp.orderedWindows.first ?? {
            let newWindow = LookupWindowController.newWindow()

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
            setError(localizedDescription: "Could not find a window to display results in.")
            return
        }

        let query = SearchQuery(sanitized(query: string), getDirection(fromUserData: userData))
        windowController.setSearchQuery(query)
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
