//
//  FontSizeController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 3/6/22.
//

import Foundation
import AppKit

extension NSNotification.Name {
    static let textScaleDidChange = NSNotification.Name("textScaleDidChange")
}

// For IB use only.
class SharedFontSizeController: NSObject {
    var sharedController = FontSizeController.shared

    @IBOutlet
    var segmentedControl: NSSegmentedControl?

    @IBAction
    public func increaseScale(_ sender: Any?) {
        sharedController.increaseScale(sender)
    }

    @IBAction
    public func decreaseScale(_ sender: Any?) {
        sharedController.decreaseScale(sender)
    }

    @IBAction
    public func resetScale(_ sender: Any?) {
        sharedController.resetScale(sender)
    }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: .textScaleDidChange,
                                               object: sharedController,
                                               queue: nil) { notification in
            self.updateSegmentedControl()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        updateSegmentedControl()
    }

    private func updateSegmentedControl() {
        guard let segmentedControl = segmentedControl else {
            return
        }

        segmentedControl.setEnabled(sharedController.canDecreaseScale, forSegment: 0)
        if segmentedControl.segmentCount == 2 {
            segmentedControl.setEnabled(sharedController.canIncreaseScale, forSegment: 1)
        } else {
            segmentedControl.setEnabled(sharedController.canResetScale, forSegment: 1)
        }

        if segmentedControl.segmentCount == 3 {
            segmentedControl.setEnabled(sharedController.canIncreaseScale, forSegment: 2)
        }
    }

    override func responds(to aSelector: Selector!) -> Bool {
        switch aSelector {
        case #selector(increaseScale(_:)):
            return sharedController.canIncreaseScale
        case #selector(decreaseScale(_:)):
            return sharedController.canDecreaseScale
        case #selector(resetScale(_:)):
            return sharedController.canResetScale
        default:
            return super.responds(to: aSelector)
        }
    }

    @IBAction
    func didSelectSegmentedControl(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            decreaseScale(sender)
        case 1:
            if sender.segmentCount == 2 {
                increaseScale(sender)
            } else {
                resetScale(sender)
            }
        case 2:
            increaseScale(sender)
        default:
            preconditionFailure("Only segmented controls with 2 or 3 segments are supported.")
        }
    }
}

class FontSizeController: NSObject {
    static let scaleUserInfoKey = "scale"

    private let kStepMultiplier: Float = 1.1

    public private(set) var textScale: Float = 1 {
        didSet {
            print("textScale changed to \(textScale)")
        }
    }

    static let shared = FontSizeController()

    private override init() {
        textScale = UserDefaults.standard.float(forKey: "webViewTextSizeMultiplier")
        super.init()
        notify()
    }

    public var canDecreaseScale: Bool {
        textScale > 0.6
    }

    public var canIncreaseScale: Bool {
        textScale < 5
    }

    public var canResetScale: Bool {
        return textScale > (kStepMultiplier * 0.95) || textScale < (1 / (kStepMultiplier * 0.95))
    }

    @IBAction
    public func increaseScale(_ sender: Any?) {
        guard canIncreaseScale else {
            return
        }
        textScale *= kStepMultiplier
        UserDefaults.standard.set(textScale, forKey: "webViewTextSizeMultiplier")
        notify()
    }

    @IBAction
    public func decreaseScale(_ sender: Any?) {
        guard canDecreaseScale else {
            return
        }
        textScale /= kStepMultiplier
        UserDefaults.standard.set(textScale, forKey: "webViewTextSizeMultiplier")
        notify()
    }

    @IBAction
    public func resetScale(_ sender: Any?) {
        textScale = 1
        UserDefaults.standard.set(textScale, forKey: "webViewTextSizeMultiplier")
        notify()
    }

    private func notify() {
        NotificationCenter.default.post(name: .textScaleDidChange,
                                        object: self,
                                        userInfo: ["scale": textScale])
    }
}
