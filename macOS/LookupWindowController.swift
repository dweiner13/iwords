//
//  LookupWindowController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa
import Combine
import SwiftUI

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
    static let lookupWindowController =  NSStoryboard.SceneIdentifier("LookupWindowController")
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

    @IBOutlet @objc
    dynamic var backForwardController: BackForwardController!

    @IBOutlet @objc
    var fontSizeController: FontSizeController!

    @IBOutlet weak var backForwardToolbarItem: NSToolbarItem!
    @IBOutlet weak var directionItem: NSToolbarItem!
    @IBOutlet weak var fontSizeItem: NSToolbarItem!
    @IBOutlet weak var directionToggleButton: NSButton!
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

        let directionMenuItem = NSMenuItem(title: "Toggle Direction",
                                           action: #selector(toggleDirection(_:)),
                                           keyEquivalent: "")
        directionItem.menuFormRepresentation = directionMenuItem

        let fontSizeMenuItem = NSMenuItem(title: "Font Size", action: nil, keyEquivalent: "")
        fontSizeMenuItem.submenu = fontSizeController.menu()
        fontSizeItem.menuFormRepresentation = fontSizeMenuItem

        // The window is restorable, so this will only affect initial launch after installation.
        window?.setContentSize(NSSize(width: 700, height: 500))

        window?.restorationClass = WindowRestoration.self

        if #available(macOS 11.0, *) {
            window?.subtitle = Dictionary.Direction(rawValue: _direction)!.description
        }
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

    public func setSearchQuery(_ searchQuery: SearchQuery) {
        guard searchQuery != backForwardController.currentSearchQuery else {
            print("Ignoring redundant search query \(searchQuery)")
            return
        }
        self._setSearchQuery(searchQuery,
                             updateHistoryLists: true,
                             updateBackForward: true)
    }

    @IBAction
    private func exportRawResult(_ sender: Any?) {
        guard let text = lookupViewController?.text,
              let window = window else {
                  NSSound.beep()
                  return
              }
        let data = text.data(using: .utf8)
        let fileName = "\(backForwardController.currentSearchQuery?.searchText ?? "results").txt"
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = fileName
        savePanel.beginSheetModal(for: window) { [savePanel] modalResponse in
            guard modalResponse == .OK else {
                return
            }
            guard let url = savePanel.url else {
                NSSound.beep()
                return
            }
            do {
                try data?.write(to: url)
            } catch {
                self.presentError(error)
            }
        }
    }

    #if DEBUG
    private func canExportJSONResult() -> Bool {
        lookupViewController?.results != nil
    }

    @IBAction
    private func exportJSONResult(_ sender: Any?) {
        guard let results = lookupViewController?.results,
              let window = window else {
            NSSound.beep()
            return
        }
        let fileName = "\(backForwardController.currentSearchQuery?.searchText ?? "results").json"
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = fileName
        savePanel.beginSheetModal(for: window) { [savePanel] modalResponse in
            guard modalResponse == .OK else {
                return
            }
            guard let url = savePanel.url else {
                NSSound.beep()
                return
            }
            do {
                try JSONEncoder().encode(results).write(to: url)
            } catch {
                self.presentError(error)
            }
        }
    }
    #endif

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
            lookupViewController.text = results ?? ""
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
            #if DEBUG
        case #selector(exportJSONResult(_:)):
            return canExportJSONResult()
            #endif
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

extension LookupWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        searchField.becomeFirstResponder()
    }

    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        let standardFrame = NSRect(origin: window.frame.origin,
                                 size: CGSize(width: lookupViewController.standardWidthAtCurrentFontSize(),
                                              height: window.frame.height))
        return standardFrame
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
