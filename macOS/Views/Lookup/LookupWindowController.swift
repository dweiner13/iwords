//
//  LookupWindowController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa
import SwiftUI

extension NSUserInterfaceItemIdentifier {
    static let backMenuItem = NSUserInterfaceItemIdentifier("back")
    static let forwardMenuItem = NSUserInterfaceItemIdentifier("forward")
    static let directionMenu = NSUserInterfaceItemIdentifier("directionMenu")
}

private extension NSStoryboard.SceneIdentifier {
    static let lookupWindowController =  NSStoryboard.SceneIdentifier("LookupWindowController")
}

let DEFAULT_DIRECTION: Dictionary.Direction = .latinToEnglish

class LookupWindowController: NSWindowController {

    @IBOutlet @objc
    dynamic var backForwardController: BackForwardController!

    @IBOutlet @objc
    var fontManager: NSFontManager!

    @IBOutlet
    var dictionaryController: DictionaryController!

    @IBOutlet weak var backForwardToolbarItem: NSToolbarItem!
    @IBOutlet weak var directionToggleItem: NSToolbarItem!
    @IBOutlet weak var fontSizeItem: NSToolbarItem!
    @IBOutlet weak var directionToggleButton: NSButton!
    @IBOutlet weak var floatToolbarItem: NSToolbarItem!

    // Not used, but need a strong reference or it will be dealloced.
    @IBOutlet var sharedFontSizeController: SharedFontSizeController!

    private weak var searchBar: SearchBarViewController!

    var lookupViewController: LookupViewController! {
        contentViewController as? LookupViewController
    }

    private var dirObservation: Any?

