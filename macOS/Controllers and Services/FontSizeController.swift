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

class FontSizeController: NSObject {
    static let scaleUserInfoKey = "scale"
    static let shared = FontSizeController()

    // MARK: Properties

    public private(set) var textScale: Float = 1

    public var canDecreaseScale: Bool {
        textScale > 0.6
    }

    public var canIncreaseScale: Bool {
        textScale < 5
    }

    public var canResetScale: Bool {
        return textScale > (kStepMultiplier * 0.95) || textScale < (1 / (kStepMultiplier * 0.95))
    }

    private let kStepMultiplier: Float = 1.1

    // MARK: Methods

    private override init() {
        textScale = UserDefaults.standard.float(forKey: "webViewTextSizeMultiplier")
        super.init()
        notify()
    }

    // MARK: IBActions

    @IBAction
    public func increaseScale(_ sender: Any?) {
        guard canIncreaseScale else {
            return
        }
        if textScale < 0.6 {
            textScale = 0.6
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

    // MARK: Private methods

    private func notify() {
        NotificationCenter.default.post(name: .textScaleDidChange,
                                        object: self,
                                        userInfo: ["scale": textScale])
    }
}
