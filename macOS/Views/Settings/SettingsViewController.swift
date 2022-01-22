//
//  SettingsViewController.swift
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

class SettingsViewController: NSViewController {

    @IBOutlet
    weak var fontButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        updateForFont(NSFontManager.shared.selectedFont)

        NotificationCenter.default.addObserver(forName: .selectedFontDidChange,
                                               object: AppDelegate.shared,
                                               queue: nil) { [weak self] notification in
            let font = notification.userInfo?[SelectedFontDidChangeFontKey] as? NSFont
            self?.updateForFont(font)
        }
    }

    private func updateForFont(_ font: NSFont?) {
        if let font = font {
            fontButton.title = font.settingsDisplayString()
        } else {
            fontButton.title = "Select..."
        }
    }
}
