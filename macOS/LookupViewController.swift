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

    var results: [DictionaryController.Result]? {
        didSet {
            results.map(updateForResults)
        }
    }

    @IBOutlet
    weak var progressIndicator: NSProgressIndicator!

    func setLoading(_ loading: Bool) {
        if loading {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                loadingView.animator().isHidden = false
            }
            textView.isSelectable = false
            progressIndicator.startAnimation(self)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                loadingView.animator().isHidden = true
            }
            textView.isSelectable = true
            progressIndicator.stopAnimation(self)
        }
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

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.textContainerInset = NSSize(width: 8, height: 12)
        setHelpText()

        #if DEBUG
        startListeningToUserDefaults()
        #endif
    }

    #if DEBUG
    private func startListeningToUserDefaults() {
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.prettyResults", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "values.prettyResults" else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        results.map(updateForResults)
    }
    #endif

    func standardWidthAtCurrentFontSize() -> CGFloat {
        let font = AppDelegate.shared.font
        let string = String(repeating: "a", count: 80)
        let textWidth = (string as NSString).size(withAttributes: [.font: font as Any]).width
        return textWidth + textView.textContainerInset.width * 2 + 24
    }

    func updateForResults(_ results: [DictionaryController.Result]) {
        if let textStorage = textView.textStorage {
            let attrString = DictionaryController.Result.allRawStyled(results, font: AppDelegate.shared.font)
                .let { NSMutableAttributedString(attributedString: $0) }
                .then { $0.addAttributes([.foregroundColor: NSColor.labelColor], range: NSRange(location: 0, length: $0.length)) }
            textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length),
                                          with: attrString)
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
        } else {
            setHelpText()
        }
    }

    @IBAction func didChangeMode(_ sender: Any) {
        updateForMode()
    }

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

    private func setHelpText() {
        func helpText() -> NSAttributedString {
            let str = NSMutableAttributedString(string: "Welcome to iWords, a Latin dictionary. Search a word to get started.\n", attributes: [.font: AppDelegate.shared.font])
            str.append(NSAttributedString(string: """

                                                 *
                                                 """ + " ",
                                          attributes: [
                                            .font: AppDelegate.shared.font,
                                            .foregroundColor: NSColor.labelColor]))
            str.append(NSAttributedString(string: "View help",
                                          attributes: [
                                            .link: URL(string: "iwords:help")!,
                                            .font: AppDelegate.shared.font,
                                            .foregroundColor: NSColor.labelColor]))
            str.append(NSAttributedString(string: """

                                                 *
                                                 """ + " ",
                                          attributes: [
                                            .font: AppDelegate.shared.font,
                                            .foregroundColor: NSColor.labelColor]))
            str.append(NSAttributedString(string: "Send feedback",
                                          attributes: [
                                            .link: URL(string: "iwords:feedback")!,
                                            .font: AppDelegate.shared.font,
                                            .foregroundColor: NSColor.labelColor]))
            return str
        }

        if let textStorage = textView.textStorage {
            textStorage.setAttributedString(helpText())
        }
    }
}
