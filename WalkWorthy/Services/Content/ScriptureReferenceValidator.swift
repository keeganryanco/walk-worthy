import Foundation

struct ScriptureReferenceValidator {
    static let approvedReferences: Set<String> = [
        "Galatians 6:9",
        "1 Corinthians 15:58",
        "Joshua 1:9",
        "2 Timothy 1:7",
        "Philippians 4:6-7",
        "Isaiah 26:3",
        "Colossians 3:23",
        "1 Corinthians 9:27",
        "Galatians 5:13",
        "Mark 10:45"
    ]

    static func isApproved(_ reference: String) -> Bool {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if approvedReferences.contains(trimmed) {
            return true
        }

        // Canonical format fallback: "<Book> <Chapter>:<Verse>" or verse ranges.
        let pattern = #"^(?:[1-3]\s)?[A-Za-z]+(?:\s[A-Za-z]+)*\s\d{1,3}:\d{1,3}(?:-\d{1,3})?$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    static func sanitizedSnippet(_ text: String, maxLength: Int = 220) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxLength {
            return trimmed
        }

        let prefix = trimmed.prefix(maxLength)
        return String(prefix).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
