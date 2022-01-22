//
//  FontSizeSegmentedControl.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/8/22.
//

import Cocoa

class FontSizeSegmentedControl: NSSegmentedControl {

    override var tag: Int {
        set {

        }
        get {
            switch selectedSegment {
            case 0:
                return Int(NSFontAction.sizeDownFontAction.rawValue)
            case 1:
                return Int(NSFontAction.sizeUpFontAction.rawValue)
            default:
                return -1
            }
        }
    }
    
}
