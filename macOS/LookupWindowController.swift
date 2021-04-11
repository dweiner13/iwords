//
//  LookupWindowController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa
import Combine

extension UserDefaults {
    var dictionaryOptions: Dictionary.Options {
        var options = Dictionary.Options()
        if bool(forKey: "diagnosticMode") {
            options.insert(.diagnosticMode)
        }
        return options
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let backForwardMenuFormBackItem =
        NSUserInterfaceItemIdentifier("backForwardMenuFormBackItem")
    static let backForwardMenuFormForwardItem =
        NSUserInterfaceItemIdentifier("backForwardMenuFormForwardItem")
}

/// This class is functionally the singleton controller for the whole application.
class LookupWindowController: NSWindowController, NSMenuItemValidation {



    static var shared: LookupWindowController!

    var history: [String] = []
    private var backList: [String] = []
    private var forwardList: [String] = []
    private var lastSearchTerm: String?

    private var backForwaredMenu: NSMenu!
    private var directionMenu: NSMenu!

    @IBOutlet weak var backForwardToolbarItem: NSToolbarItem!
    @IBOutlet weak var backForwardControl: NSSegmentedControl!
    @IBOutlet weak var directionItem: NSToolbarItem!
    @IBOutlet weak var popUpButton: NSPopUpButton!
    @IBOutlet weak var searchField: NSSearchField!

    private var direction: Dictionary.Direction {
        let raw = UserDefaults.standard.integer(forKey: "translationDirection")
        return Dictionary.Direction(rawValue: raw)!
    }

    private var lookupViewController: LookupViewController! {
        contentViewController as? LookupViewController
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        guard Self.shared == nil else {
            fatalError()
        }

        Self.shared = self

        searchField.becomeFirstResponder()

        updateBackForwardButtons()
        var backForwardMenuItem = NSMenuItem(title: "Back/Forward", action: nil, keyEquivalent: "")
        let backForwardSubmenu = NSMenu()
        let backItem = NSMenuItem(title: "Back",    action: #selector(goBack(_:)),    keyEquivalent: "")
        backItem.identifier = .backForwardMenuFormBackItem
        backForwardSubmenu.addItem(backItem)
        let forwardItem = NSMenuItem(title: "Forward", action: #selector(goForward(_:)), keyEquivalent: "")
        forwardItem.identifier = .backForwardMenuFormForwardItem
        backForwardSubmenu.addItem(forwardItem)
        backForwaredMenu = backForwardSubmenu
        backForwaredMenu.autoenablesItems = true
        backForwardMenuItem.submenu = backForwardSubmenu
        backForwardToolbarItem.menuFormRepresentation = backForwardMenuItem

        var directionMenuItem = NSMenuItem(title: "Direction", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let lToEItem = NSMenuItem(title: "Latin to English", action: #selector(setLatinToEnglish), keyEquivalent: "")
        lToEItem.state = .on
        submenu.addItem(lToEItem)
        let eToLItem = NSMenuItem(title: "English to Latin", action: #selector(setEnglishToLatin), keyEquivalent: "")
        eToLItem.state = .off
        submenu.addItem(eToLItem)
        directionMenu = submenu
        directionMenuItem.submenu = submenu
        directionItem.menuFormRepresentation = directionMenuItem

        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.translationDirection", options: .new, context: nil)

        NotificationCenter.default
            .publisher(for: .goBack)
            .sink(receiveValue: goBack(_:))
            .store(in: &cancellables)
        NotificationCenter.default
            .publisher(for: .goForward)
            .sink(receiveValue: goForward(_:))
            .store(in: &cancellables)
    }

    var cancellables: [AnyCancellable] = []

    public func setSearchText(_ searchText: String) {
        guard !searchText.isEmpty, searchText != lastSearchTerm else {
            return
        }
        searchField.stringValue = searchText

        if let lastSearchTerm = lastSearchTerm {
            backList.append(lastSearchTerm)
            forwardList = []
        }
        search(searchText)
        history.append(searchText)
        lastSearchTerm = searchText

        updateBackForwardButtons()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let new = UserDefaults.standard.integer(forKey: "translationDirection")
        directionMenu?.items[0].state = new == 0 ? .on : .off
        directionMenu?.items[1].state = new == 1 ? .on : .off
    }

    @objc
    private func setLatinToEnglish() {
        UserDefaults.standard.setValue(Dictionary.Direction.latinToEnglish.rawValue, forKey: "translationDirection")
    }

    @objc
    private func setEnglishToLatin() {
        UserDefaults.standard.setValue(Dictionary.Direction.englishToLatin.rawValue, forKey: "translationDirection")
    }

    @IBAction
    private func searchFieldAction(_ field: NSSearchField) {
        setSearchText(field.stringValue)
    }

    private func search(_ searchText: String) {
        do {
            let results = try Dictionary.shared.getDefinition(
                searchText,
                direction: direction,
                options: UserDefaults.standard.dictionaryOptions
            )
            lookupViewController.setResultText(results ?? "No results found")
        } catch {
            self.presentError(error)
        }
    }

    @IBAction func backForwardControlPressed(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:  goBack()
        case 1:  goForward()
        default: return
        }
    }

    @objc
    private func goBack(_ sender: Any? = nil) {
        if let lastSearchTerm = lastSearchTerm {
            forwardList.append(lastSearchTerm)
        }
        if let backSearchTerm = backList.popLast() {
            search(backSearchTerm)
            searchField.stringValue = backSearchTerm
            lastSearchTerm = backSearchTerm
        }

        updateBackForwardButtons()
    }

    @objc
    private func goForward(_ sender: Any? = nil) {
        if let lastSearchTerm = lastSearchTerm {
            backList.append(lastSearchTerm)
        }
        if let forwardSearchTerm = forwardList.popLast() {
            search(forwardSearchTerm)
            searchField.stringValue = forwardSearchTerm
            lastSearchTerm = forwardSearchTerm
        }

        updateBackForwardButtons()
    }

    var canGoBack: Bool {
        !backList.isEmpty
    }

    var canGoForward: Bool {
        !forwardList.isEmpty
    }

    public func updateBackForwardButtons() {
        backForwardControl.setEnabled(canGoBack,    forSegment: 0)
        backForwardControl.setEnabled(canGoForward, forSegment: 1)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.identifier {
        case NSUserInterfaceItemIdentifier.backForwardMenuFormBackItem:
            return canGoBack
        case NSUserInterfaceItemIdentifier.backForwardMenuFormForwardItem:
            return canGoForward
        default:
            return true
        }
    }
}
