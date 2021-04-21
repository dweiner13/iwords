//
//  LookupViewController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa

class LookupViewController: NSViewController {

    @IBOutlet var textView: NSTextView!

    override class var restorableStateKeyPaths: [String] {
        ["textView.string"]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        textView.font = .monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 24, height: 12)
        textView.string = "Welcome to iWords, a Latin dictionary. Search a word to get started."
    }

    func setResultText(_ text: String) {
        textView.string = text
    }

    @IBAction func didPressHelp(_ sender: Any) {
        guard let bookName = Bundle.main.object(forInfoDictionaryKey: "CFBundleHelpBookName") as? String else {
            return
        }
        NSHelpManager.shared.openHelpAnchor("feedback", inBook: bookName)
    }
}
