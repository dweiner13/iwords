//
//  WindowRestoration.swift
//  words (macOS)
//
//  Created by Dan Weiner on 4/18/21.
//

import Cocoa

@MainActor
class WindowRestoration: NSObject, NSWindowRestoration {
    static func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier,
                              state: NSCoder,
                              completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        let window = LookupWindowController.newController().window
        window?.identifier = identifier
        completionHandler(window, nil)
    }
}
