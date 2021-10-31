//
//  LookupViewController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa
import SwiftUI

enum ResultDisplayMode: Int {
    case pretty, raw
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

    @IBOutlet weak var displayModeControl: NSSegmentedControl!

    var mode: ResultDisplayMode {
        get {
            ResultDisplayMode(rawValue: displayModeControl.selectedSegment)!
        }
        set {
            displayModeControl.selectedSegment = newValue.rawValue
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
           let (definitions, truncated) = parse(text) {
            displayModeControl.setEnabled(true, forSegment: 0)
            let hostingView = NSHostingView(rootView: DefinitionsView(definitions: (definitions, truncated))
                                        .environmentObject(fontSizeController))
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalToSystemSpacingBelow: displayModeControl.bottomAnchor, multiplier: 1),
                hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            definitionHostingView = hostingView
        } else {
            mode = .raw
            displayModeControl.setEnabled(false, forSegment: 0)
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
}

extension LookupViewController: FontSizeControllerDelegate {
    func fontSizeController(_ controller: FontSizeController, fontSizeChangedTo fontSize: CGFloat) {
        setFontSize(fontSize)
    }
}
