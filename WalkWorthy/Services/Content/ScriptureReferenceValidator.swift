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
        approvedReferences.contains(reference)
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
