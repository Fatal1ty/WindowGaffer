import Foundation

/// Decides when a missing saved target may use the sole running window of an
/// application as a fallback. Distinct saved targets must never collapse onto
/// that window merely because the other windows are temporarily unavailable.
public enum AutomaticRebindingPolicy {
    public static func allowsSingleCandidateFallback(
        for target: WindowTargetDescriptor,
        among activeTargets: [WindowTargetDescriptor]
    ) -> Bool {
        activeTargets
            .filter { refersToSameApplication($0, target) }
            .allSatisfy { $0 == target }
    }

    private static func refersToSameApplication(
        _ lhs: WindowTargetDescriptor,
        _ rhs: WindowTargetDescriptor
    ) -> Bool {
        let lhsBundleIdentifier = clean(lhs.bundleIdentifier)
        let rhsBundleIdentifier = clean(rhs.bundleIdentifier)
        if let lhsBundleIdentifier, let rhsBundleIdentifier,
           lhsBundleIdentifier == rhsBundleIdentifier {
            return true
        }

        let lhsExecutablePath = clean(lhs.executablePath)
        let rhsExecutablePath = clean(rhs.executablePath)
        if let lhsExecutablePath, let rhsExecutablePath,
           lhsExecutablePath == rhsExecutablePath {
            return true
        }

        guard let lhsName = clean(lhs.applicationName),
              let rhsName = clean(rhs.applicationName) else {
            return false
        }
        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedSame
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
