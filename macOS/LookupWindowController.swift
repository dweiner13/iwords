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
        if bool(forKey: "diagnosticMode"), AppDelegate.shared.isDebug {
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

struct SearchQuery: Equatable, Identifiable, CustomDebugStringConvertible {
    let searchText: String
    let direction: Dictionary.Direction
    let id = UUID()

    var debugDescription: String {
        #"<"\#(searchText) (\#(direction))>"#
    }

    func withDirection(_ direction: Dictionary.Direction) -> SearchQuery {
        SearchQuery(searchText, direction)
    }

    init(_ searchText: String, _ direction: Dictionary.Direction) {
        self.searchText = searchText
        self.direction = direction
    }
}

/// This class is functionally the singleton controller for the whole application.
class LookupWindowController: NSWindowController, NSMenuItemValidation {

    static var shared: LookupWindowController!

    var canGoBack: Bool {
        !backList.isEmpty
    }

    var canGoForward: Bool {
        !forwardList.isEmpty
    }

    private var backList: [SearchQuery] = [] {
        didSet {
            print("backList: \(backList)")
        }
    }
    private var forwardList: [SearchQuery] = [] {
        didSet {
            print("forwardList: \(forwardList)")
        }
    }
    private var lastSearchQuery: SearchQuery?

    private var backForwaredMenu: NSMenu!
    private var directionMenu: NSMenu!
    private var lToEItem: NSMenuItem!
    private var eToLItem: NSMenuItem!

    @IBOutlet weak var backForwardToolbarItem: NSToolbarItem!
    @IBOutlet weak var backForwardControl: NSSegmentedControl!
    @IBOutlet weak var directionItem: NSToolbarItem!
    @IBOutlet weak var popUpButton: NSPopUpButton!
    @IBOutlet weak var searchField: NSSearchField!

    private var cancellables: [AnyCancellable] = []

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

        // Set up menu form equivalents for buttons

        updateBackForwardButtons()
        let backForwardMenuItem = NSMenuItem(title: "Back/Forward", action: nil, keyEquivalent: "")
        let backForwardSubmenu = NSMenu()
        let backItem = NSMenuItem(title: "Back", action: #selector(goBack(_:)), keyEquivalent: "")
        backItem.identifier = .backForwardMenuFormBackItem
        backForwardSubmenu.addItem(backItem)
        let forwardItem = NSMenuItem(title: "Forward", action: #selector(goForward(_:)), keyEquivalent: "")
        forwardItem.identifier = .backForwardMenuFormForwardItem
        backForwardSubmenu.addItem(forwardItem)
        backForwaredMenu = backForwardSubmenu
        backForwaredMenu.autoenablesItems = true
        backForwardMenuItem.submenu = backForwardSubmenu
        backForwardToolbarItem.menuFormRepresentation = backForwardMenuItem

        let directionMenuItem = NSMenuItem(title: "Direction", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        lToEItem = NSMenuItem(title: "Latin to English", action: #selector(setLatinToEnglish), keyEquivalent: "")
        lToEItem.state = .off
        submenu.addItem(lToEItem)
        eToLItem = NSMenuItem(title: "English to Latin", action: #selector(setEnglishToLatin), keyEquivalent: "")
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
        NotificationCenter.default
            .publisher(for: .focusSearch)
            .sink(receiveValue: focusSearch(_:))
            .store(in: &cancellables)

        updateDirectionMenuItems()

        // The window is restorable, so this will only affect initial launch after installation.
        window?.setContentSize(NSSize(width: 700, height: 500))
    }

    public func setSearchQuery(_ searchQuery: SearchQuery) {
        self.setSearchQuery(searchQuery, updateHistoryLists: true)
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

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard NSUserDefaultsController.shared.isEqual(to: object),
              keyPath == "values.translationDirection" else { return }
        updateDirectionMenuItems()
    }

    func updateDirectionMenuItems() {
        let new = UserDefaults.standard.integer(forKey: "translationDirection")
        directionMenu?.items[0].state = new == 0 ? .on : .off
        directionMenu?.items[1].state = new == 1 ? .on : .off
    }

    @IBAction func backForwardControlPressed(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: goBack()
        case 1: goForward()
        default: return
        }
    }

    // The core of the logic for actually performing a query and updating the UI.
    private func setSearchQuery(_ searchQuery: SearchQuery,
                                updateHistoryLists: Bool) {
        guard !searchQuery.searchText.isEmpty,
              searchQuery != lastSearchQuery else {
            return
        }
        searchField.stringValue = searchQuery.searchText

        UserDefaults.standard.setValue(searchQuery.direction.rawValue,
                                       forKey: "translationDirection")
        if updateHistoryLists, let lastSearchQuery = lastSearchQuery, lastSearchQuery != backList.last {
            backList.append(lastSearchQuery)
            forwardList = []
        }
        if search(searchQuery) {
            if updateHistoryLists {
                HistoryController.shared.recordVisit(to: searchQuery)
            }
            lastSearchQuery = searchQuery
        } else {
            lastSearchQuery = nil
        }
        updateBackForwardButtons()
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
        setSearchQuery(SearchQuery(field.stringValue, direction))
    }

    /// - Returns: whether or not a result was found
    @discardableResult
    private func search(_ query: SearchQuery) -> Bool {
        do {
            let results = try Dictionary.shared.getDefinition(
                query.searchText,
                direction: query.direction,
                options: UserDefaults.standard.dictionaryOptions
            )
            lookupViewController.setResultText(results ?? "No results found")
            print("Query entered: \"\(query)\"")
            return results != nil
        } catch {
            self.presentError(error)
            return false
        }
    }

    @objc
    private func goBack(_ sender: Any? = nil) {
        if let lastSearchQuery = lastSearchQuery {
            forwardList.append(lastSearchQuery)
        }
        if let back = backList.popLast() {
            setSearchQuery(back, updateHistoryLists: false)
        }
        updateBackForwardButtons()
    }

    @objc
    private func goForward(_ sender: Any? = nil) {
        if let lastSearchTerm = lastSearchQuery {
            backList.append(lastSearchTerm)
        }
        if let forward = forwardList.popLast() {
            setSearchQuery(forward, updateHistoryLists: false)
        }
        updateBackForwardButtons()
    }

    @objc
    private func focusSearch(_ sender: Any?) {
        searchField?.becomeFirstResponder()
    }
}
