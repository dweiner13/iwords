//
//  LookupWindowController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa
import Combine
import SwiftUI
import Flow

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

    func displaySearchText() -> String {
        String(searchText.prefix(100))
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

private extension NSUserInterfaceItemIdentifier {
    static let fontSizeMenuFormDecrease = NSUserInterfaceItemIdentifier("fontSizeMenuFormDecrease")
    static let fontSizeMenuFormIncrease = NSUserInterfaceItemIdentifier("fontSizeMenuFormIncrease")
}


class LookupWindowController: NSWindowController {

    override class var restorableStateKeyPaths: [String] {
        ["_direction", "window.tab.title", "searchField.stringValue", "dictionaryController"]
    }

    @IBOutlet @objc
    dynamic var backForwardController: BackForwardController!

    @IBOutlet @objc
    var fontManager: NSFontManager!

    @IBOutlet
    var dictionaryController: DictionaryController!

    @IBOutlet weak var backForwardToolbarItem: NSToolbarItem!
    @IBOutlet weak var directionItem: NSToolbarItem!
    @IBOutlet weak var fontSizeItem: NSToolbarItem!
    @IBOutlet weak var directionToggleButton: NSButton!
    @IBOutlet weak var searchField: NSSearchField!

    var lookupViewController: LookupViewController! {
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

        fontSizeItem.menuFormRepresentation = fontMenuFormRepresentation()

        // The window is restorable, so this will only affect initial launch after installation.
        window?.setContentSize(NSSize(width: 700, height: 500))

        window?.restorationClass = WindowRestoration.self

        dictionaryController.delegate = self

        updateTitle(forDirection: dictionaryController.direction)
    }

    @objc
    override func encodeRestorableState(with coder: NSCoder) {
        backForwardController.encode(with: coder)
        super.encodeRestorableState(with: coder)
    }

    @objc
    override func restoreState(with coder: NSCoder) {
        backForwardController.decode(with: coder)
        super.restoreState(with: coder)
    }

    public func setSearchQuery(_ searchQuery: SearchQuery, withAlternativeNavigation alt: Bool) {
        if alt {
            let controller = Self.newController()
            controller._setSearchQuery(searchQuery,
                                       updateHistoryLists: true,
                                       updateBackForward: true)
            controller.window?.makeKeyAndOrderFront(self)
        } else {
            guard searchQuery != backForwardController.currentSearchQuery else {
                print("Ignoring redundant search query \(searchQuery)")
                return
            }

            self._setSearchQuery(searchQuery,
                                 updateHistoryLists: true,
                                 updateBackForward: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        backForwardController = nil
        fontManager = nil
        dictionaryController = nil
    }

    @IBAction
    func lookUpInPerseus(_ sender: Any?) {
        guard let searchText = backForwardController.currentSearchQuery?.searchText else {
            return
        }

        let urls = PerseusUtils.urlsForLookUpInPerseus(searchText: searchText)

        if urls.count > 1 && !UserDefaults.standard.bool(forKey: "suppressMultipleTabsAlert") {
            let alert = NSAlert()
            alert.messageText = "Are you sure you want to open \(urls.count) new tabs in your web browser?"
            alert.informativeText = "\(urls.count) tabs to www.perseus.tufts.edu will be opened."
            alert.addButton(withTitle: "Open \(urls.count) Tabs")
            alert.addButton(withTitle: "Cancel")
            alert.showsSuppressionButton = true
            let clicked = alert.runModal()

            if let suppressionButton = alert.suppressionButton,
               suppressionButton.state == .on {
                UserDefaults.standard.set(true, forKey: "suppressMultipleTabsAlert")
            }

            guard clicked == .alertFirstButtonReturn else {
                return
            }
        }

        urls.forEach {
            NSWorkspace.shared.open($0)
        }
    }

    @IBAction
    private func exportRawResult(_ sender: Any?) {
        guard let results = lookupViewController?.results,
              let window = window else {
            NSSound.beep()
            return
        }
        let text = DictionaryController.Result.allRaw(results)
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
                let parsedResults = results.compactMap(\.parsed).flatMap { $0 }
                try JSONEncoder()
                    .encode(parsedResults)
                    .write(to: url)
            } catch {
                self.presentError(error)
            }
        }
    }
    #endif

    private func fontMenuFormRepresentation() -> NSMenuItem {
        NSMenuItem(title: "Font Size", action: nil, keyEquivalent: "").then {
            $0.submenu = NSMenu().then { m in
                let decrease = NSMenuItem(title: "Decrease Text Size",
                                          action: #selector(NSFontManager.modifyFont(_:)),
                                          keyEquivalent: "").then {
                    $0.target = NSFontManager.shared
                    $0.identifier = .fontSizeMenuFormDecrease
                    $0.tag = Int(NSFontAction.sizeDownFontAction.rawValue)
                }
                m.addItem(decrease)
                let increase = NSMenuItem(title: "Increase Text Size",
                                          action: #selector(NSFontManager.modifyFont(_:)),
                                          keyEquivalent: "").then {
                    $0.target = NSFontManager.shared
                    $0.identifier = .fontSizeMenuFormIncrease
                    $0.tag = Int(NSFontAction.sizeUpFontAction.rawValue)
                }
                m.addItem(increase)
            }
        }
    }

    // The core of the logic for actually performing a query and updating the UI.
    private func _setSearchQuery(_ searchQuery : SearchQuery,
                                 updateHistoryLists: Bool,
                                 updateBackForward: Bool) {
        guard !searchQuery.searchText.isEmpty else {
            return
        }

        guard !isLoading else {
            NSSound.beep()
            return
        }

        searchField.stringValue = searchQuery.searchText

        self.window?.tab.title = searchQuery.displaySearchText()

        dictionaryController.direction = searchQuery.direction
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
        dictionaryController.direction.toggle()
    }

    @IBAction
    private func searchFieldAction(_ field: NSSearchField) {
        guard let sanitized = sanitize(searchFieldValue: field.stringValue) else {
            return
        }

        let query = SearchQuery(sanitized, dictionaryController.direction)

        setSearchQuery(query, withAlternativeNavigation: false)
    }

    private func sanitize(searchFieldValue: String) -> String? {
        let trimmed = searchFieldValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(["#", "!", "@", "~"]))
        return trimmed.count > 1 ? trimmed : nil
    }

    private var isLoading = false {
        didSet {
            backForwardController?.updateSegmentedControl()
            lookupViewController?.setLoading(isLoading)
            window?.tab.accessoryView = isLoading ? NSProgressIndicator().then {
                $0.controlSize = .small
                $0.isIndeterminate = true
                $0.style = .spinning
                $0.startAnimation(self)
            } : nil
        }
    }

    private func search(_ query: SearchQuery) {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else {
                return
            }
            do {
                self.isLoading = true
                let results = try await self.dictionaryController.search(text: query.searchText)
                self.lookupViewController.results = results
                self.isLoading = false
            } catch {
                self.presentError(error)
            }
        }
    }

    @objc
    private func focusSearch(_ sender: Any?) {
        searchField?.becomeFirstResponder()
    }

    override func newWindowForTab(_ sender: Any?) {
        let newWindow = Self.newController(copying: self).window!
        var windowToAddTabAfter: NSWindow?

        if sender is NSWindow {
            windowToAddTabAfter = self.window?.tabbedWindows?.last ?? self.window
        } else {
            windowToAddTabAfter = self.window
        }

        windowToAddTabAfter?.addTabbedWindow(newWindow, ordered: .above)
        newWindow.makeKeyAndOrderFront(sender)
    }

    func copyState(from otherController: LookupWindowController) {
        if let currentSearchQuery = otherController.backForwardController.currentSearchQuery {
            _setSearchQuery(currentSearchQuery,
                            updateHistoryLists: false,
                            updateBackForward: true)
        } else {
            // If we don't have a query, just update direction
            dictionaryController.direction = otherController.dictionaryController.direction
        }
    }

    static func newController(copying original: LookupWindowController? = nil) -> LookupWindowController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let newController = storyboard.instantiateController(withIdentifier: .lookupWindowController)
            as! LookupWindowController
        if let original = original {
            newController.copyState(from: original)
        }
        return newController
    }

    private func updateTitle(forDirection direction: Dictionary.Direction) {
        if #available(macOS 11.0, *) {
            window?.title = "iWords"
            window?.subtitle = direction.description
        } else {
            window?.title = "iWords (\(direction.description))"
        }
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
        case #selector(lookUpInPerseus(_:)):
            guard let searchText = backForwardController.currentSearchQuery?.searchText else {
                return false
            }
            return PerseusUtils.canLookUpInPerseus(searchText: searchText)
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

    func backForwardControllerShouldChangeCurrentQuery(_ controller: BackForwardController) -> Bool {
        !isLoading
    }

    func backForwardController(_ controller: BackForwardController,
                               performAlternateNavigationToDisplayQuery query: SearchQuery) {
        let controller = Self.newController()
        controller._setSearchQuery(query,
                                   updateHistoryLists: false,
                                   updateBackForward: true)
        controller.window?.makeKeyAndOrderFront(self)
    }
}

extension LookupWindowController: DictionaryControllerDelegate {
    func dictionary(_ dictionary: Dictionary, progressChangedTo progress: Double) {
        lookupViewController.progressIndicator.doubleValue = progress * 100
    }

    func dictionaryController(_ controller: DictionaryController,
                              didChangeDirectionTo direction: Dictionary.Direction) {
        AppDelegate.shared?.updateDirectionItemsState()
        updateTitle(forDirection: direction)
        invalidateRestorableState()
    }
}
