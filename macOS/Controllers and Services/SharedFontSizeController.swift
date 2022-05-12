//
//  SharedFontSizeController.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 5/3/22.
//

import AppKit

// For IB use. Proxies everything to the shared FontSizeController object.
class SharedFontSizeController: NSObject {

    // MARK: Properties

    var sharedController = FontSizeController.shared

    @IBOutlet
    var segmentedControl: NSSegmentedControl?

    // MARK: Methods

    override init() {
        super.init()
        // TODO: trying to fix memory leak. Remove every observer everywhere and see if crash still
        // happens. Best guess right now is that the memory leak is what prevented the crash from
        // happening. Fixing the memory leak caused the crash to start, reverting it prevents the
        // crash from happening.
        NotificationCenter.default.addObserver(forName: .textScaleDidChange,
                                               object: sharedController,
                                               queue: nil) { [weak self] notification in
            self?.updateSegmentedControl()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        updateSegmentedControl()
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

    // MARK: IBActions

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
            preconditionFailure("Only segmented controls with 2 (for -/+) or 3 (for -/reset/+) segments are supported.")
        }
    }

    // MARK: Private methods

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
}
