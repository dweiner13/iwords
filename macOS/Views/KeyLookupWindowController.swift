////
////  KeyLookupWindowController.swift
////  iWords (macOS)
////
////  Created by Dan Weiner on 2/7/22.
////
//
//import Cocoa
//
//class KeyLookupWindowController: NSObject, NSCoding {
//    @objc dynamic var floatsOnTop = false {
//        didSet {
//            guard oldValue != floatsOnTop else {
//                return
//            }
//
//            guard let windowController = windowController else {
//                floatsOnTop = false
//                return
//            }
//
//            windowController.floatsOnTop = floatsOnTop
//        }
//    }
//
//    @objc dynamic var canFloatOnTop = false
//
//    private var windowController: LookupWindowController?
//    private var keyWindowObservation: Any?
//
//    override init() {
//        super.init()
//        NSApp.keyWindow.map(updateForKeyWindow)
//        startListening()
//    }
//
//    required init?(coder: NSCoder) {
//        super.init()
//        NSApp.keyWindow.map(updateForKeyWindow)
//        startListening()
//    }
//
//    func encode(with coder: NSCoder) {
//        // do nothing
//    }
//
//    private func startListening() {
//        keyWindowObservation = NSApp.observe(\.keyWindow, changeHandler: { [unowned self] app, change in
//            self.updateForKeyWindow(app.keyWindow)
//        })
//    }
//
//    private func updateForKeyWindow(_ window: NSWindow?) {
//        guard let window = window else {
//            return
//        }
//
//        print("🏕 window", window)
//        windowController = window.windowController as? LookupWindowController
//        floatsOnTop = windowController?.floatsOnTop ?? false
//        canFloatOnTop = window.windowController is LookupWindowController
//    }
//}
