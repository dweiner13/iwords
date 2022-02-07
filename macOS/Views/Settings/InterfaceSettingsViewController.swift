//
//  InterfaceSettingsViewController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/17/22.
//

import AppKit

private extension NSFont {
    func settingsDisplayString() -> String {
        (displayName ?? "Unknown Font") + " " + (String(format: "%.0f", pointSize)) + "pt"
    }
}

class InterfaceSettingsViewController: NSViewController {

    @IBOutlet
    weak var fontButton: NSButton!

    @IBOutlet
    weak var fontTextField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        updateForFont(NSFontManager.shared.selectedFont)

        NotificationCenter.default.addObserver(forName: .selectedFontDidChange,
                                               object: AppDelegate.shared,
                                               queue: nil) { [weak self] notification in
            let font = notification.userInfo?[SelectedFontDidChangeFontKey] as? NSFont
            self?.updateForFont(font)
        }

        preferredContentSize = view.fittingSize.then {
            $0.width = SETTINGS_WINDOW_WIDTH
        }
    }

    private func updateForFont(_ font: NSFont?) {
        if let font = font {
            fontTextField.isHidden = false
            fontTextField.stringValue = font.settingsDisplayString()
            fontTextField.font = font
        } else {
            fontTextField.isHidden = true
        }
    }
}
