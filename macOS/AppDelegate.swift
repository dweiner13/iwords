//
//  AppDelegate.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa

extension Notification.Name {
    static let focusSearch = Notification.Name("focusSearch")
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var shared: AppDelegate!

    @IBOutlet weak var backItem: NSMenuItem!
    @IBOutlet weak var forwardItem: NSMenuItem!

    func keyWindowController() -> LookupWindowController {
        NSApp.keyWindow?.windowController as! LookupWindowController
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard Self.shared == nil else {
            fatalError()
        }
        Self.shared = self
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

    @IBAction func focusSearch(_ sender: Any) {
        NotificationCenter.default.post(name: .focusSearch, object: nil)
    }

    @IBAction func setLatinToEnglish(_ sender: Any) {
        UserDefaults.standard.setValue(Dictionary.Direction.latinToEnglish.rawValue,
                                       forKey: "translationDirection")
    }

    @IBAction func setEnglishToLatin(_ sender: Any) {
        UserDefaults.standard.setValue(Dictionary.Direction.englishToLatin.rawValue,
                                       forKey: "translationDirection")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

extension AppDelegate: HistoryDelegate {
    func historyController(_ historyController: HistoryController,
                           didSelectHistoryItem query: SearchQuery) {
        AppDelegate.shared.keyWindowController().setSearchQuery(query)
    }
}
