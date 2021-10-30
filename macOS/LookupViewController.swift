//
//  LookupViewController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa

class LookupViewController: NSViewController {

    @IBOutlet
    var textView: NSTextView!

    @IBOutlet
    var fontSizeController: FontSizeController!

    override class var restorableStateKeyPaths: [String] {
        ["textView.string"]
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

    func setResultText(_ text: String) {
        textView.string = text
    }

    private func setFontSize(_ fontSize: CGFloat) {
        textView.font = NSFont(name: "Monaco", size: fontSize)
    }

    @IBAction func didPressHelp(_ sender: Any) {
        guard let bookName = Bundle.main.object(forInfoDictionaryKey: "CFBundleHelpBookName") as? String else {
            return
        }
        NSHelpManager.shared.openHelpAnchor("feedback", inBook: bookName)
    }
}

extension LookupViewController: FontSizeControllerDelegate {
    func fontSizeController(_ controller: FontSizeController, fontSizeChangedTo fontSize: CGFloat) {
        setFontSize(fontSize)
    }
}
