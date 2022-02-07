//
//  UpdateSettingsViewController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 2/6/22.
//

import Cocoa

class UpdateSettingsViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        preferredContentSize = view.fittingSize.then {
            $0.width = SETTINGS_WINDOW_WIDTH
        }
    }
    
}
