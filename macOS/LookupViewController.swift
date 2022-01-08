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
    var textView: NSTextView!

    var results: [DictionaryController.Result]? {
        didSet {
            results.map(updateForResults)
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
            print("Successfully encoded results")
        }
        super.encodeRestorableState(with: coder)
    }

    @objc
    override func restoreState(with coder: NSCoder) {
        if let data = coder.decodeObject(of: NSData.self, forKey: "resultsJSON") {
            results = try? JSONDecoder().decode([DictionaryController.Result].self,
                                                from: data as Data)
            print("Successfully decoded results")
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
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.string = "Welcome to iWords, a Latin dictionary. Search a word to get started.\n"
        textView.font = AppDelegate.shared.font
        appendHelpText()

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
        let font = textView.font
        let string = String(repeating: "a", count: 80)
        let textWidth = (string as NSString).size(withAttributes: [.font: font as Any]).width
        return textWidth + textView.textContainerInset.width * 2 + 24
    }

    func updateForResults(_ results: [DictionaryController.Result]) {
        textView.string = DictionaryController.Result.allRaw(results)

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

    func setFont(_ font: NSFont) {
        textView.font = font
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
            textView.string = results.map(DictionaryController.Result.allRaw(_:)) ?? "(nil)"
            textView.font = self.textView.font
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

    private func appendHelpText() {
        func helpText() -> NSAttributedString {
            let str = NSMutableAttributedString()
            str.append(NSAttributedString(string: """

                                                 *
                                                 """ + " ",
                                          attributes: [
                                            .font: textView.font!,
                                            .foregroundColor: textView.textColor!]))
            str.append(NSAttributedString(string: "View help",
                                          attributes: [
                                            .link: URL(string: "iwords:help")!,
                                            .font: textView.font!,
                                            .foregroundColor: textView.textColor!]))
            str.append(NSAttributedString(string: """

                                                 *
                                                 """ + " ",
                                          attributes: [
                                            .font: textView.font!,
                                            .foregroundColor: textView.textColor!]))
            str.append(NSAttributedString(string: "Send feedback",
                                          attributes: [
                                            .link: URL(string: "iwords:feedback")!,
                                            .font: textView.font!,
                                            .foregroundColor: textView.textColor!]))
            return str
        }

        textView.textStorage?.append(helpText())
    }
}
