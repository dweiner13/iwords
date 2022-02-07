//
//  DictionarySettingsHelpViewController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/6/22.
//

import Cocoa

class DictionarySettingsHelpViewController: NSViewController {

    @IBOutlet var textView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let rtfURL = Bundle.main.url(forResource: "Dictionary Settings Help",
                                     withExtension: "rtf")!
        let richText = NSAttributedString(rtf: try! Data(contentsOf: rtfURL),
                                          documentAttributes: nil)!
        textView.textStorage?.setAttributedString(richText)

        textView.textContainerInset = .init(width: 6, height: 8)
    }


    
}
