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
    lazy var dictionaryController = DictionaryController(direction: .latinToEnglish)

    func handle(intent: LookUpIntent) async -> LookUpIntentResponse {
        guard let direction = Dictionary.Direction(intent.direction) else {
            return LookUpIntentResponse(code: .failure, userActivity: nil)
        }

        let sanitizedTerms = intent.query?.map { Dictionary.sanitize(input: $0) ?? "" } ?? []

        do {
            dictionaryController.direction = direction
            let results = try await dictionaryController.search(terms: sanitizedTerms)
            let response = LookUpIntentResponse(code: .success, userActivity: nil)
            response.definition = results
                .map(\.raw)
                .map { $0 ?? "No result" }
            return response
        } catch {
            return LookUpIntentResponse(code: .failure, userActivity: nil)
        }
    }

    func resolveDirection(for intent: LookUpIntent) async -> DirectionResolutionResult {
        guard Dictionary.Direction(intent.direction) != nil else {
            return .needsValue()
        }

        return .success(with: intent.direction)
    }

    func resolveQuery(for intent: LookUpIntent) async -> [INStringResolutionResult] {
        intent.query?.map {
            .success(with: $0)
        } ?? []
    }
}
