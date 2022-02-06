//
//  DictionarySettingsViewController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/6/22.
//

import Cocoa

let SETTINGS_WINDOW_WIDTH: CGFloat = 500

class DictionarySettingsViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        preferredContentSize = view.fittingSize.then {
            $0.width = SETTINGS_WINDOW_WIDTH
        }
    }
    
}
