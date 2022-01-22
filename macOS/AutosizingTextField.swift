//
//  AutosizingTextField.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/16/22.
//

import Cocoa

// Stolen from https://stackoverflow.com/a/47234344
class AutoGrowingTextField: NSTextField {

    var minHeight: CGFloat? = 23
    let bottomSpace: CGFloat = 7
    // magic number! (the field editor TextView is offset within the NSTextField. It’s easy to get the space above (it’s origin), but it’s difficult to get the default spacing for the bottom, as we may be changing the height

    var heightLimit: CGFloat?
    var lastSize: NSSize?
    var isEditing = false

    var autogrows = true

    @objc
    dynamic var needsRecalculateSize = false

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        isEditing = true
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        isEditing = false
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        self.invalidateIntrinsicContentSize()
    }

    // Added by me :)
    func invalidateSize() {
        self.invalidateIntrinsicContentSize()
        self.needsRecalculateSize = true
    }

    override var intrinsicContentSize: NSSize {
        var minSize: NSSize {
            var size = super.intrinsicContentSize
            size.height = minHeight ?? 0
            return size
        }

        defer {
            needsRecalculateSize = false
        }

        // Only update the size if we’re editing the text, or if we’ve not set it yet
        // If we try and update it while another text field is selected, it may shrink back down to only the size of one line (for some reason?)
        if isEditing || lastSize == nil || needsRecalculateSize {
            let hPadding: CGFloat = 12

            let text = stringValue
            let attributedText = NSAttributedString(string: text, attributes: [.font: font as Any])
            let boundingRect = attributedText.boundingRect(with: NSSize(width: frame.width - hPadding, height: 99999),
                                                           options: autogrows ? [.usesFontLeading, .usesLineFragmentOrigin] : [])
            let newHeight = boundingRect.height

            var newSize = super.intrinsicContentSize
            newSize.height = newHeight + bottomSpace

            if let heightLimit = heightLimit, let lastSize = lastSize, newSize.height > heightLimit {
                newSize = lastSize
            }

            if let minHeight = minHeight, newSize.height < minHeight {
                newSize.height = minHeight
            }

            lastSize = newSize
            return newSize
        }
        else {
            return lastSize ?? minSize
        }
    }
}
