//
//  LookupWindowController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa
import Combine

extension NSUserInterfaceItemIdentifier {
    static let backMenuItem = NSUserInterfaceItemIdentifier("back")
    static let forwardMenuItem = NSUserInterfaceItemIdentifier("forward")
    static let directionMenu = NSUserInterfaceItemIdentifier("directionMenu")
}

extension UserDefaults {
    var dictionaryOptions: Dictionary.Options {
        var options = Dictionary.Options()
        if bool(forKey: "diagnosticMode"), AppDelegate.shared.isDebug {
            options.insert(.diagnosticMode)
        }
        return options
    }
}

@objc
class SearchQuery: NSObject {
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? SearchQuery else { return false }
        return searchText == object.searchText &&
            direction == object.direction
    }

    let searchText: String
    let direction: Dictionary.Direction

    override var debugDescription: String {
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

let DEFAULT_DIRECTION: Dictionary.Direction = .latinToEnglish

/// This class is functionally the singleton controller for the whole application.
class LookupWindowController: NSWindowController {

    @objc dynamic
    private var _direction: Dictionary.Direction.RawValue = DEFAULT_DIRECTION.rawValue {
        didSet {
            AppDelegate.shared.updateDirectionItemsState()
        }
    }
    var direction: Dictionary.Direction {
        get {
            .init(rawValue: _direction)!
        }
        set {
            _direction = newValue.rawValue
        }
    }

    private lazy var directionMenu = makeDirectionMenu()
    private var lToEItem: NSMenuItem!
    private var eToLItem: NSMenuItem!

    @IBOutlet var backForwardController: BackForwardController!

    @IBOutlet weak var backForwardToolbarItem: NSToolbarItem!
    @IBOutlet weak var directionItem: NSToolbarItem!
    @IBOutlet weak var popUpButton: NSPopUpButton!
    @IBOutlet weak var searchField: NSSearchField!

    private var cancellables: [AnyCancellable] = []

    private var lookupViewController: LookupViewController! {
        contentViewController as? LookupViewController
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Set up menu form equivalents for buttons
        let backForwardMenuItem = NSMenuItem(title: "Back/Forward", action: nil, keyEquivalent: "")
        backForwardMenuItem.submenu = backForwardController.menu()
        backForwardToolbarItem.menuFormRepresentation = backForwardMenuItem

        let directionMenuItem = NSMenuItem(title: "Direction", action: nil, keyEquivalent: "")
        directionMenuItem.submenu = directionMenu
        directionItem.menuFormRepresentation = directionMenuItem

        // The window is restorable, so this will only affect initial launch after installation.
        window?.setContentSize(NSSize(width: 700, height: 500))
    }

    private func makeDirectionMenu() -> NSMenu {
        let m = NSMenu()
        lToEItem = NSMenuItem(title: "Latin to English",
                              action: #selector(setLatinToEnglish),
                              keyEquivalent: "L")
        lToEItem.state = .off
        lToEItem.keyEquivalentModifierMask = [.command, .shift]
        m.addItem(lToEItem)
        eToLItem = NSMenuItem(title: "English to Latin",
                              action: #selector(setEnglishToLatin),
                              keyEquivalent: "E")
        eToLItem.state = .off
        lToEItem.keyEquivalentModifierMask = [.command, .shift]
        m.addItem(eToLItem)
        m.delegate = self
        m.identifier = .directionMenu
        return m
    }

    public func setSearchQuery(_ searchQuery: SearchQuery) {
        guard searchQuery != backForwardController.currentSearchQuery else {
            print("Ignoring redundant search query \(searchQuery)")
            return
        }
        self._setSearchQuery(searchQuery,
                             updateHistoryLists: true,
                             updateBackForward: true)
    }

    // The core of the logic for actually performing a query and updating the UI.
    private func _setSearchQuery(_ searchQuery : SearchQuery,
                                 updateHistoryLists: Bool,
                                 updateBackForward: Bool) {
        guard !searchQuery.searchText.isEmpty else {
            return
        }

        searchField.stringValue = searchQuery.searchText

        self.window?.tab.title = searchQuery.searchText

        direction = searchQuery.direction
        search(searchQuery)
        if updateHistoryLists {
            HistoryController.shared.recordVisit(to: searchQuery)
        }
        if updateBackForward {
            backForwardController.recordVisit(to: searchQuery)
        }
    }

    @objc
    private func setLatinToEnglish(_ sender: Any?) {
        direction = .latinToEnglish
    }

    @objc
    private func setEnglishToLatin(_ sender: Any?) {
        direction = .englishToLatin
    }

    @IBAction
    private func searchFieldAction(_ field: NSSearchField) {
        setSearchQuery(SearchQuery(field.stringValue, direction))
    }

    /// - Returns: whether or not a result was found
    private func search(_ query: SearchQuery) {
        do {
            let results = try Dictionary.shared.getDefinition(
                query.searchText,
                direction: query.direction,
                options: UserDefaults.standard.dictionaryOptions
            )
            lookupViewController.setResultText(results ?? "No results found")
            print("Query entered: \"\(query.debugDescription)\"")
        } catch {
            self.presentError(error)
        }
    }

    @objc
    private func focusSearch(_ sender: Any?) {
        searchField?.becomeFirstResponder()
    }

    @objc
    private func newTab(_ sender: Any?) {
        window?.addTabbedWindow(Self.newWindow(), ordered: .above)
    }

    override func newWindowForTab(_ sender: Any?) {
        let window = Self.newWindow()
        self.window?.addTabbedWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(sender)
    }

    static func newWindow() -> NSWindow {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateInitialController() as! LookupWindowController
        return controller.window!
    }
}

// Handling for back/forward
@objc
extension LookupWindowController {
    override func responds(to aSelector: Selector!) -> Bool {
        switch aSelector {
        case #selector(goBack(_:)):
            return backForwardController.canGoBack
        case #selector(goForward(_:)):
            return backForwardController.canGoForward
        default:
            return super.responds(to: aSelector)
        }
    }

    func goBack(_ sender: Any?) {
        backForwardController.goBack(sender)
    }

    func goForward(_ sender: Any?) {
        backForwardController.goForward(sender)
    }
}

extension LookupWindowController: BackForwardDelegate {
    func backForwardControllerCurrentQueryChanged(_ controller: BackForwardController) {
        assert(controller == backForwardController)

        guard let searchQuery = controller.currentSearchQuery else {
            return
        }
        _setSearchQuery(searchQuery,
                        updateHistoryLists: false,
                        updateBackForward: false)
    }
}

// Handling for menu form representation of direction control
extension LookupWindowController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        assert(menu.identifier == directionMenu.identifier)

        menu.items[0].state = _direction == 0 ? .on : .off
        menu.items[1].state = _direction == 1 ? .on : .off
    }
}

extension LookupWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        searchField.becomeFirstResponder()
    }
}
