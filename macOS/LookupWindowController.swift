//
//  LookupWindowController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa

class LookupWindowController: NSWindowController {

    @IBOutlet weak var popUpButton: NSPopUpButton!
    @IBOutlet weak var searchField: NSSearchField!

    private var direction: Dictionary.Direction {
        let raw = UserDefaults.standard.integer(forKey: "translationDirection")
        return Dictionary.Direction(rawValue: raw)!
    }

    private var lookupViewController: LookupViewController! {
        contentViewController as? LookupViewController
    }

    @IBAction
    private func searchFieldAction(_ field: NSSearchField) {
        search(field.stringValue)
    }

    private func search(_ searchText: String) {
        do {
            let results = try Dictionary.shared.getDefinition(searchText, direction: direction)
            lookupViewController.setResultText(results ?? "No results found")
        } catch {
            self.presentError(error)
        }
    }
}
