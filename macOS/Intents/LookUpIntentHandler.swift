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

    func handle(intent: LookUpIntent, completion: @escaping (LookUpIntentResponse) -> Void) {
        guard let direction = Dictionary.Direction(intent.direction) else {
            completion(LookUpIntentResponse(code: .failure, userActivity: nil))
            return
        }

        let sanitizedTerms = intent.query?.map { Dictionary.sanitize(input: $0) ?? "" } ?? []
        dictionaryController.direction = direction
        dictionaryController.search(terms: sanitizedTerms) { result in
            switch result {
            case .failure(let error):
                completion(LookUpIntentResponse(code: .failure, userActivity: nil))
            case .success(let results):
                let response = LookUpIntentResponse(code: .success, userActivity: nil)
                response.definition = results
                    .map(\.raw)
                    .map { $0 ?? "No result" }
                completion(response)
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
        completion(intent.query?.map {
            .success(with: $0)
        } ?? [])
    }
}
