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
    func handle(intent: LookUpIntent) async -> LookUpIntentResponse {
        guard let query = intent.query?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty else {
              return LookUpIntentResponse(code: .failure, userActivity: nil)
        }

        guard let direction = Dictionary.Direction(intent.direction) else {
            return LookUpIntentResponse(code: .failure, userActivity: nil)
        }

        do {
            let definition = try await Dictionary.shared.getDefinition(query,
                                                                       direction: direction,
                                                                       options: [])
            let response = LookUpIntentResponse(code: .success, userActivity: nil)
            response.definition = definition
            return response
        } catch let error as DWError {
            let response = LookUpIntentResponse(code: .success, userActivity: nil)
            response.definition = error.localizedDescription
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

    func resolveQuery(for intent: LookUpIntent) async -> INStringResolutionResult {
        guard let query = intent.query?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty else {
            return .needsValue()
        }
        return .success(with: query)
    }
}
