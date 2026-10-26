//
//  LookUpIntentHandler.swift
//  words (macOS)
//
//  Created by Dan Weiner on 10/23/21.
//

import Cocoa
import Intents

@available(macOS 12.0, *)
extension Dictionary.Direction {
    init?(_ direction: Direction) {
        switch direction {
        case .latinToEnglish: self = .latinToEnglish
        case .englishToLatin: self = .englishToLatin
        case .unknown: return nil
        }
    }
}

@available(macOS 12.0, *)
class LookUpIntentHandler: NSObject, LookUpIntentHandling {
    @MainActor lazy var dictionaryController = DictionaryController(direction: .latinToEnglish)

    func handle(intent: LookUpIntent, completion: @escaping (LookUpIntentResponse) -> Void) {
        guard let direction = Dictionary.Direction(intent.direction) else {
            completion(LookUpIntentResponse(code: .failure, userActivity: nil))
            return
        }

        let sanitizedTerms = Self.searchTerms(from: intent.query)
        guard !sanitizedTerms.isEmpty, sanitizedTerms.allSatisfy(Self.isValidSearchTerm) else {
            completion(LookUpIntentResponse(code: .failure, userActivity: nil))
            return
        }
        Task { @MainActor in
            dictionaryController.direction = direction
            dictionaryController.search(terms: sanitizedTerms) { result in
                switch result {
                case .failure:
                    completion(LookUpIntentResponse(code: .failure, userActivity: nil))
                case .success(let results):
                    let activity = NSUserActivity(activityType: Self.activityType)
                    activity.userInfo = [
                        "query": sanitizedTerms,
                        "direction": direction.rawValue
                    ]
                    let response = LookUpIntentResponse(code: .success, userActivity: activity)
                    response.definition = results
                        .map(\.raw)
                        .map { $0 ?? "No result" }
                    completion(response)
                }
            }
        }
    }

    func resolveDirection(for intent: LookUpIntent, with completion: @escaping (DirectionResolutionResult) -> Void) {
        guard Dictionary.Direction(intent.direction) != nil else {
            completion(.needsValue())
            return
        }

        completion(.success(with: intent.direction))
    }

    func resolveQuery(for intent: LookUpIntent, with completion: @escaping ([INStringResolutionResult]) -> Void) {
        guard let query = intent.query, !query.isEmpty else {
            completion([.needsValue()])
            return
        }

        completion(query.map { text in
            let terms = Self.searchTerms(from: [text])
            guard !terms.isEmpty else { return .needsValue() }
            guard terms.allSatisfy(Self.isValidSearchTerm) else { return .unsupported() }
            return .success(with: terms.joined(separator: " "))
        })
    }

    static let activityType = "LookUpIntent"

    // A Shortcuts text item can contain several words, just like the app's search field.
    static func searchTerms(from query: [String]?) -> [String] {
        (query ?? [])
            .flatMap { $0.split(whereSeparator: \.isWhitespace) }
            .compactMap { Dictionary.sanitize(input: String($0)) }
    }

    static func isValidSearchTerm(_ term: String) -> Bool {
        term.utf8.count <= 256 &&
            term.rangeOfCharacter(from: .controlCharacters) == nil
    }
}
