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
class SearchQuery: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool {
        true
    }

    let searchText: String
    let direction: Dictionary.Direction

    override var debugDescription: String {
        "<\"\(searchText)\" (\(direction.debugDescription))>"
    }

    override var description: String {
        "\(searchText) (\(direction))"
    }

    func propertyListRepresentation() -> Any {
        ["searchText": searchText, "direction": direction.rawValue]
    }

    init?(fromPropertyListRepresentation obj: Any) {
        guard let obj = obj as? [String: Any] else {
            fatalError("Could not decode from obj \(obj)")
            return nil
        }
        guard let searchText = obj["searchText"] as? String,
              let direction = obj["direction"] as? Int else {
            return nil
        }
        self.searchText = searchText
        self.direction = .init(rawValue: direction)!
    }

    required init?(coder: NSCoder) {
        guard let searchText = coder.decodeObject(of: NSString.self, forKey: "searchText") as String? else {
            return nil
        }
        self.searchText = searchText
        guard let direction = Dictionary.Direction(rawValue: coder.decodeInteger(forKey: "direction")) else {
            return nil
        }
        self.direction = direction
        super.init()
    }

    init(_ searchText: String, _ direction: Dictionary.Direction) {
        self.searchText = searchText
        self.direction = direction
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? SearchQuery else { return false }
        return searchText == object.searchText &&
            direction == object.direction
    }

    func encode(with coder: NSCoder) {
        coder.encode(searchText, forKey: "searchText")
        coder.encode(direction.rawValue, forKey: "direction")
    }

    func withDirection(_ direction: Dictionary.Direction) -> SearchQuery {
        SearchQuery(searchText, direction)
    }
}

private extension NSStoryboard.SceneIdentifier {
    static let lookupWindowController = NSStoryboard.SceneIdentifier("LookupWindowController")
}

let DEFAULT_DIRECTION: Dictionary.Direction = .latinToEnglish

class LookupWindowController: NSWindowController {

    override class var restorableStateKeyPaths: [String] {
        ["_direction", "window.tab.title", "searchField.stringValue"]
    }

    @objc dynamic
    private var _direction: Dictionary.Direction.RawValue = DEFAULT_DIRECTION.rawValue {
        didSet {
            AppDelegate.shared?.updateDirectionItemsState()
            if #available(macOS 11.0, *) {
                window?.subtitle = Dictionary.Direction(rawValue: _direction)!.description
            }
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

    @IBOutlet @objc
    dynamic var backForwardController: BackForwardController!

    @IBOutlet @objc
    var fontSizeController: FontSizeController!

    @IBOutlet weak var backForwardToolbarItem: NSToolbarItem!
    @IBOutlet weak var directionItem: NSToolbarItem!
    @IBOutlet weak var fontSizeItem: NSToolbarItem!
    @IBOutlet weak var popUpButton: NSPopUpButton!
    @IBOutlet weak var searchField: NSSearchField!

    private var lookupViewController: LookupViewController! {
        contentViewController as? LookupViewController
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Set up menu form equivalents for toolbar items
        let backForwardMenuItem = NSMenuItem(title: "Back/Forward", action: nil, keyEquivalent: "")
        backForwardMenuItem.submenu = backForwardController.menu()
        backForwardToolbarItem.menuFormRepresentation = backForwardMenuItem

        let directionMenuItem = NSMenuItem(title: "Direction", action: nil, keyEquivalent: "")
        directionMenuItem.submenu = directionMenu
        directionItem.menuFormRepresentation = directionMenuItem

        let fontSizeMenuItem = NSMenuItem(title: "Font Size", action: nil, keyEquivalent: "")
        fontSizeMenuItem.submenu = fontSizeController.menu()
        fontSizeItem.menuFormRepresentation = fontSizeMenuItem

        // The window is restorable, so this will only affect initial launch after installation.
        window?.setContentSize(NSSize(width: 700, height: 500))

        window?.restorationClass = WindowRestoration.self
    }

    @objc
    override func encodeRestorableState(with coder: NSCoder) {
        backForwardController.encode(with: coder)
        super.restoreState(with: coder)
    }

    @objc
    override func restoreState(with coder: NSCoder) {
        backForwardController.decode(with: coder)
        super.restoreState(with: coder)
    }

    private func makeDirectionMenu() -> NSMenu {
        let m = NSMenu()
        lToEItem = NSMenuItem(title: Dictionary.Direction.latinToEnglish.description,
                              action: #selector(setLatinToEnglish),
                              keyEquivalent: "")
        lToEItem.state = .off
        m.addItem(lToEItem)
        eToLItem = NSMenuItem(title: Dictionary.Direction.englishToLatin.description,
                              action: #selector(setEnglishToLatin),
                              keyEquivalent: "")
        eToLItem.state = .off
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
        invalidateRestorableState()
    }

    @IBAction
    private func toggleDirection(_ sender: Any?) {
        direction.toggle()
    }

    @IBAction
    private func setLatinToEnglish(_ sender: Any?) {
        direction = .latinToEnglish
    }

    @IBAction
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

    override func newWindowForTab(_ sender: Any?) {
        let window = Self.newWindow()
        self.window?.addTabbedWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(sender)
    }

    static func newWindow() -> NSWindow {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: .lookupWindowController)
            as! LookupWindowController
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
