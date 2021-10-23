//
//  File.swift
//  words (macOS)
//
//  Created by Dan Weiner on 10/23/21.
//

import AppKit

private let kFontSizeKey = "FontSize"

@objc
protocol FontSizeControllerDelegate: AnyObject {
    func fontSizeController(_ controller: FontSizeController, fontSizeChangedTo fontSize: CGFloat)
}

class FontSizeController: NSObject {

    @IBOutlet
    weak var delegate: FontSizeControllerDelegate?

    /// Attach a pre-configured 2-segment Segmented Control to this controller to have the
    /// controller manage the enabled/disabled states of the segments.
    @IBOutlet
    var segmentedControl: NSSegmentedControl? {
        didSet {
            updateSegmentedControl()
        }
    }

    var fontSize: CGFloat {
        CGFloat(_fontSize)
    }

    private let defaultSize: Int = 12
    private let sizeRange: ClosedRange<Int> = 9...22

    private var _fontSize: Int {
        get {
            let size = UserDefaults.standard.integer(forKey: kFontSizeKey)
            return size > 0 ? size : defaultSize
        } set {
            UserDefaults.standard.set(newValue, forKey: kFontSizeKey)
            delegate?.fontSizeController(self, fontSizeChangedTo: CGFloat(newValue))
            updateSegmentedControl()
        }
    }

    override init() {
        super.init()
        UserDefaults.standard.addObserver(self, forKeyPath: kFontSizeKey, options: [], context: nil)
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == kFontSizeKey else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        delegate?.fontSizeController(self, fontSizeChangedTo: fontSize)
    }

    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: kFontSizeKey)
    }

    @objc
    var canIncrease: Bool {
        sizeRange.contains(_fontSize + 1)
    }

    @objc
    var canDecrease: Bool {
        sizeRange.contains(_fontSize - 1)
    }

    @objc
    var canReset: Bool {
        _fontSize != defaultSize
    }

    @IBAction
    func reset(_ sender: Any) {
        _fontSize = defaultSize
    }

    @IBAction
    func increase(_ sender: Any?) {
        guard canIncrease else { return }
        _fontSize = _fontSize + 1
    }

    @IBAction
    func decrease(_ sender: Any?) {
        guard canDecrease else { return }
        _fontSize = _fontSize - 1
    }

    @IBAction
    func segmentedControlPressed(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: decrease(sender)
        case 1: increase(sender)
        default: return
        }
    }

    private func updateSegmentedControl() {
        segmentedControl?.setEnabled(canDecrease, forSegment: 0)
        segmentedControl?.setEnabled(canIncrease, forSegment: 1)
    }
}
