//
//  BackForwardController.swift
//  words (macOS)
//
//  Created by Dan Weiner on 4/18/21.
//

import Cocoa

@objc
protocol BackForwardDelegate: AnyObject {
    func backForwardControllerCurrentQueryChanged(_ controller: BackForwardController)
    func backForwardControllerShouldChangeCurrentQuery(_ controller: BackForwardController) -> Bool
    func backForwardController(_ controller: BackForwardController, performAlternateNavigationToDisplayQuery query: SearchQuery)
}

private extension NSUserInterfaceItemIdentifier {
    static let backForwardMenuFormBackItem =
        NSUserInterfaceItemIdentifier("backForwardMenuFormBackItem")
    static let backForwardMenuFormForwardItem =
        NSUserInterfaceItemIdentifier("backForwardMenuFormForwardItem")
}


class BackForwardController: NSObject {

    /// Current search query
    internal private(set) var currentSearchQuery: SearchQuery?

    @IBOutlet
    weak var delegate: BackForwardDelegate?

    /// Attach a pre-configured 2-segment Segmented Control to this controller to have the
    /// controller manage the enabled/disabled states of the segments.
    @IBOutlet
    var segmentedControl: NSSegmentedControl? {
        didSet {
            updateSegmentedControl()
        }
    }

    var canGoBack: Bool {
        !backList.isEmpty && (delegate?.backForwardControllerShouldChangeCurrentQuery(self) ?? true)
    }

    var canGoForward: Bool {
        !forwardList.isEmpty && (delegate?.backForwardControllerShouldChangeCurrentQuery(self) ?? true)
    }

    var backItem: SearchQuery? {
        backList.last
    }

    var forwardItem: SearchQuery? {
        forwardList.last
    }

    private var backList: [SearchQuery] = [] {
        didSet {
            #if DEBUG
            print("backList: \(backList)")
            #endif
        }
    }

    private var forwardList: [SearchQuery] = [] {
        didSet {
            #if DEBUG
            print("forwardList: \(forwardList)")
            #endif
        }
    }

    func decode(with coder: NSCoder) {
        backList = coder.decodeObject(forKey: "backList") as? [SearchQuery] ?? []
        forwardList = coder.decodeObject(forKey: "forwardList") as? [SearchQuery] ?? []
        currentSearchQuery = coder.decodeObject(forKey: "currentSearchQuery") as? SearchQuery
        updateSegmentedControl()
    }

    func encode(with coder: NSCoder) {
        coder.encode(backList, forKey: "backList")
        coder.encode(forwardList, forKey: "forwardList")
        coder.encode(currentSearchQuery, forKey: "currentSearchQuery")
    }

    /// A preconfigured a NSMenu with Back and Forward items.
    func menu() -> NSMenu {
        let m = NSMenu()
        let backItem = NSMenuItem(title: "Back", action: #selector(goBack(_:)), keyEquivalent: "")
        backItem.identifier = .backForwardMenuFormBackItem
        backItem.target = self
        m.addItem(backItem)
        let forwardItem = NSMenuItem(title: "Forward", action: #selector(goForward(_:)), keyEquivalent: "")
        forwardItem.identifier = .backForwardMenuFormForwardItem
        forwardItem.target = self
        m.addItem(forwardItem)
        m.autoenablesItems = true
        return m
    }

    @IBAction
    func goBack(_ sender: Any?) {
        guard delegate?.backForwardControllerShouldChangeCurrentQuery(self) ?? true else {
            return
        }
        // If user holds shift, go back in new window
        if NSApp.currentEventModifierFlags.contains(.shift),
            let delegate = delegate,
            let backItem = backItem {
            delegate.backForwardController(self, performAlternateNavigationToDisplayQuery: backItem)
            return
        }
        guard let back = backList.popLast() else {
            return
        }
        if let currentSearchQuery = currentSearchQuery {
            forwardList.append(currentSearchQuery)
        }
        currentSearchQuery = back
        delegate?.backForwardControllerCurrentQueryChanged(self)
        updateSegmentedControl()
    }

    @IBAction
    func goForward(_ sender: Any?) {
        guard delegate?.backForwardControllerShouldChangeCurrentQuery(self) ?? true else {
            return
        }
        // If user holds shift, go back in new window
        if NSApp.currentEventModifierFlags.contains(.shift),
            let delegate = delegate,
            let forwardItem = forwardItem {
            delegate.backForwardController(self, performAlternateNavigationToDisplayQuery: forwardItem)
            return
        }
        guard let forward = forwardList.popLast() else {
            return
        }
        if let lastSearchTerm = currentSearchQuery {
            backList.append(lastSearchTerm)
        }
        currentSearchQuery = forward
        delegate?.backForwardControllerCurrentQueryChanged(self)
        updateSegmentedControl()
    }

    func recordVisit(to searchQuery: SearchQuery?) {
        if let currentSearchQuery = currentSearchQuery, currentSearchQuery != backList.last {
            backList.append(currentSearchQuery)
            forwardList = []
        }
        currentSearchQuery = searchQuery
        updateSegmentedControl()
    }

    @IBAction
    func backForwardControlPressed(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: goBack(sender)
        case 1: goForward(sender)
        default: return
        }
    }

    func updateSegmentedControl() {
        segmentedControl?.setEnabled(canGoBack,    forSegment: 0)
        segmentedControl?.setEnabled(canGoForward, forSegment: 1)
    }
}

extension BackForwardController: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.identifier {
        case .some(.backForwardMenuFormBackItem):
            return canGoBack
        case .some(.backForwardMenuFormForwardItem):
            return canGoForward
        default:
            return true
        }
    }

}
