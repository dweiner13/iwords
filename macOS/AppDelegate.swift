//
//  AppDelegate.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Cocoa
import Intents
import DWUtils
import Flow
import Sparkle

extension NSFont {
    static let `default` = NSFont(name: "Menlo", size: 13)!
}

extension NSNotification.Name {
    static let selectedFontDidChange = NSNotification.Name("selectedFontDidChange")
}

let SelectedFontDidChangeFontKey = "font"

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var shared: AppDelegate!

    @IBOutlet weak var latinToEnglishItem: NSMenuItem!
    @IBOutlet weak var englishToLatinItem: NSMenuItem!

    private var keyWindowDirection: Dictionary.Direction {
        get {
            keyWindowController()?.dictionaryController.direction ?? DEFAULT_DIRECTION
        }
    }

    var windowDidBecomeKey: Any?
    var windowDidCloseObservation: Any?

    override init() {
        super.init()
        guard Self.shared == nil else {
            fatalError()
        }
        Self.shared = self
    }

    func keyWindowController() -> LookupWindowController? {
        NSApp.keyWindow?.windowController as? LookupWindowController
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        DictionaryRelocator.initialize()

        registerDefaults()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugDefaults.check()

        setUpFont()

        #if DEBUG
        startListeningToUserDefaults()
        #endif

        if NSApp.windows.isEmpty {
            newWindow(self)
        }

        windowDidBecomeKey = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification,
                                                             object: nil,
                                                             queue: nil) { [weak self] notification in
            self?.updateDirectionItemsState()
        }

        windowDidCloseObservation = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                                           object: nil,
                                                                           queue: nil) { notification in
            guard (notification.object as? NSWindow)?.identifier == .init("iWordsPreferences") else {
                return
            }
            // If settings window closes, close associated help window
            NSApp.windows.first {
                $0.windowController?.contentViewController is DictionarySettingsHelpViewController
            }?.close()
        }

        NSApp.servicesProvider = ServiceProvider()
    }

    var font = NSFont.default

    func setUpFont() {
        NSFontManager.shared.target = self

        if let data = UserDefaults.standard.data(forKey: "font") {
            do {
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.requiresSecureCoding = true
                if let font = unarchiver.decodeObject(of: NSFont.self, forKey: "font") {
                    self.font = font
                }
            } catch {
                print("Unable to decode font", error, error.localizedDescription)
            }
        }

        NSFontManager.shared.setSelectedFont(font, isMultiple: false)
        applyFont(font)
        saveFont(font)
    }

    @objc
    func changeFont(_ sender: NSFontManager) {
        let currentFont = font
        font = sender.convert(currentFont)
        applyFont(font)
        saveFont(font)
    }

    func applyFont(_ font: NSFont) {
        NotificationCenter.default.post(name: .selectedFontDidChange,
                                        object: self,
                                        userInfo: [SelectedFontDidChangeFontKey: font])
    }

    func saveFont(_ font: NSFont) {
        NSKeyedArchiver(requiringSecureCoding: true)
            .then {
                $0.encode(font, forKey: "font")
            }
            .encodedData
            .do {
                UserDefaults.standard.set($0, forKey: "font")
            }
    }

    @IBAction @objc
    func resetFont(_ sender: Any?) {
        font = font.dwWithSize(16)
        NSFontManager.shared.setSelectedFont(font, isMultiple: false)
        applyFont(font)
        saveFont(font)
    }

    func updateDirectionItemsState(_ newDirection: Dictionary.Direction? = nil) {
        latinToEnglishItem.state = newDirection ?? keyWindowDirection == .latinToEnglish ? .on  : .off
        englishToLatinItem.state = newDirection ?? keyWindowDirection == .englishToLatin ? .on :  .off
    }

    #if DEBUG
    private func startListeningToUserDefaults() {
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.diagnosticMode", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "values.diagnosticMode" else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        print("User defaults changed", UserDefaults.standard.dictionaryRepresentation())
    }
    #endif

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "copySearchToNewWindows": false,
            "diagnosticMode": false,
            "groupDefinitions": true,
            "history": [],
            "prettyFormatOutput": true,
            "searchBarGrowsToFitContent": true,
            "showInflections": false,
            "webViewTextSizeMultiplier": 1 as Float,
            "windowsFloatOnTop": false,
        ])
    }

    @objc
    var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }


    @IBAction
    func newWindow(_ sender: Any?) {
        LookupWindowController.newController(copying: UserDefaults.standard.bool(forKey: "copySearchToNewWindows") ? keyWindowController() : nil)
            .window
            .map(showNewWindow(_:))
    }

    func showNewWindow(_ newWindow: NSWindow) {
        if let keyWindow = NSApp.keyWindow {
            let newPoint = newWindow.cascadeTopLeft(from: keyWindow.topLeft)
            newWindow.setFrameTopLeftPoint(newPoint)
        } else {
            newWindow.center()
        }

        newWindow.makeKeyAndOrderFront(self)
    }

    func application(_ application: NSApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        print(userActivityType)
        return false
    }

    @available(macOS 12.0, *)
    func application(_ application: NSApplication, handlerFor intent: INIntent) -> Any? {
        switch intent {
        case is LookUpIntent: return LookUpIntentHandler()
        default: return nil
        }
    }

    /// - note: only "iwords:feedback" is valid, not "iwords://feedback"
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        switch URLComponents(url: url, resolvingAgainstBaseURL: false)?.path {
        case "feedback":
            sendFeedback(application)
        case "help":
            openHelp()
        default:
            return
        }
    }

    fileprivate func showFeedbackErrorModal() {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = "Unable to compose an email automatically. Please send an email to support@danielweiner.org with your feedback."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @IBAction
    func showWarnings(_ sender: Any?) {
        UserDefaults.standard.removeObject(forKey: "suppressMultipleTabsAlert")
    }

    private func openHelp() {
        NSApp.showHelp(nil)
    }

    @IBAction
    private func sendFeedback(_ sender: Any?) {
        guard let service = NSSharingService(named: .composeEmail) else {
            showFeedbackErrorModal()
            return
        }
        service.recipients = ["support@danielweiner.org"]
        service.subject = "Feedback for iWords"
        let message = """


            ---- Version information ----
            iWords: Version \(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "Unknown")
            macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
            """
        guard service.canPerform(withItems: [message]) else {
            showFeedbackErrorModal()
            return
        }
        service.perform(withItems: [message])
    }

    @IBAction
    func showPreferences(_ sender: Any?) {
        if let window = NSApp.windows.first(where: { $0.identifier == .init("iWordsPreferences") }) {
            window.makeKeyAndOrderFront(sender)
        } else {
            let prefWindowController = NSStoryboard(name: .init("Settings"), bundle: nil).instantiateInitialController() as! NSWindowController
            prefWindowController.window!.makeKeyAndOrderFront(sender)
        }
    }

    override func responds(to aSelector: Selector!) -> Bool {
        switch aSelector {
        case #selector(showWarnings(_:)):
            return UserDefaults.standard.bool(forKey: "suppressMultipleTabsAlert")
        default:
            return super.responds(to: aSelector)
        }
    }
}

extension AppDelegate: HistoryDelegate {
    func historyController(_ historyController: HistoryController,
                           didSelectHistoryItem query: SearchQuery,
                           withAlternativeNavigation alt: Bool) {
        if alt {
            keyWindowController()?.setSearchQuery(query, withAlternativeNavigation: true)
        } else {
            keyWindowController()?.setSearchQuery(query, withAlternativeNavigation: false)
        }
    }
}

extension AppDelegate {
    @objc
    func didPresentErrorWithRecovery(_ didRecover: Bool, contextInfo: UnsafeMutableRawPointer?) {
        NSApp.terminate(self)
    }
}
