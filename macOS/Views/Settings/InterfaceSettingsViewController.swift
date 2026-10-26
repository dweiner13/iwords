//
//  InterfaceSettingsViewController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/17/22.
//

import AppKit

class InterfaceSettingsViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        preferredContentSize = NSSize(width: SETTINGS_WINDOW_WIDTH, height: view.fittingSize.height)
    }
}
