//
//  LookupViewController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa
import SwiftUI

enum ResultDisplayMode: Int {
    case raw, pretty
}

class LookupViewController: NSViewController {

    @IBOutlet
    weak var textView: NSTextView!

    @IBOutlet
    weak var scrollView: NSScrollView!

    @IBOutlet weak var loadingView: LoadingView!

    @IBOutlet weak var welcomeView: NSView!

    var results: [DictionaryController.Result]? {
        didSet {
            results.map(updateForResults)
            updateWelcomeViewVisibility()
        }
    }

    var isLoading = false {
        didSet {
            updateWelcomeViewVisibility()
            textView.isSelectable = !isLoading
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                loadingView.animator().isHidden = !isLoading
            }
        }
    }

    func updateWelcomeViewVisibility() {
        welcomeView.isHidden = results != nil || isLoading
        scrollView.isHidden = !welcomeView.isHidden
    }

    var mode: ResultDisplayMode {
        get {
            #if DEBUG
            return UserDefaults.standard.bool(forKey: "prettyResults") ? .pretty : .raw
            #else
            return .raw
            #endif
        }
        set {
            switch newValue {
            case .pretty:
                UserDefaults.standard.set(true, forKey: "prettyResults")
            case .raw:
                UserDefaults.standard.removeObject(forKey: "prettyResults")
            }
        }
    }

    private var definitionHostingView: NSView?

    @objc
    override func encodeRestorableState(with coder: NSCoder) {
        if let results = results,
           let encoded = try? JSONEncoder().encode(results) {
            coder.encode(encoded, forKey: "resultsJSON")
        }
        super.encodeRestorableState(with: coder)
    }

    @objc
    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let data = coder.decodeObject(of: NSData.self, forKey: "resultsJSON") {
            results = try? JSONDecoder().decode([DictionaryController.Result].self,
                                                from: data as Data)
        }
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // do nothing
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.textContainerInset = NSSize(width: 8, height: 12)
        textView.delegate = self

        startListeningToUserDefaults()

        updateWelcomeViewVisibility()

        NotificationCenter.default.addObserver(forName: .selectedFontDidChange,
                                               object: AppDelegate.shared,
                                               queue: nil) { [weak self] notification in
            self?.fontChanged()
        }
    }

    private func startListeningToUserDefaults() {
        #if DEBUG
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.prettyResults", options: .new, context: nil)
        #endif
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.showStyledRawResults", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        #if DEBUG
        case "values.prettyResults":
            results.map(updateForResults(_:))
        #endif
        case "values.showStyledRawResults":
            results.map(updateForResults(_:))
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    deinit {
#if DEBUG
        NSUserDefaultsController.shared.removeObserver(self, forKeyPath: "values.prettyResults")
#endif
        NSUserDefaultsController.shared.removeObserver(self, forKeyPath: "values.showStyledRawResults")
    }

    func standardWidthAtCurrentFontSize() -> CGFloat {
        let font = AppDelegate.shared.font
        let string = String(repeating: "a", count: 80)
        let textWidth = (string as NSString).size(withAttributes: [.font: font as Any]).width
        return textWidth + textView.textContainerInset.width * 2 + 24
    }

    func updateForResults(_ results: [DictionaryController.Result]) {
        if UserDefaults.standard.bool(forKey: "showStyledRawResults"),
           let textStorage = textView.textStorage {
            let attrString = DictionaryController.Result.allRawStyled(results, font: AppDelegate.shared.font)
                .let { NSMutableAttributedString(attributedString: $0) }
                .then { $0.addAttributes([.foregroundColor: NSColor.labelColor], range: NSRange(location: 0, length: $0.length)) }
            textStorage.setAttributedString(attrString)
        } else {
            textView.textStorage?.setAttributedString(NSAttributedString(string: DictionaryController.Result.allRaw(results),
                                                                         attributes: [.font: AppDelegate.shared.font,
                                                                                      .foregroundColor: NSColor.labelColor]))
        }

        definitionHostingView?.isHidden = true
        definitionHostingView?.removeFromSuperview()
        definitionHostingView = nil

        if #available(macOS 11.0, *),
           mode == .pretty {
            let hostingView = NSHostingView(rootView: DefinitionsView(definitions: (results.compactMap(\.parsed).flatMap { $0 },
                                                                                    false)))
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: view.topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            definitionHostingView = hostingView
        }

        DispatchQueue.main.async {
            self.scrollView.flashScrollers()
        }

        invalidateRestorableState()
    }

    private func updateForMode() {
        switch mode {
        case .raw:
            textView.isHidden = false
            definitionHostingView?.isHidden = true
        case .pretty:
            textView.isHidden = true
            definitionHostingView?.isHidden = false
        }
        invalidateRestorableState()
    }

    func fontChanged() {
        if let results = results {
            updateForResults(results)
        }
    }

    @IBAction func didChangeMode(_ sender: Any) {
        updateForMode()
    }
}

