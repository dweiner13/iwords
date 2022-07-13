//
//  WindowRestoration.swift
//  words (macOS)
//
//  Created by Dan Weiner on 4/18/21.
//

import Cocoa

class WindowRestoration: NSObject, NSWindowRestoration {
    static func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier,
                              state: NSCoder,
                              completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        // TODO: dw restore
//        completionHandler(LookupWindowController.newController().window, nil)
    }
}
