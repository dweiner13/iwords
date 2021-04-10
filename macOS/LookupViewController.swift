//
//  LookupViewController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa

class LookupViewController: NSViewController {

    @IBOutlet var textView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        textView.font = .monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 24, height: 12)
    }

    func setResultText(_ text: String) {
        textView.string = text
    }
}
