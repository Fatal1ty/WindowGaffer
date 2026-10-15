import Foundation

public enum WindowTargetMatchingPolicy {
    /// Matches only metadata that does not conflict with a more descriptive
    /// saved field. Accessibility identifiers are often reused by separate
    /// processes of the same application, so they cannot override a different
    /// document or window title.
    public static func isHighConfidenceMatch(
        _ candidate: WindowTargetDescriptor,
        _ target: WindowTargetDescriptor
    ) -> Bool {
        if let targetDocument = clean(target.document),
           let candidateDocument = clean(candidate.document) {
            return targetDocument == candidateDocument
        }

        if let targetTitle = clean(target.windowTitle),
           let candidateTitle = clean(candidate.windowTitle) {
            return targetTitle == candidateTitle
        }

        if let targetIdentifier = clean(target.windowIdentifier),
           let candidateIdentifier = clean(candidate.windowIdentifier) {
            return targetIdentifier == candidateIdentifier
        }

        return false
    }

    private static func clean(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !value.isEmpty else {
            return nil
        }
        return value
    }
}
