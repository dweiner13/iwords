//
//  SearchBarViewController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/15/22.
//

import Cocoa

protocol SearchBarDelegate: AnyObject {
    func searchBar(_ searchBar: SearchBarViewController, didSearchText text: String)
}

class SearchBarViewController: NSTitlebarAccessoryViewController {

    @IBOutlet private weak var searchField: AutoGrowingTextField!
    @IBOutlet private weak var directionToggleButton: NSButton!
    @IBOutlet private weak var goButton: NSButton!

//    @IBAction
//    private let searchFieldHeightAnchor: NSLayoutConstraint!
    @IBOutlet private weak var searchFieldHeightAnchor: NSLayoutConstraint!

    @IBOutlet private weak var progressIndicator: NSProgressIndicator!

    weak var backForwardController: BackForwardController? {
        didSet {
            backForwardControllerObservation = nil
            backForwardControllerObservation = backForwardController?.observe(\.currentSearchQuery, changeHandler: { backForwardController, change in
                if let searchText = backForwardController.currentSearchQuery?.searchText {
                    self.searchField.stringValue = searchText
                    self.searchField.invalidateSize()
                    DispatchQueue.main.async {
                        self.refreshHeight()
                    }
                }
            })
        }
    }

    weak var delegate: SearchBarDelegate?
    var backForwardControllerObservation: Any?

    @IBAction func goAction(_ sender: Any?) {
        delegate?.searchBar(self, didSearchText: searchField.stringValue)
    }

    func setProgress(_ progress: CGFloat) {
        progressIndicator.doubleValue = progress * 100
    }

    var isLoading = false {
        didSet {
            if isLoading {
                progressIndicator.doubleValue = 0
            }
            progressIndicator.isHidden = !isLoading
        }
    }

    @objc
    func focusSearch(_ sender: Any?) {
        view.window?.makeFirstResponder(searchField)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        searchField.delegate = self

        startListeningToUserDefaults()

        setAutogrows(UserDefaults.standard.bool(forKey: "searchBarGrowsToFitContent"))

        view.menu = NSMenu().then {
            $0.addItem(NSMenuItem(title: "Search Bar Grows Vertically",
                                  action: nil,
                                  keyEquivalent: "").then {
                $0.bind(.value,
                        to: NSUserDefaultsController.shared,
                        withKeyPath: "values.searchBarGrowsToFitContent",
                        options: [:])
            })
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        self.searchField.invalidateSize()
        refreshHeight()
    }

    private func startListeningToUserDefaults() {
        NSUserDefaultsController.shared.addObserver(self,
                                                    forKeyPath: "values.searchBarGrowsToFitContent",
                                                    options: .new,
                                                    context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "values.searchBarGrowsToFitContent" else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        setAutogrows(UserDefaults.standard.bool(forKey: "searchBarGrowsToFitContent"))
    }

    private func setAutogrows(_ autogrows: Bool) {
        if view.window?.firstResponder == view.window?.fieldEditor(false, for: searchField) {
            view.window?.makeFirstResponder(nil)
        }

        searchField.autogrows = autogrows
        searchField.lineBreakMode = autogrows ? .byWordWrapping : .byClipping
        searchField.cell?.wraps = autogrows
        searchField.cell?.isScrollable = !autogrows
        searchField.cell?.usesSingleLineMode = !autogrows

        searchField.invalidateSize()
        refreshHeight()
    }

    private func setHeight(_ height: CGFloat) {
        view.frame.size.height = height
        fullScreenMinHeight = height
    }

    private func refreshHeight() {
        self.setHeight(min(self.searchField.intrinsicContentSize.height + 15, 150))
    }
}

extension SearchBarViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        DispatchQueue.main.async {
            self.refreshHeight()
        }
    }
}
