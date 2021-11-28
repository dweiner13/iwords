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

    @IBOutlet
    var fontSizeController: FontSizeController!

    @objc
    dynamic var text: String? {
        didSet {
            updateForResultText(text ?? "")
        }
    }

    var results: [ResultItem]?

    var mode: ResultDisplayMode {
        get {
            #if DEBUG
            return ResultDisplayMode(rawValue: UserDefaults.standard.integer(forKey: "resultDisplayMode"))!
            #endif
            return .raw
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "resultDisplayMode")
        }
    }

    private var definitionHostingView: NSView?

    override class var restorableStateKeyPaths: [String] {
        ["text"]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.textContainerInset = NSSize(width: 24, height: 12)
        textView.string = "Welcome to iWords, a Latin dictionary. Search a word to get started."

        setFontSize(fontSizeController.fontSize)
    }

    func standardWidthAtCurrentFontSize() -> CGFloat {
        let font = textView.font
        let string = String(repeating: "a", count: 80)
        let textWidth = (string as NSString).size(withAttributes: [.font: font as Any]).width
        return textWidth + textView.textContainerInset.width * 2 + 24
    }

    private func updateForResultText(_ text: String) {
        textView.string = text

        definitionHostingView?.isHidden = true
        definitionHostingView?.removeFromSuperview()
        definitionHostingView = nil
        
        if #available(macOS 11.0, *),
           let (results, isTruncated) = parse(text) {
            let definitions = results.compactMap(\.definition)
            self.results = results
            let hostingView = NSHostingView(rootView: DefinitionsView(definitions: (results, isTruncated))
                                        .environmentObject(fontSizeController))
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: view.topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            definitionHostingView = hostingView
        } else {
            self.results = nil
            mode = .raw
        }

        updateForMode()
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
    }

    private func setFontSize(_ fontSize: CGFloat) {
        textView.font = NSFont(name: "Monaco", size: fontSize)
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
            let hostingView = NSHostingView(rootView: DefinitionsView(definitions: (results ?? [], false))
                                                .environmentObject(fontSizeController))
            hostingView.frame = CGRect(x: 0, y: 0, width: width, height: hostingView.intrinsicContentSize.height)
            printView = hostingView
        case .raw:
            let textView = NSTextView(frame: CGRect(x: 0, y: 0, width: width, height: 100))
            textView.string = text ?? "(nil)"
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
            switch mode {
            case .pretty: return results?.isEmpty == false
            case .raw: return text != nil
            }
        default:
            return super.responds(to: aSelector)
        }
    }
}

extension LookupViewController: FontSizeControllerDelegate {
    func fontSizeController(_ controller: FontSizeController, fontSizeChangedTo fontSize: CGFloat) {
        setFontSize(fontSize)
    }
}