    private lazy var directionMenuFormRepresentation: NSMenu = {
        let menu = NSMenu()
        for direction in Dictionary.Direction.allCases {
            let item = NSMenuItem(title: direction.description, action: #selector(setDirection(_:)), keyEquivalent: "")
            item.tag = direction.rawValue
            menu.addItem(item)
        }
        return menu
    }()

    override func windowDidLoad() {
        super.windowDidLoad()
        AppDelegate.shared?.retainWindow(self)

        window?.showsToolbarButton = true

        // Set up menu form equivalents for toolbar items
        let backForwardMenuItem = NSMenuItem(title: "Back/Forward", action: nil, keyEquivalent: "")
        backForwardMenuItem.submenu = backForwardController.menu()
        backForwardToolbarItem.menuFormRepresentation = backForwardMenuItem

        let directionItem = NSMenuItem(title: "Direction", action: nil, keyEquivalent: "")
        directionItem.submenu = directionMenuFormRepresentation
        directionToggleItem?.menuFormRepresentation = directionItem
        fontSizeItem.menuFormRepresentation = fontMenuFormRepresentation()

        let floatItem = NSMenuItem(title: "Float on Top", action: #selector(toggleFloats(_:)), keyEquivalent: "")
        floatItem.target = self
        floatToolbarItem.menuFormRepresentation = floatItem

        // The window is restorable, so this will only affect initial launch after installation.
        window?.setContentSize(NSSize(width: 700, height: 500))

        window?.restorationClass = WindowRestoration.self
        window?.isRestorable = true
        window?.identifier = NSUserInterfaceItemIdentifier("lookup-" + UUID().uuidString)

        dirObservation = dictionaryController.observe(\.direction) { [weak self] dictionaryController, change in
            MainActor.assumeIsolated {
            guard let self = self else { return }
            let direction = dictionaryController.direction
            AppDelegate.shared?.updateDirectionItemsState(direction)
            self.updateTitle(forDirection: direction)
            self.invalidateRestorableState()
            self.directionToggleButton.title = direction.description

            self.directionMenuFormRepresentation.items[direction.rawValue].state = .on
            self.directionMenuFormRepresentation.items[1 - direction.rawValue].state = .off
            }
        }

        UserDefaults.standard.addObserver(self, forKeyPath: "windowsFloatOnTop", context: nil)

        setFloatsOnTop(UserDefaults.standard.bool(forKey: "windowsFloatOnTop"))

        dictionaryController.delegate = self

        updateTitle(forDirection: dictionaryController.direction)

        searchBar = NSStoryboard.main!.instantiateController(withIdentifier: .init("SearchBarViewController")) as? SearchBarViewController
        window?.addTitlebarAccessoryViewController(searchBar)
        searchBar.delegate = self
    }

    @objc
    func toggleFloats(_ sender: Any?) {
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "windowsFloatOnTop"),
                                  forKey: "windowsFloatOnTop")
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        setFloatsOnTop(UserDefaults.standard.bool(forKey: "windowsFloatOnTop"))
    }

    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: "windowsFloatOnTop")
    }

    func setFloatsOnTop(_ floats: Bool) {
        window?.level = floats ? .floating : .normal
        floatToolbarItem.menuFormRepresentation?.title = floats ? "Stop Floating on Top" : "Float on Top"
    }

    @objc
    func setDirection(_ sender: NSMenuItem) {
        guard let direction = Dictionary.Direction(rawValue: sender.tag) else {
            return
        }

        dictionaryController.direction = direction
    }

    @objc
    override func encodeRestorableState(with coder: NSCoder) {
        coder.encode(dictionaryController.direction.rawValue, forKey: "lookupDirection")
        if let results = lookupViewController?.results, let data = try? JSONEncoder().encode(results) {
            coder.encode(data, forKey: "lookupResultsJSON")
        }
        backForwardController.encode(with: coder)
        super.encodeRestorableState(with: coder)
    }

    @objc
    override func restoreState(with coder: NSCoder) {
        _ = window // Load storyboard outlets before decoding.
        if coder.containsValue(forKey: "lookupDirection") {
            dictionaryController.direction = Dictionary.Direction(rawValue: coder.decodeInteger(forKey: "lookupDirection")) ?? .latinToEnglish
        }
        if let data = coder.decodeObject(of: NSData.self, forKey: "lookupResultsJSON") {
            lookupViewController.results = try? JSONDecoder().decode([LookupResult].self, from: data as Data)
        }
        backForwardController.decode(with: coder)
        if let currentSearchDisplayText = backForwardController.currentSearchQuery?.displaySearchText() {
            self.window?.tab.title = currentSearchDisplayText
            if let query = backForwardController.currentSearchQuery { searchBar?.update(for: query) }
        }
        super.restoreState(with: coder)

        invalidateRestorableState()
    }

    public func setSearchQuery(_ searchQuery: SearchQuery, withAlternativeNavigation alt: Bool) {
        if alt {
            let controller = Self.newController()
            controller._setSearchQuery(searchQuery,
                                       updateHistoryLists: true,
                                       updateBackForward: true)
            controller.window?.makeKeyAndOrderFront(self)
        } else {
            let isCurrentQuery = searchQuery == backForwardController.currentSearchQuery

            self._setSearchQuery(searchQuery,
                                 updateHistoryLists: !isCurrentQuery,
                                 updateBackForward: !isCurrentQuery)
        }
    }

    func windowWillClose(_ notification: Notification) {
        dictionaryController?.cancel()
        backForwardController = nil
        fontManager = nil
        dictionaryController = nil
        AppDelegate.shared?.releaseWindow(self)

    }

    @IBAction
    private func exportRawResult(_ sender: Any?) {
        guard let results = lookupViewController?.results,
              let window = window else {
            NSSound.beep()
            return
        }
        let text = LookupResult.allRaw(results)
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

    private func fontMenuFormRepresentation() -> NSMenuItem {
        let item = NSMenuItem(title: "Font Size", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        let decrease = NSMenuItem(title: "Decrease Text Size", action: #selector(decreaseTextSize), keyEquivalent: "")
        decrease.target = self
        menu.addItem(decrease)
        let increase = NSMenuItem(title: "Increase Text Size", action: #selector(increaseTextSize), keyEquivalent: "")
        increase.target = self
        menu.addItem(increase)
        item.submenu = menu
        return item
    }

    // The core of the logic for actually performing a query and updating the UI.
    private func _setSearchQuery(_ searchQuery: SearchQuery,
                                 updateHistoryLists: Bool,
                                 updateBackForward: Bool) {
        searchBar.update(for: searchQuery)

        guard !searchQuery.searchText.isEmpty else {
            return
        }

        guard !isLoading else {
            NSSound.beep()
            return
        }

        self.window?.tab.title = searchQuery.displaySearchText()

        dictionaryController.direction = searchQuery.direction

        // Perform search
        isLoading = true
        dictionaryController.search(text: searchQuery.searchText) { [weak self] result in
            guard let self = self, self.dictionaryController != nil else {
                return
            }
            switch result {
            case .failure(let error):
                self.presentError(error)
                self.isLoading = false
            case .success(let results):
                if updateHistoryLists {
                    HistoryController.shared.recordVisit(to: searchQuery)
                }
                if updateBackForward {
                    self.backForwardController.recordVisit(to: searchQuery)
                }
                self.lookupViewController.results = results
                self.isLoading = false
                self.invalidateRestorableState()
            }
        }

        invalidateRestorableState()
    }

    @IBAction
    private func changeDirection(_ sender: Any?) {
        if let senderMenuItem = sender as? NSMenuItem,
           let newDirection = Dictionary.Direction(rawValue: senderMenuItem.tag) {
            dictionaryController.direction = newDirection
        } else {
            dictionaryController.direction.toggle()
        }
    }

    @IBAction
    func search(_ sender: Any?) {
        let searchText: String? = {
            if let sender = sender as? NSSearchField {
                return sender.stringValue
            } else if let sender = sender as? NSMenuItem {
                return sender.representedObject as? String
            } else if let sender = sender as? String {
                return sender
            } else { return nil }
        }()

        let direction: Dictionary.Direction? = {
            if let sender = sender as? NSMenuItem {
                return Dictionary.Direction(rawValue: sender.tag)
            } else { return nil }
        }()

        let isAlternateNavigation = (NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false)

        guard let searchText = searchText,
              let sanitized = Dictionary.sanitize(input: searchText) else {
            NSSound.beep()
            return
        }

        let query = SearchQuery(sanitized, direction ?? dictionaryController.direction)

        setSearchQuery(query, withAlternativeNavigation: isAlternateNavigation)
    }

    private var isLoading = false {
        didSet {
            backForwardController?.updateSegmentedControl()
            lookupViewController?.isLoading = isLoading
            searchBar?.isLoading = isLoading
            if isLoading {
                let indicator = NSProgressIndicator()
                indicator.controlSize = .small
                indicator.isIndeterminate = true
                indicator.style = .spinning
                indicator.startAnimation(self)
                window?.tab.accessoryView = indicator
            } else {
                window?.tab.accessoryView = nil
            }
        }
    }

    override func newWindowForTab(_ sender: Any?) {
        let newWindow = Self.newController(copying: UserDefaults.standard.bool(forKey: "copySearchToNewWindows") ? self : nil).window!
        var windowToAddTabAfter: NSWindow?

        if sender is NSWindow {
            windowToAddTabAfter = self.window?.tabbedWindows?.last ?? self.window
        } else {
            windowToAddTabAfter = self.window
        }

        windowToAddTabAfter?.addTabbedWindow(newWindow, ordered: .above)
        newWindow.makeKeyAndOrderFront(sender)
    }

    @objc
    func focusSearch(_ sender: Any?) {
        searchBar?.focusSearch(sender)
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
        } else {
            window?.title = "iWords"
        }
    }

    @objc
    func decreaseTextSize() {
        lookupViewController.decreaseTextSize()
    }

    @objc
    func increaseTextSize() {
        lookupViewController.increaseTextSize()
    }

    func resetTextSize() {
        lookupViewController.resetTextSize()
    }

    @IBAction
    func fontSizeControlPressed(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            decreaseTextSize()
        case 1:
            increaseTextSize()
        default:
            preconditionFailure()
        }
    }
}

// MARK: - Handling for toolbar items
@objc
extension LookupWindowController {
    override func responds(to aSelector: Selector!) -> Bool {
        switch aSelector {
        case #selector(goBack(_:)):
            return backForwardController.canGoBack
        case #selector(goForward(_:)):
            return backForwardController.canGoForward
        case #selector(exportRawResult(_:)):
            return lookupViewController?.results?.isEmpty == false
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

// MARK: - NSWindow Delegate

extension LookupWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        searchBar?.focusSearch(self)
    }

    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        let standardFrame = NSRect(origin: window.frame.origin,
                                 size: CGSize(width: lookupViewController.standardWidthAtCurrentFontSize(),
                                              height: window.frame.height))
        return standardFrame
    }
}

// MARK: - BackForward Delegate

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

// MARK: - DictionaryController Delegate

extension LookupWindowController: DictionaryControllerDelegate {
    func dictionary(_ dictionary: Dictionary, progressChangedTo progress: Double) {
        searchBar?.setProgress(progress)
    }
}

// MARK: - SearchBar Delegate

extension LookupWindowController: SearchBarDelegate {
    func searchBar(_ searchBar: SearchBarViewController, didSearchText text: String) {
        search(text)
    }
}