// MARK: - Printing

extension LookupViewController {
    @objc
    func printDocument(_ sender: Any) {
        let printInfo = NSPrintInfo.shared
        printInfo.verticalPagination = .automatic
        printInfo.horizontalPagination = .fit
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        let printView: NSView
        let width = printInfo.imageablePageBounds.width
        switch mode {
        case .pretty:
            guard #available(macOS 11.0, *) else {
                fallthrough
            }
            let parsedResults = results?.compactMap(\.parsed).flatMap { $0 }
            let hostingView = NSHostingView(rootView: DefinitionsView(definitions: (parsedResults ?? [], false)))
            hostingView.frame = CGRect(x: 0, y: 0, width: width, height: hostingView.intrinsicContentSize.height)
            printView = hostingView
        case .raw:
            let textView = NSTextView(frame: CGRect(x: 0, y: 0, width: width, height: 100))
            results
                .map {
                    DictionaryController.Result.allRawStyled($0, font: AppDelegate.shared.font)
                }
                .map {
                    textView.textStorage?.append($0)
                }

            textView.frame.size.height = textView.intrinsicContentSize.height
            printView = textView
        }

        let op = NSPrintOperation(view: printView, printInfo: printInfo)
        op.canSpawnSeparateThread = true
        op.run()
    }

    @objc
    func runPageLayout(_ sender: Any) {
        NSPageLayout().runModal()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        switch aSelector {
        case #selector(printDocument(_:)):
            return results?.isEmpty == false
        default:
            return super.responds(to: aSelector)
        }
    }
}

// MARK: - NSTextViewDelegate

extension LookupViewController: NSTextViewDelegate {
    func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        guard !selectedText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return menu
        }
        menu.insertItem(NSMenuItem(title: "Look Up (Latin → English)",
                                   action: #selector(LookupWindowController.search(_:)),
                                   keyEquivalent: "").then { $0.tag = Dictionary.Direction.latinToEnglish.rawValue; $0.representedObject = selectedText() },
                        at: 0)
        menu.insertItem(NSMenuItem(title: "Look Up (English → Latin)",
                                   action: #selector(LookupWindowController.search(_:)),
                                   keyEquivalent: "").then { $0.tag = Dictionary.Direction.englishToLatin.rawValue; $0.representedObject = selectedText() },
                        at: 1)
        menu.insertItem(NSMenuItem(title: "Look Up in Perseus",
                                   action: #selector(LookupWindowController.lookUpInPerseus(_:)),
                                   keyEquivalent: "").then { $0.representedObject = selectedText() },
                        at: 2)
        menu.insertItem(NSMenuItem.separator(),
                        at: 3)
        return menu
    }

    private func selectedText() -> String {
        let range = textView.selectedRange()
        guard let substring = textView.textStorage?.attributedSubstring(from: range),
              substring.length > 0 else {
            return ""
        }
        return substring.string
    }
}

// MARK: - NSSplitViewDelegate

extension LookupViewController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView,
                   constrainMinCoordinate proposedMinimumPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        38
    }

    func splitView(_ splitView: NSSplitView,
                   constrainSplitPosition proposedPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        let allowedPositions = (0..<6).map {
            CGFloat($0) * 17 + 38
        }
        return allowedPositions.min { lhs, rhs in
            abs(lhs - proposedPosition) < abs(rhs - proposedPosition)
        } ?? proposedPosition
    }
}
