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
    static let focusSearch = Notification.Name("focusSearch")
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
        registerDefaults()

        #if DEBUG
        startListeningToUserDefaults()

        UserDefaults.standard.setValue(1, forKey: "diagnosticMode")
        #endif
    }

    #if DEBUG
    private func startListeningToUserDefaults() {
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.diagnosticMode", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "values.diagnosticMode" else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        print(UserDefaults.standard.dictionaryRepresentation())
    }
    #endif

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "diagnosticMode": false,
            "direction": 0
        ])
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

    @IBAction func focusSearch(_ sender: Any) {
        NotificationCenter.default.post(name: .focusSearch, object: nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.identifier?.rawValue == "history" else {
            return
        }

        let items = [.separator()] + LookupWindowController.shared.history
            .reversed()
            .enumerated()
            .map { tuple -> NSMenuItem in
                let (i, query) = tuple
                let item = NSMenuItem(title: query.searchText,
                                      action: #selector(historyMenuItemSelected(_:)),
                                      keyEquivalent: "")
                item.tag = i
                return item
            }

        menu.items.replaceSubrange(2..., with: items)
    }

    @IBAction func historyMenuItemSelected(_ sender: NSMenuItem) {
        let historyItemIndex = sender.tag
        let history = LookupWindowController.shared.history.reversed()[historyItemIndex]
        LookupWindowController.shared.setSearchQuery(history)
    }

    @IBAction func clearDefaults(_ sender: Any) {
        UserDefaults.resetStandardUserDefaults()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
