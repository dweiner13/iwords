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

    private var webView: WebView!

    @IBOutlet weak var welcomeView: NSView!

    var fontSizeController = FontSizeController.shared

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

        webView = WebView(frame: view.bounds)
        webView.setMaintainsBackForwardList(false)
        webView.textSizeMultiplier = fontSizeController.textScale
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        webView.drawsBackground = false
        webView.frameLoadDelegate = self

        let url = Bundle.main.url(forResource: "results-page", withExtension: "html")!
        webView.mainFrame.load(URLRequest(url: url))

        startListeningToUserDefaults()

        updateWelcomeViewVisibility()

        NotificationCenter.default.addObserver(forName: .textScaleDidChange,
                                               object: FontSizeController.shared,
                                               queue: nil) { [weak self] notification in
            self?.webView.textSizeMultiplier = notification.userInfo![FontSizeController.scaleUserInfoKey] as! Float
        }
    }

    private func startListeningToUserDefaults() {
        #if DEBUG
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.prettyResults", options: .new, context: nil)
        #endif
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.groupDefinitions", options: .new, context: nil)
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.showInflections", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        #if DEBUG
        case "values.prettyResults":
            fallthrough
        #endif
        case "values.groupDefinitions":
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
        NSUserDefaultsController.shared.removeObserver(self, forKeyPath: "values.groupDefinitions")
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
    }

    func showResultsInWebView(_ results: [DictionaryController.Result]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try! encoder.encode(results)
        let str = String(data: encoded, encoding: .utf8)!
        let js = """
            showResults({
                queries: \(str),
                showInflections: \(String(UserDefaults.standard.bool(forKey: "showInflections"))),
                groupDefinitions: \(String(UserDefaults.standard.bool(forKey: "groupDefinitions")))
            })
            """
        print(js)
        webView.stringByEvaluatingJavaScript(from: js)
    }

    func fontChanged() {
        if let results = results {
            updateForResults(results)
        }
    }

    // Called from JS in web view
    @objc
    func webViewDidLoad() {
        results.map(showResultsInWebView(_:))
    }

    override class func isSelectorExcluded(fromWebScript selector: Selector!) -> Bool {
        if selector == #selector(webViewDidLoad) {
            return false
        }

        return true
    }
}

extension LookupViewController: WebFrameLoadDelegate {

    func webView(_ webView: WebView!, didClearWindowObject windowObject: WebScriptObject!, for frame: WebFrame!) {
        windowObject.setValue(self, forKey: "iWordsDelegate")
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
        printInfo.topMargin = 24
        printInfo.leftMargin = 24
        printInfo.bottomMargin = 24
        printInfo.rightMargin = 24

        webView.mainFrame.frameView.printOperation(with: printInfo).run()
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

    func decreaseTextSize() {
        webView.makeTextSmaller(nil)
        print("new text size: \(webView.textSizeMultiplier)")
    }

    func increaseTextSize() {
        webView.makeTextLarger(nil)
        print("new text size: \(webView.textSizeMultiplier)")
    }

    func resetTextSize() {
        webView.textSizeMultiplier = 1
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
