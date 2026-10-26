import AppKit

/// Converts dictionary data directly into native text, without a markup intermediate.
enum ResultsRenderer {
    static func render(
        _ results: [LookupResult],
        scale: CGFloat,
        formatted: Bool,
        showInflections: Bool,
        expandedInflections: Set<Int> = [],
        includeActions: Bool = true
    ) -> NSAttributedString {
        let output = NSMutableAttributedString(string: "")
        let bodyFont = NSFont.systemFont(ofSize: 15 * scale)
        let codeFont = NSFont.monospacedSystemFont(ofSize: 13 * scale, weight: .regular)

        func append(_ text: String, font: NSFont, color: NSColor = .labelColor,
                    indent: CGFloat = 8, spacing: CGFloat = 6, link: URL? = nil) {
            guard !text.isEmpty else { return }
            let paragraph = NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = indent * scale
            paragraph.headIndent = indent * scale
            paragraph.paragraphSpacing = spacing * scale
            paragraph.lineSpacing = 2 * scale
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph
            ]
            if let link { attributes[.link] = link }
            output.append(NSAttributedString(string: text + "\n", attributes: attributes))
        }

        for (index, query) in results.enumerated() {
            if index > 0 { append("\n", font: bodyFont, spacing: 4) }
            guard formatted, let parsed = query.parsed else {
                append(query.raw ?? "", font: codeFont, indent: 0)
                continue
            }
            append(query.input, font: .boldSystemFont(ofSize: 17 * scale), indent: 0, spacing: 8)
            if includeActions {
                append("Look up in Perseus", font: .systemFont(ofSize: 12 * scale),
                       indent: 0, link: URL(string: "iwords-results://perseus/\(index)"))
                if !showInflections && parsed.contains(where: {
                    if case .word(let word) = $0 {
                        return word.forms.contains { !$0.inflections.isEmpty }
                    }
                    return false
                }) {
                    append(expandedInflections.contains(index) ? "Hide inflections" : "Show inflections",
                           font: .systemFont(ofSize: 12 * scale), indent: 0,
                           link: URL(string: "iwords-results://inflections/\(index)"))
                }
            }
            for result in parsed {
                switch result {
                case .word(let word):
                    if showInflections || expandedInflections.contains(index) {
                        for form in word.forms {
                            append(form.inflections.joined(separator: "\n"), font: codeFont,
                                   color: .secondaryLabelColor)
                        }
                    }
                    for form in word.forms {
                        append(form.dictionaryForms.joined(separator: "\n"), font: codeFont)
                    }
                    append(word.meaning.trimmingCharacters(in: .newlines), font: bodyFont,
                           indent: 16, spacing: 14)
                case .unknown(let text), .addon(let text), .trick(let text):
                    append(text, font: codeFont, spacing: 10)
                }
            }
        }
        return output
    }
}
