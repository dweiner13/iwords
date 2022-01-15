//
//  SearchBarViewController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/15/22.
//

import Cocoa
import Combine

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

    var backForwardController: BackForwardController? {
        didSet {
            backForwardControllerCancellable = nil
            backForwardControllerCancellable = backForwardController?
                .$currentSearchQuery
                .sink {
                    if let searchText = $0?.searchText {
                        self.searchField.stringValue = searchText
                        self.searchField.invalidateSize()
                        DispatchQueue.main.async {
                            self.refreshHeight()
                        }
                    }
                }
        }
    }

    weak var delegate: SearchBarDelegate?
    var backForwardControllerCancellable: AnyCancellable?

    @IBAction func goAction(_ sender: Any?) {
        delegate?.searchBar(self, didSearchText: searchField.stringValue)
    }

    @objc
    func focusSearch(_ sender: Any?) {
        view.window?.makeFirstResponder(searchField)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        searchField.delegate = self

        startListeningToUserDefaults()

        searchField.autogrows = UserDefaults.standard.bool(forKey: "searchBarGrowsToFitContent")

        view.menu = NSMenu().then {
            $0.addItem(NSMenuItem(title: "Search Bar Grows to Fit Content",
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
        searchField.autogrows = UserDefaults.standard.bool(forKey: "searchBarGrowsToFitContent")
        self.searchField.invalidateSize()
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
