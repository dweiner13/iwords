//
//  ServiceProvider.swift
//  words (macOS)
//
//  Created by Dan Weiner on 10/23/21.
//

import AppKit

@objc
class ServiceProvider: NSObject {
    @objc
    func translateLatinToEnglish(_ pasteboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        func setError(localizedDescription: String) {
            let userInfo = [NSLocalizedDescriptionKey: localizedDescription]
            error?.pointee = NSError(domain: "org.danielweiner.org",
                                     code: 1,
                                     userInfo: userInfo)
        }

        guard let string = pasteboard.string(forType: .string) else {
            setError(localizedDescription: "Could not retrieve text from the pasteboard.")
            return
        }

        do {
            let result = try Dictionary.shared.getDefinition(string.trimmingCharacters(in: .whitespacesAndNewlines),
                                                             direction: .latinToEnglish,
                                                             options: [])
            guard let result = result else {
                setError(localizedDescription: "No results found.")
                return
            }
            pasteboard.clearContents()
            pasteboard.writeObjects([result as NSString])
        } catch {
            setError(localizedDescription: "Encountered error translating text: \(error.localizedDescription).")
        }
    }
}
