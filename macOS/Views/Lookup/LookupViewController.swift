//
//  LookupViewController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa
import SwiftUI
import WebKit

enum ResultDisplayMode: Int {
    case raw, pretty
}

class LookupViewController: NSViewController {

    @IBOutlet weak var webView: WKWebView!

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
        }
    }

    func updateWelcomeViewVisibility() {
        welcomeView.isHidden = results != nil || isLoading
        webView.isHidden = !welcomeView.isHidden
    }

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

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.configuration.userContentController.add(self, name: "windowDidLoad")

        let url = Bundle.main.url(forResource: "results-page", withExtension: "html")!
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())

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
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.showInflections", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        #if DEBUG
        case "values.prettyResults":
            fallthrough
        #endif
        case "values.showStyledRawResults":
            fallthrough
        case "values.showInflections":
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
        NSUserDefaultsController.shared.removeObserver(self, forKeyPath: "values.showInflections")
    }

    func standardWidthAtCurrentFontSize() -> CGFloat {
        // TODO: fix
        return 300
//        let font = AppDelegate.shared.font
//        let string = String(repeating: "a", count: 80)
//        let textWidth = (string as NSString).size(withAttributes: [.font: font as Any]).width
//        return textWidth + textView.textContainerInset.width * 2 + 24
    }

    func updateForResults(_ results: [DictionaryController.Result]) {
        showResultsInWebView(results)
        invalidateRestorableState()
        // TODO: fix
//        if UserDefaults.standard.bool(forKey: "showStyledRawResults"),
//           let textStorage = textView.textStorage {
//            let attrString = DictionaryController.Result.parsedStyled(results, font: AppDelegate.shared.font)
//                .let { NSMutableAttributedString(attributedString: $0) }
//                .then { $0.addAttributes([.foregroundColor: NSColor.labelColor], range: NSRange(location: 0, length: $0.length)) }
//            textStorage.setAttributedString(attrString)
//        } else {
//            textView.textStorage?.setAttributedString(NSAttributedString(string: DictionaryController.Result.allRaw(results),
//                                                                         attributes: [.font: AppDelegate.shared.font,
//                                                                                      .foregroundColor: NSColor.labelColor]))
//        }

//        DispatchQueue.main.async {
//            self.webView.flashScrollers()
//        }

//        invalidateRestorableState()
    }

    func showResultsInWebView(_ results: [DictionaryController.Result]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try! encoder.encode(results)
        let str = String(data: encoded, encoding: .utf8)!
//        print(str)

        webView.evaluateJavaScript(
            """
            showResults({
                queries: \(str),
                showInflections: \(String(UserDefaults.standard.bool(forKey: "showInflections")))
            })
            """,
            completionHandler: { result, error in
                print("webkit error:", error)
            }
        )
//        webView.callAsyncJavaScript("showResults({ results: \(str) }})", arguments: [:], in: nil, in: .page, completionHandler: nil)
    }

    func fontChanged() {
        if let results = results {
            updateForResults(results)
        }
    }
}

extension LookupViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        results.map(showResultsInWebView(_:))
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

        // TODO: webkit printing broken >:(
        if #available(macOS 11.0, *) {
            let op = webView.printOperation(with: printInfo)
            op.view?.frame = webView.bounds
            op.run()
        } else {
            // TODO: Fallback on earlier versions
        }
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
        guard #available(macOS 10.15.4, *) else {
            return ""
        }

        let range = webView.firstSelectedRange
        print(range)
        return ""
//        guard let substring = textView.textStorage?.attributedSubstring(from: range),
//              substring.length > 0 else {
//            return ""
//        }
//        return substring.string
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
