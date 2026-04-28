import Foundation

public struct URLRuleEngine: Sendable {
    private let rules: [String: InputSource]

    public init(rules: [String: InputSource]) {
        self.rules = rules
    }

    public func preferredInputSource(for urlString: String?) -> InputSource? {
        guard let urlString, !urlString.isEmpty else {
            return nil
        }

        let normalized = urlString.lowercased()
        return rules
            .filter { pattern, _ in
                let normalizedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !normalizedPattern.isEmpty && normalized.contains(normalizedPattern)
            }
            .sorted { lhs, rhs in
                lhs.key.count > rhs.key.count
            }
            .first?
            .value
    }
}
