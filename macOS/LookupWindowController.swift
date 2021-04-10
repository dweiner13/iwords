//
//  LookupWindowController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa

class LookupWindowController: NSWindowController {

    private var backList: [String] = []
    private var forwardList: [String] = []
    private var lastSearchTerm: String?

    private var directionMenu: NSMenu?

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

        searchField.becomeFirstResponder()

        updateBackForwardButtons()
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
        let searchText = field.stringValue
        guard !searchText.isEmpty, searchText != lastSearchTerm else {
            return
        }

        if let lastSearchTerm = lastSearchTerm {
            backList.append(lastSearchTerm)
            forwardList = []
        }
        search(searchText)
        lastSearchTerm = searchText

        updateBackForwardButtons()
    }

    private func search(_ searchText: String) {
        do {
            let results = try Dictionary.shared.getDefinition(searchText, direction: direction)
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
    private func goBack() {
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
    private func goForward() {
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

    private func updateBackForwardButtons() {
        print("backList: \(backList)")
        print("lastSearchTerm: \(lastSearchTerm)")
        print("forwardList: \(forwardList)")
        backForwardControl.setEnabled(!backList.isEmpty, forSegment: 0)
        backForwardControl.setEnabled(!forwardList.isEmpty, forSegment: 1)

//        let backMenu = NSMenu(title: "Back")
//        backMenu.items = backList
//            .enumerated()
//            .map { tuple -> NSMenuItem in
//                let (i, searchText) = tuple
//                let item = NSMenuItem(title: searchText, action: #selector(didPressBackMenuItem(_:)), keyEquivalent: "")
//                item.tag = i
//                return item
//            }
//        backForwardControl.setMenu(backMenu, forSegment: 0)
//
//        let forwardMenu = NSMenu(title: "Forward")
//        forwardMenu.items = forwardList
//            .enumerated()
//            .map { tuple -> NSMenuItem in
//                let (i, searchText) = tuple
//                let item = NSMenuItem(title: searchText, action: #selector(didPressForwardMenuItem(_:)), keyEquivalent: "")
//                item.tag = i
//                return item
//            }
//        backForwardControl.setMenu(forwardMenu, forSegment: 1)
    }

    @objc
    private func didPressBackMenuItem(_ sender: NSMenuItem) {

    }

    @objc
    private func didPressForwardMenuItem(_ sender: NSMenuItem) {

    }
}
