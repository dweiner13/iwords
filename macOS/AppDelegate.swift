//
//  AppDelegate.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa

extension Notification.Name {
    static let goBack = Notification.Name("goBack")
    static let goForward = Notification.Name("goForward")
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSMenuDelegate {
    static var shared: AppDelegate!

    @IBOutlet weak var backItem: NSMenuItem!
    @IBOutlet weak var forwardItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard Self.shared == nil else {
            fatalError()
        }
        Self.shared = self
        LookupWindowController.shared.updateBackForwardButtons()
    }

    @objc
    var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.identifier?.rawValue {
        case "back":
            return LookupWindowController.shared.canGoBack
        case "forward":
            return LookupWindowController.shared.canGoForward
        default:
            return true
        }
    }

    @IBAction func goBack(_ sender: Any) {
        NotificationCenter.default.post(name: .goBack, object: nil)
    }

    @IBAction func goForward(_ sender: Any) {
        NotificationCenter.default.post(name: .goForward, object: nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.identifier?.rawValue == "history" else {
            return
        }

        let items = [.separator()] + LookupWindowController.shared.history.reversed().map {
            NSMenuItem(title: $0,
                       action: #selector(historyMenuItemSelected(_:)),
                       keyEquivalent: "")
        }

        menu.items.replaceSubrange(2..., with: items)
    }

    @IBAction func historyMenuItemSelected(_ sender: NSMenuItem) {
        let historyItem = sender.title
        LookupWindowController.shared.setSearchText(historyItem)
    }
}
