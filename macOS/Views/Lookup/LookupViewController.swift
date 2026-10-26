//
//  LookupViewController.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa

class LookupViewController: NSViewController {

    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private var expandedInflections: Set<Int> = []
    private var isObservingDefaults = false
    private var scaleObservation: NSObjectProtocol?

    @IBOutlet weak var welcomeView: NSView!

    var fontSizeController = FontSizeController.shared

    var results: [LookupResult]? {
        didSet {
            expandedInflections.removeAll()
            renderResults()
            if isViewLoaded { textView.scrollRangeToVisible(NSRange(location: 0, length: 0)) }
            invalidateRestorableState()
            updateWelcomeViewVisibility()
        }
    }

    var isLoading = false {
        didSet {
            updateWelcomeViewVisibility()
        }
    }

    func updateWelcomeViewVisibility() {
        guard isViewLoaded else { return }
        welcomeView.isHidden = results != nil || isLoading
        scrollView.isHidden = !welcomeView.isHidden
    }

    @objc
    override func encodeRestorableState(with coder: NSCoder) {
        if let results = results,
           let encoded = try? JSONEncoder().encode(results) {
            coder.encode(encoded, forKey: "resultsJSON")
        }
        super.encodeRestorableState(with: coder)
    }

    @objc
    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let data = coder.decodeObject(of: NSData.self, forKey: "resultsJSON") {
            results = try? JSONDecoder().decode([LookupResult].self,
                                                from: data as Data)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.usesFindBar = true
        textView.delegate = self
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: view.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textView.setAccessibilityLabel("Dictionary results")
        textView.setAccessibilityIdentifier("lookupResults")
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        textView.frame = scrollView.contentView.bounds
        renderResults()

        startListeningToUserDefaults()

        updateWelcomeViewVisibility()

        scaleObservation = NotificationCenter.default.addObserver(forName: .textScaleDidChange,
                                               object: FontSizeController.shared,
                                               queue: .main) { [weak self] notification in
            self?.renderResults()
        }
    }

    private func startListeningToUserDefaults() {
        isObservingDefaults = true
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.showInflections", options: .new, context: nil)
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.prettyFormatOutput", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case "values.showInflections":
            fallthrough
        case "values.prettyFormatOutput":
            renderResults()
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    deinit {
        if let scaleObservation { NotificationCenter.default.removeObserver(scaleObservation) }
        guard isObservingDefaults else { return }
        NSUserDefaultsController.shared.removeObserver(self, forKeyPath: "values.showInflections")
        NSUserDefaultsController.shared.removeObserver(self, forKeyPath: "values.prettyFormatOutput")
    }

    func standardWidthAtCurrentFontSize() -> CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: 13 * CGFloat(fontSizeController.textScale), weight: .regular)
        return (String(repeating: "0", count: 80) as NSString).size(withAttributes: [.font: font]).width + 48
    }

    private func renderResults() {
        guard isViewLoaded else { return }
        let origin = scrollView.contentView.bounds.origin
        let output = ResultsRenderer.render(
            results ?? [],
            scale: CGFloat(fontSizeController.textScale),
            formatted: UserDefaults.standard.bool(forKey: "prettyFormatOutput"),
            showInflections: UserDefaults.standard.bool(forKey: "showInflections"),
            expandedInflections: expandedInflections
        )
        let selection = textView.selectedRange()
        let preservesSelection = textView.string == output.string
        textView.textStorage?.setAttributedString(output)
        if preservesSelection { textView.setSelectedRange(selection) }
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func lookUpInPerseus(_ word: String) {
        let urls = PerseusUtils.urlsForLookUpInPerseus(searchText: word)

        if urls.count >= 50 {
            let alert = NSAlert()
            alert.messageText = "Too Many Words"
            alert.informativeText = "Looking up in Perseus opens a new tab for each word. Your query has \(urls.count) words. Please search for fewer than 50 words."
            alert.runModal()
            return
        }

        if urls.count > 1 && !UserDefaults.standard.bool(forKey: "suppressMultipleTabsAlert") {
            let alert = NSAlert()
            alert.messageText = "Are you sure you want to open \(urls.count) new tabs in your web browser?"
            alert.informativeText = "\(urls.count) tabs to www.perseus.tufts.edu will be opened."
            alert.addButton(withTitle: "Open \(urls.count) Tabs")
            alert.addButton(withTitle: "Cancel")
            alert.showsSuppressionButton = true
            let clicked = alert.runModal()

            if clicked == .alertFirstButtonReturn,
               let suppressionButton = alert.suppressionButton,
               suppressionButton.state == .on {
                UserDefaults.standard.set(true, forKey: "suppressMultipleTabsAlert")
            }

            guard clicked == .alertFirstButtonReturn else {
                return
            }
        }

        urls.forEach {
            NSWorkspace.shared.open($0)
        }
    }

}

extension LookupViewController: NSTextViewDelegate {
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL,
              let index = Int(url.lastPathComponent),
              let results, results.indices.contains(index) else { return false }
        switch url.host {
        case "perseus":
            lookUpInPerseus(results[index].input)
        case "inflections":
            if !expandedInflections.insert(index).inserted {
                expandedInflections.remove(index)
            }
            renderResults()
        default:
            return false
        }
        return true
    }
}

// MARK: - Printing

extension LookupViewController {
    @objc
    func printDocument(_ sender: Any) {
        let printInfo = NSPrintInfo.shared
        printInfo.verticalPagination = .automatic
        printInfo.horizontalPagination = .fit
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.topMargin = 24
        printInfo.leftMargin = 24
        printInfo.bottomMargin = 24
        printInfo.rightMargin = 24

        // Use a separate view so pagination does not resize the onscreen results.
        let width = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        printView.textStorage?.setAttributedString(ResultsRenderer.render(
            results ?? [],
            scale: CGFloat(fontSizeController.textScale),
            formatted: UserDefaults.standard.bool(forKey: "prettyFormatOutput"),
            showInflections: UserDefaults.standard.bool(forKey: "showInflections"),
            expandedInflections: expandedInflections,
            includeActions: false
        ))
        printView.sizeToFit()
        NSPrintOperation(view: printView, printInfo: printInfo).run()
    }

    @objc
    func runPageLayout(_ sender: Any) {
        NSPageLayout().runModal()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        switch aSelector {
        case #selector(printDocument(_:)):
            return results?.isEmpty == false
        default:
            return super.responds(to: aSelector)
        }
    }

    func decreaseTextSize() {
        fontSizeController.decreaseScale(nil)
    }

    func increaseTextSize() {
        fontSizeController.increaseScale(nil)
    }

    func resetTextSize() {
        fontSizeController.resetScale(nil)
    }
}

// MARK: - NSSplitViewDelegate

extension LookupViewController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView,
                   constrainMinCoordinate proposedMinimumPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        38
    }

    func splitView(_ splitView: NSSplitView,
                   constrainSplitPosition proposedPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        let allowedPositions = (0..<6).map {
            CGFloat($0) * 17 + 38
        }
        return allowedPositions.min { lhs, rhs in
            abs(lhs - proposedPosition) < abs(rhs - proposedPosition)
        } ?? proposedPosition
    }
}
