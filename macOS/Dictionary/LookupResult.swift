import Foundation

struct LookupResult: Codable, Sendable {
    init(input: String, raw: String?, parsed: [DefinitionRecord]?) {
        self.input = input
        self.raw = raw
        self.parsed = parsed
    }

    let input: String
    let raw: String?
    let parsed: [DefinitionRecord]?

    static func allRaw(_ results: [LookupResult]) -> String {
        results.compactMap(\.raw).joined(separator: "\n\n")
    }
}

enum DefinitionRecord: Codable, Sendable {
    case word(Word)
    case unknown(String)
    case addon(String)
    case trick(String)

    struct Word: Codable, Sendable {
        struct Form: Codable, Sendable {
            let inflections: [String]
            let dictionaryForms: [String]

            var raw: String {
                let text = [inflections.joined(separator: "\n"), dictionaryForms.joined(separator: "\n")].joined(separator: "\n")
                return "\(text)"
            }
        }

        let forms: [Form]
        let meaning: String

        var raw: String {
            let text = [forms.map(\.raw).joined(separator: "\n"), meaning].joined(separator: "\n")
            return "\(text)"
        }
    }

    var raw: String {
        switch self {
        case .word(let word):
            return word.raw
        case .unknown(let str), .addon(let str), .trick(let str):
            return str
        }
    }
}
