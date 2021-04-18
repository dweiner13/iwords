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
        didSelectHistoryItem query: SearchQuery
    )
}

// MARK: - HistoryController

class HistoryController: NSObject {
    @IBOutlet
    weak var delegate: HistoryDelegate?

    static var shared: HistoryController!

    /// If HistoryController is a delegate for an NSMenu, this property is the index at which
    /// the controller should begin managing menu items.
    ///
    /// On menu updates, all items at this index and further will be removed and replaced with a
    /// list of history menu items.
    @IBInspectable
    var beginManagedMenuIndex = 2

    private var history: [SearchQuery] = [] {
        didSet {
            print("history: \(history)")
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
    }
}

// MARK: - NSMenuDelegate

extension HistoryController: NSMenuDelegate, NSMenuItemValidation {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.identifier == .historyMenu else {
            return
        }

        let items = [.separator()] + history
            .reversed()
            .enumerated()
            .map { tuple -> NSMenuItem in
                let (i, query) = tuple
                let item = NSMenuItem(title: query.searchText,
                                      action: #selector(historyMenuItemSelected(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.tag = i
                return item
            }

        menu.items.replaceSubrange(beginManagedMenuIndex..., with: items)
    }

    @objc
    private func historyMenuItemSelected(_ sender: NSMenuItem) {
        let historyItemIndex = sender.tag
        let historyItem = history.reversed()[historyItemIndex]
        delegate?.historyController(
            self,
            didSelectHistoryItem: historyItem
        )
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        true
    }
}
