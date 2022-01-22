//
//  HistoryController.swift
//  words (macOS)
//
//  Created by Dan Weiner on 4/18/21.
//

import Cocoa

extension NSUserInterfaceItemIdentifier {
    static let historyMenu = NSUserInterfaceItemIdentifier("history")
}

// MARK: - HistoryDelegate

@objc
protocol HistoryDelegate {
    func historyController(
        _ historyController: HistoryController,
        didSelectHistoryItem query: SearchQuery,
        withAlternativeNavigation alt: Bool
    )
}

// MARK: - HistoryController

private let MAX_HISTORY = 50

class HistoryController: NSObject {
    @IBOutlet
    weak var delegate: HistoryDelegate?

    static var shared: HistoryController!

    /// If HistoryController is a delegate for an NSMenu, this property is the index at which
    /// the controller should begin managing menu items.
    ///
    /// On menu updates, all items at this index and further will be removed and replaced with a
    /// list of history menu items.
    ///
    /// The default value is 2.
    @IBInspectable
    var beginManagedMenuIndex = 2

    @IBAction
    func clearHistory(_ sender: Any?) {
        history.removeAll()
    }

    private var history: [SearchQuery] {
        get {
            UserDefaults.standard.array(forKey: "history")?
                .compactMap(SearchQuery.init(fromPropertyListRepresentation:)) ?? []
        }
        set {
            UserDefaults.standard.setValue(newValue.map { $0.propertyListRepresentation() }, forKey: "history")
        }
    }

    override init() {
        guard Self.shared == nil else {
            fatalError("HistoryController should not be initialized more than once. Use HistoryController.shared instead.")
        }
        super.init()
        Self.shared = self
    }

    func recordVisit(to query: SearchQuery) {
        guard history.last != query else {
            return
        }
        history.append(query)
        if history.count > MAX_HISTORY {
            history = Array(history.dropFirst())
        }
    }
}

// MARK: - NSMenuDelegate

extension HistoryController: NSMenuDelegate, NSMenuItemValidation {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.identifier == .historyMenu else {
            return
        }

        let items = [.separator(), clearHistoryMenuItem(), .separator()] + history
            .reversed()
            .enumerated()
            .map { tuple -> NSMenuItem in
                let (i, query) = tuple
                let item = NSMenuItem(title: query.description,
                                      action: #selector(historyMenuItemSelected(_:)),
                                      keyEquivalent: "")
                let attrString = NSMutableAttributedString(string: query.displaySearchText())
                attrString.append(NSAttributedString(string: " (\(query.direction.description))", attributes: [.foregroundColor: NSColor.secondaryLabelColor]))
                item.attributedTitle = attrString
                item.target = self
                item.tag = i
                return item
            }

        menu.items.replaceSubrange(beginManagedMenuIndex..., with: items)
    }

    private func clearHistoryMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Clear History",
                              action: #selector(clearHistory(_:)),
                              keyEquivalent: "")
        item.target = self
        return item
    }

    @objc
    private func historyMenuItemSelected(_ sender: NSMenuItem) {
        let historyItemIndex = sender.tag
        let historyItem = history.reversed()[historyItemIndex]
        delegate?.historyController(self,
                                    didSelectHistoryItem: historyItem,
                                    withAlternativeNavigation: NSApp.currentEventModifierFlags.contains(.shift) ?? false)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        true
    }
}
