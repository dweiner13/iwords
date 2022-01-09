//
//  LoadingView.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/9/22.
//

import AppKit

class LoadingView: NSView {
    override var wantsUpdateLayer: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func updateLayer() {
        layer!.backgroundColor = NSColor.white.withAlphaComponent(0.5).cgColor
        super.updateLayer()
    }
}
