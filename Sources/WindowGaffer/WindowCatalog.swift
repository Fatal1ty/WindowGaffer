import AppKit
import ApplicationServices
import WindowGafferCore

final class WindowHandle: @unchecked Sendable {
    let element: AXUIElement?
    let processIdentifier: pid_t
    let descriptor: WindowTargetDescriptor
    let windowNumber: CGWindowID?
    let frame: CGRect?

    init(
        element: AXUIElement?,
        processIdentifier: pid_t,
        descriptor: WindowTargetDescriptor,
        windowNumber: CGWindowID? = nil,
        frame: CGRect? = nil
    ) {
        self.element = element
        self.processIdentifier = processIdentifier
        self.descriptor = descriptor
        self.windowNumber = windowNumber
        self.frame = frame
    }
}

final class WindowCandidate: Identifiable, @unchecked Sendable {
    let id = UUID()
    let handle: WindowHandle
    let applicationName: String
    let icon: NSImage
    let title: String
    let isMinimized: Bool
    let isFullScreen: Bool
    let usesProcessFallback: Bool

    init(
        handle: WindowHandle,
        applicationName: String,
        icon: NSImage,
        title: String,
        isMinimized: Bool,
        isFullScreen: Bool,
        usesProcessFallback: Bool = false
    ) {
        self.handle = handle
        self.applicationName = applicationName
        self.icon = icon
        self.title = title
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
        self.usesProcessFallback = usesProcessFallback
    }
}

struct ApplicationWindowGroup: Identifiable {
    let id: String
    let applicationName: String
    let icon: NSImage
    let windows: [WindowCandidate]
    let isActive: Bool
}

enum WindowCatalogError: LocalizedError {
    case accessibilityPermissionRequired

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Accessibility access is required to read application windows."
        }
    }
}

private struct CGWindowMetadata: Sendable {
    let windowNumber: CGWindowID
    let ownerPID: pid_t
    let ownerName: String?
    let title: String?
    let frame: CGRect
}

final class WindowCatalog {
    private let permissionService: AccessibilityPermissionService
    private let workerQueue = DispatchQueue(
        label: "io.windowgaffer.window-catalog",
        qos: .userInitiated
    )

    init(permissionService: AccessibilityPermissionService) {
        self.permissionService = permissionService
    }

    func diagnosticReport(completion: @escaping (String) -> Void) {
        let isTrusted = permissionService.isTrusted
        let applications = NSWorkspace.shared.runningApplications

        workerQueue.async {
            let rawWindows = Self.rawCGWindowInfo()
            let registeredPIDs = Set(applications.map(\.processIdentifier))
            var interestingPIDs = Set<pid_t>()
            var lines = [
                "Window Gaffer Diagnostics",
                "Accessibility trusted: \(isTrusted)",
                "",
                "== CoreGraphics windows =="
            ]

            for info in rawWindows {
                guard let processValue = info[kCGWindowOwnerPID as String]
                    as? NSNumber,
                      let numberValue = info[kCGWindowNumber as String]
                    as? NSNumber else {
                    continue
                }

                let processIdentifier = pid_t(processValue.int32Value)
                let owner = info[kCGWindowOwnerName as String] as? String ?? "?"
                let title = info[kCGWindowName as String] as? String ?? "<none>"
                let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue
                    ?? -1
                let bounds = (info[kCGWindowBounds as String] as? NSDictionary)
                    .flatMap {
                        CGRect(dictionaryRepresentation: $0 as CFDictionary)
                    } ?? .zero
                let text = "\(owner) \(title)".lowercased()
                let looksLikeEVE = text.contains("eve")
                    || text.contains("exefile")
                let isUnregistered = !registeredPIDs.contains(processIdentifier)
                let isSubstantialWindow = bounds.width >= 240
                    && bounds.height >= 140

                guard looksLikeEVE || (isUnregistered && isSubstantialWindow)
                else {
                    continue
                }

                interestingPIDs.insert(processIdentifier)
                lines.append(
                    "window=\(numberValue) pid=\(processIdentifier) "
                        + "owner=\(Self.singleLine(owner)) "
                        + "title=\(Self.singleLine(title)) layer=\(layer) "
                        + "bounds=\(Int(bounds.minX)),\(Int(bounds.minY)),"
                        + "\(Int(bounds.width))x\(Int(bounds.height)) "
                        + "registered=\(!isUnregistered)"
                )
            }

            lines.append("")
            lines.append("== NSWorkspace applications ==")
            for application in applications {
                let name = application.localizedName ?? "<none>"
                let executable = application.executableURL?.path ?? "<none>"
                let bundle = application.bundleURL?.path ?? "<none>"
                let bundleIdentifier = application.bundleIdentifier ?? "<none>"
                let text = "\(name) \(executable) \(bundle)".lowercased()
                guard interestingPIDs.contains(application.processIdentifier)
                        || text.contains("eve")
                        || text.contains("exefile") else {
                    continue
                }

                interestingPIDs.insert(application.processIdentifier)
                lines.append(
                    "pid=\(application.processIdentifier) "
                        + "policy=\(Self.policyName(application.activationPolicy)) "
                        + "name=\(Self.singleLine(name)) "
                        + "bundleID=\(Self.singleLine(bundleIdentifier)) "
                        + "executable=\(Self.singleLine(executable)) "
                        + "bundle=\(Self.singleLine(bundle))"
                )
            }

            lines.append("")
            lines.append("== Accessibility by PID ==")
            for processIdentifier in interestingPIDs.sorted() {
                let applicationElement = AXUIElementCreateApplication(
                    processIdentifier
                )
                AXUIElementSetMessagingTimeout(applicationElement, 0.5)
                var value: CFTypeRef?
                let error = AXUIElementCopyAttributeValue(
                    applicationElement,
                    kAXWindowsAttribute as CFString,
                    &value
                )
                let windows = value as? [AXUIElement] ?? []
                lines.append(
                    "pid=\(processIdentifier) AXWindowsError=\(error.rawValue) "
                        + "count=\(windows.count)"
                )

                for (index, window) in windows.enumerated() {
                    let role: String? = Self.attribute(
                        window,
                        kAXRoleAttribute as CFString
                    )
                    let title: String? = Self.attribute(
                        window,
                        kAXTitleAttribute as CFString
                    )
                    let subrole: String? = Self.attribute(
                        window,
                        kAXSubroleAttribute as CFString
                    )
                    lines.append(
                        "  [\(index)] role=\(Self.singleLine(role ?? "<none>")) "
                            + "subrole=\(Self.singleLine(subrole ?? "<none>")) "
                            + "title=\(Self.singleLine(title ?? "<none>"))"
                    )
                }
            }

            lines.append("")
            lines.append("Note: this report contains metadata and window names, not pixels.")
            let report = lines.joined(separator: "\n")
            DispatchQueue.main.async { completion(report) }
        }
    }

    func fetchGroups(
        completion: @escaping (Result<[ApplicationWindowGroup], Error>) -> Void
    ) {
        guard permissionService.isTrusted else {
            completion(.failure(WindowCatalogError.accessibilityPermissionRequired))
            return
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let cgWindows = Self.cgWindowMetadata()
        let applications = Self.relevantApplications(
            cgWindows: cgWindows,
            excluding: currentPID
        )
        let screenFrames = NSScreen.screens.map(\.frame)

        workerQueue.async {
            let windowsByPID = Dictionary(grouping: cgWindows, by: \.ownerPID)
            var partialGroups = applications.compactMap {
                Self.group(
                    for: $0,
                    screenFrames: screenFrames,
                    cgWindows: windowsByPID[$0.processIdentifier] ?? []
                )
            }
            let registeredPIDs = Set(applications.map(\.processIdentifier))
            partialGroups.append(contentsOf: windowsByPID.compactMap {
                processIdentifier, windows in
                guard !registeredPIDs.contains(processIdentifier) else {
                    return nil
                }
                return Self.unregisteredGroup(
                    processIdentifier: processIdentifier,
                    screenFrames: screenFrames,
                    cgWindows: windows
                )
            })
            let groupedApplications = Dictionary(
                grouping: partialGroups,
                by: \.id
            )
            let groups: [ApplicationWindowGroup] = groupedApplications
                .map { entry in
                    let matchingGroups = entry.value
                    let first = matchingGroups[0]
                    return ApplicationWindowGroup(
                        id: entry.key,
                        applicationName: first.applicationName,
                        icon: first.icon,
                        windows: matchingGroups.flatMap(\.windows),
                        isActive: matchingGroups.contains { $0.isActive }
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.isActive != rhs.isActive {
                        return lhs.isActive
                    }
                    return lhs.applicationName.localizedCaseInsensitiveCompare(
                        rhs.applicationName
                    ) == .orderedAscending
                }

            DispatchQueue.main.async {
                completion(.success(groups))
            }
        }
    }

    func findBestMatch(
        for descriptor: WindowTargetDescriptor,
        allowSingleCandidateFallback: Bool,
        completion: @escaping (WindowHandle?) -> Void
    ) {
        guard permissionService.isTrusted else {
            completion(nil)
            return
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let cgWindows = Self.cgWindowMetadata()
        let applications = Self.relevantApplications(
            cgWindows: cgWindows,
            excluding: currentPID
        )
        let screenFrames = NSScreen.screens.map(\.frame)

        workerQueue.async {
            let windowsByPID = Dictionary(grouping: cgWindows, by: \.ownerPID)
            var candidates: [WindowCandidate] = []

            for application in applications
            where !application.isTerminated
                && Self.matchesApplication(application, descriptor: descriptor) {
                let applicationCandidates = Self.windows(
                    for: application,
                    screenFrames: screenFrames,
                    cgWindows: windowsByPID[application.processIdentifier] ?? []
                )
                candidates.append(contentsOf: applicationCandidates)

                if let exact = applicationCandidates.first(where: {
                    Self.matches($0.handle.descriptor, descriptor)
                }) {
                    DispatchQueue.main.async {
                        completion(exact.handle)
                    }
                    return
                }
            }

            let registeredPIDs = Set(applications.map(\.processIdentifier))
            for (processIdentifier, windows) in windowsByPID
            where !registeredPIDs.contains(processIdentifier) {
                guard let group = Self.unregisteredGroup(
                    processIdentifier: processIdentifier,
                    screenFrames: screenFrames,
                    cgWindows: windows
                ), group.id == descriptor.bundleIdentifier
                    || group.applicationName.localizedCaseInsensitiveCompare(
                        descriptor.applicationName
                    ) == .orderedSame else {
                    continue
                }

                candidates.append(contentsOf: group.windows)
                if let exact = group.windows.first(where: {
                    Self.matches($0.handle.descriptor, descriptor)
                }) {
                    DispatchQueue.main.async {
                        completion(exact.handle)
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                guard allowSingleCandidateFallback, candidates.count == 1 else {
                    completion(nil)
                    return
                }
                completion(candidates[0].handle)
            }
        }
    }

    private static func relevantApplications(
        cgWindows: [CGWindowMetadata],
        excluding currentPID: pid_t
    ) -> [NSRunningApplication] {
        let windowOwnerPIDs = Set(cgWindows.map(\.ownerPID))
        var applicationsByPID: [pid_t: NSRunningApplication] = [:]

        for application in NSWorkspace.shared.runningApplications
        where !application.isTerminated {
            applicationsByPID[application.processIdentifier] = application
        }

        for processIdentifier in windowOwnerPIDs
        where applicationsByPID[processIdentifier] == nil {
            if let application = NSRunningApplication(
                processIdentifier: processIdentifier
            ) {
                applicationsByPID[processIdentifier] = application
            }
        }

        return applicationsByPID.values.filter {
            $0.processIdentifier != currentPID
                && ($0.activationPolicy == .regular
                    || windowOwnerPIDs.contains($0.processIdentifier))
        }
    }

    private static func group(
        for application: NSRunningApplication,
        screenFrames: [CGRect],
        cgWindows: [CGWindowMetadata]
    ) -> ApplicationWindowGroup? {
        let windows = windows(
            for: application,
            screenFrames: screenFrames,
            cgWindows: cgWindows
        )
        guard !windows.isEmpty else { return nil }

        return ApplicationWindowGroup(
            id: applicationIdentity(application),
            applicationName: applicationDisplayName(application),
            icon: application.icon ?? fallbackApplicationIcon,
            windows: windows,
            isActive: application.isActive
        )
    }

    private static func unregisteredGroup(
        processIdentifier: pid_t,
        screenFrames: [CGRect],
        cgWindows: [CGWindowMetadata]
    ) -> ApplicationWindowGroup? {
        guard !cgWindows.isEmpty else { return nil }

        let applicationName = cgWindows.lazy.compactMap {
            clean($0.ownerName)
        }.first ?? "Process \(processIdentifier)"
        let identifier = "unregistered:\(applicationName.lowercased())"
        let icon = fallbackApplicationIcon
        // Wine exposes several layer-zero helper surfaces for a single EVE
        // client (menu strips, tooltip hosts, and the actual game surface).
        // The game surface is consistently the largest one for that PID.
        guard let primaryWindow = cgWindows.max(by: {
            $0.frame.width * $0.frame.height
                < $1.frame.width * $1.frame.height
        }) else {
            return nil
        }
        let candidates = [cgFallbackCandidate(
            cgWindow: primaryWindow,
            index: 0,
            processIdentifier: processIdentifier,
            applicationName: applicationName,
            applicationIdentifier: identifier,
            executablePath: nil,
            icon: icon,
            screenFrames: screenFrames
        )]

        return ApplicationWindowGroup(
            id: identifier,
            applicationName: applicationName,
            icon: icon,
            windows: candidates,
            isActive: false
        )
    }

    private static func windows(
        for application: NSRunningApplication,
        screenFrames: [CGRect],
        cgWindows: [CGWindowMetadata]
    ) -> [WindowCandidate] {
        let applicationElement = AXUIElementCreateApplication(
            application.processIdentifier
        )
        AXUIElementSetMessagingTimeout(applicationElement, 0.5)

        var elements: [AXUIElement] = attribute(
            applicationElement,
            kAXWindowsAttribute as CFString
        ) ?? []

        if let mainWindow: AXUIElement = attribute(
            applicationElement,
            kAXMainWindowAttribute as CFString
        ) {
            appendIfMissing(mainWindow, to: &elements)
        }
        if let focusedWindow: AXUIElement = attribute(
            applicationElement,
            kAXFocusedWindowAttribute as CFString
        ) {
            appendIfMissing(focusedWindow, to: &elements)
        }

        let applicationName = applicationDisplayName(application)
        let applicationIdentifier = applicationIdentity(application)
        let executablePath = application.executableURL?.path
        let icon = application.icon ?? fallbackApplicationIcon

        var candidates = elements.enumerated().compactMap { index, element in
            axCandidate(
                element: element,
                index: index,
                application: application,
                applicationName: applicationName,
                applicationIdentifier: applicationIdentifier,
                executablePath: executablePath,
                icon: icon,
                screenFrames: screenFrames
            )
        }

        for (index, cgWindow) in cgWindows.enumerated()
        where !hasMatchingAXCandidate(cgWindow, candidates: candidates) {
            candidates.append(cgFallbackCandidate(
                cgWindow: cgWindow,
                index: index,
                processIdentifier: application.processIdentifier,
                applicationName: applicationName,
                applicationIdentifier: applicationIdentifier,
                executablePath: executablePath,
                icon: icon,
                screenFrames: screenFrames
            ))
        }

        return candidates
    }

    private static func cgFallbackCandidate(
        cgWindow: CGWindowMetadata,
        index: Int,
        processIdentifier: pid_t,
        applicationName: String,
        applicationIdentifier: String,
        executablePath: String?,
        icon: NSImage,
        screenFrames: [CGRect]
    ) -> WindowCandidate {
        let fullScreen = isFullScreen(
            cgWindow.frame,
            screenFrames: screenFrames
        )
        let rawTitle = clean(cgWindow.title)
        let ownerName = clean(cgWindow.ownerName)
        let genericProcessTitle = rawTitle != nil
            && rawTitle?.localizedCaseInsensitiveCompare(ownerName ?? "")
                == .orderedSame
        let displayTitle: String

        if let rawTitle, !genericProcessTitle {
            displayTitle = rawTitle
        } else if let rawTitle {
            displayTitle = "\(applicationName) — \(rawTitle) (\(processIdentifier))"
        } else if fullScreen {
            displayTitle = "\(applicationName) — Full Screen (\(processIdentifier))"
        } else {
            displayTitle = "\(applicationName) — Window \(index + 1) (\(processIdentifier))"
        }

        let descriptor = WindowTargetDescriptor(
            bundleIdentifier: applicationIdentifier,
            applicationName: applicationName,
            windowTitle: displayTitle,
            executablePath: executablePath
        )
        let handle = WindowHandle(
            element: nil,
            processIdentifier: processIdentifier,
            descriptor: descriptor,
            windowNumber: cgWindow.windowNumber,
            frame: cgWindow.frame
        )
        return WindowCandidate(
            handle: handle,
            applicationName: applicationName,
            icon: icon,
            title: displayTitle,
            isMinimized: false,
            isFullScreen: fullScreen,
            usesProcessFallback: true
        )
    }

    private static func axCandidate(
        element: AXUIElement,
        index: Int,
        application: NSRunningApplication,
        applicationName: String,
        applicationIdentifier: String,
        executablePath: String?,
        icon: NSImage,
        screenFrames: [CGRect]
    ) -> WindowCandidate? {
        guard let role: String = attribute(
            element,
            kAXRoleAttribute as CFString
        ), acceptedWindowRoles.contains(role) else {
            return nil
        }

        let title = clean(attribute(
            element,
            kAXTitleAttribute as CFString
        ) as String?)
        let document = clean(attribute(
            element,
            kAXDocumentAttribute as CFString
        ) as String?)
        let identifier = clean(attribute(
            element,
            kAXIdentifierAttribute as CFString
        ) as String?)
        let description = clean(attribute(
            element,
            kAXDescriptionAttribute as CFString
        ) as String?)
        let windowNumberValue: NSNumber? = attribute(
            element,
            "AXWindowNumber" as CFString
        )
        let windowNumber = windowNumberValue.map {
            CGWindowID($0.uint32Value)
        }
        let windowFrame = frame(of: element)
        let fullScreen = windowFrame.map {
            isFullScreen($0, screenFrames: screenFrames)
        } ?? false
        let displayTitle = title
            ?? document.flatMap(documentDisplayName)
            ?? usefulDescription(description, applicationName: applicationName)
            ?? (fullScreen
                ? "\(applicationName) — Full Screen"
                : "\(applicationName) — Untitled Window \(index + 1)")
        let minimized: Bool = attribute(
            element,
            kAXMinimizedAttribute as CFString
        ) ?? false

        let descriptor = WindowTargetDescriptor(
            bundleIdentifier: applicationIdentifier,
            applicationName: applicationName,
            windowTitle: displayTitle,
            windowIdentifier: identifier,
            document: document,
            executablePath: executablePath
        )
        let handle = WindowHandle(
            element: element,
            processIdentifier: application.processIdentifier,
            descriptor: descriptor,
            windowNumber: windowNumber,
            frame: windowFrame
        )

        return WindowCandidate(
            handle: handle,
            applicationName: applicationName,
            icon: icon,
            title: displayTitle,
            isMinimized: minimized,
            isFullScreen: fullScreen
        )
    }

    private static func hasMatchingAXCandidate(
        _ cgWindow: CGWindowMetadata,
        candidates: [WindowCandidate]
    ) -> Bool {
        return candidates.contains { candidate in
            if candidate.handle.windowNumber == cgWindow.windowNumber {
                return true
            }
            if let candidateFrame = candidate.handle.frame,
               approximatelyEqual(candidateFrame, cgWindow.frame, tolerance: 3) {
                return true
            }
            if let cgTitle = clean(cgWindow.title) {
                return candidate.title.localizedCaseInsensitiveCompare(cgTitle)
                    == .orderedSame
            }
            return false
        }
    }

    private static func cgWindowMetadata() -> [CGWindowMetadata] {
        rawCGWindowInfo().compactMap { info in
            guard let layer = info[kCGWindowLayer as String] as? NSNumber,
                  layer.intValue == 0,
                  let processValue = info[kCGWindowOwnerPID as String] as? NSNumber,
                  let numberValue = info[kCGWindowNumber as String] as? NSNumber,
                  let boundsDictionary = info[kCGWindowBounds as String]
                    as? NSDictionary,
                  let frame = CGRect(
                      dictionaryRepresentation: boundsDictionary as CFDictionary
                  ),
                  frame.width >= 80,
                  frame.height >= 60 else {
                return nil
            }

            if let alpha = info[kCGWindowAlpha as String] as? NSNumber,
               alpha.doubleValue <= 0.01 {
                return nil
            }

            return CGWindowMetadata(
                windowNumber: CGWindowID(numberValue.uint32Value),
                ownerPID: pid_t(processValue.int32Value),
                ownerName: info[kCGWindowOwnerName as String] as? String,
                title: info[kCGWindowName as String] as? String,
                frame: frame
            )
        }
    }

    private static func rawCGWindowInfo() -> [[String: Any]] {
        CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []
    }

    private static func singleLine(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private static func policyName(
        _ policy: NSApplication.ActivationPolicy
    ) -> String {
        switch policy {
        case .regular:
            return "regular"
        case .accessory:
            return "accessory"
        case .prohibited:
            return "prohibited"
        @unknown default:
            return "unknown(\(policy.rawValue))"
        }
    }

    private static func applicationDisplayName(
        _ application: NSRunningApplication
    ) -> String {
        let localizedName = clean(application.localizedName)
        let executableName = clean(
            application.executableURL?.deletingPathExtension().lastPathComponent
        )
        let bundle = application.bundleURL.flatMap(Bundle.init(url:))
        let bundleDisplayName = clean(
            bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ) ?? clean(bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
        let bundleFileName = clean(
            application.bundleURL?.deletingPathExtension().lastPathComponent
        )

        if let localizedName,
           localizedName.localizedCaseInsensitiveCompare(executableName ?? "")
            != .orderedSame {
            return localizedName
        }
        if let bundleDisplayName,
           bundleDisplayName.localizedCaseInsensitiveCompare(executableName ?? "")
            != .orderedSame {
            return bundleDisplayName
        }
        if let bundleFileName,
           bundleFileName.localizedCaseInsensitiveCompare(executableName ?? "")
            != .orderedSame {
            return bundleFileName
        }
        return localizedName ?? bundleDisplayName ?? bundleFileName
            ?? executableName ?? "Application"
    }

    private static func applicationIdentity(
        _ application: NSRunningApplication
    ) -> String {
        if let bundleIdentifier = application.bundleIdentifier {
            return bundleIdentifier
        }
        if let bundlePath = application.bundleURL?.path {
            return "bundle-path:\(bundlePath)"
        }
        if let executablePath = application.executableURL?.path {
            return "executable:\(executablePath)"
        }
        return "name:\(applicationDisplayName(application))"
    }

    private static func matchesApplication(
        _ application: NSRunningApplication,
        descriptor: WindowTargetDescriptor
    ) -> Bool {
        if applicationIdentity(application) == descriptor.bundleIdentifier {
            return true
        }
        if let executablePath = descriptor.executablePath,
           application.executableURL?.path == executablePath {
            return true
        }
        return applicationDisplayName(application)
            .localizedCaseInsensitiveCompare(descriptor.applicationName)
            == .orderedSame
    }

    private static let acceptedWindowRoles: Set<String> = [
        kAXWindowRole as String,
        kAXSheetRole as String,
        kAXDrawerRole as String
    ]

    private static func appendIfMissing(
        _ element: AXUIElement,
        to elements: inout [AXUIElement]
    ) {
        guard !elements.contains(where: { CFEqual($0, element) }) else {
            return
        }
        elements.append(element)
    }

    private static func clean(_ value: String?) -> String? {
        guard let cleanValue = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !cleanValue.isEmpty else {
            return nil
        }
        return cleanValue
    }

    private static func documentDisplayName(_ document: String) -> String? {
        if let url = URL(string: document), !url.lastPathComponent.isEmpty {
            return url.lastPathComponent.removingPercentEncoding
                ?? url.lastPathComponent
        }

        let pathName = (document as NSString).lastPathComponent
        return pathName.isEmpty ? nil : pathName
    }

    private static func usefulDescription(
        _ description: String?,
        applicationName: String
    ) -> String? {
        guard let description,
              description.localizedCaseInsensitiveCompare(applicationName)
                != .orderedSame,
              description.localizedCaseInsensitiveCompare("window")
                != .orderedSame else {
            return nil
        }
        return description
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = attribute(
            element,
            kAXPositionAttribute as CFString
        ), let sizeValue: AXValue = attribute(
            element,
            kAXSizeAttribute as CFString
        ), AXValueGetType(positionValue) == .cgPoint,
           AXValueGetType(sizeValue) == .cgSize else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private static func isFullScreen(
        _ frame: CGRect,
        screenFrames: [CGRect]
    ) -> Bool {
        screenFrames.contains {
            abs(frame.width - $0.width) <= 3
                && abs(frame.height - $0.height) <= 3
        }
    }

    private static func approximatelyEqual(
        _ lhs: CGRect,
        _ rhs: CGRect,
        tolerance: CGFloat
    ) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    private static func matches(
        _ candidate: WindowTargetDescriptor,
        _ target: WindowTargetDescriptor
    ) -> Bool {
        WindowTargetMatchingPolicy.isHighConfidenceMatch(candidate, target)
    }

    private static func attribute<T>(
        _ element: AXUIElement,
        _ name: CFString
    ) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name, &value)
        guard error == .success else { return nil }
        return value as? T
    }

    private static var fallbackApplicationIcon: NSImage {
        NSImage(
            systemSymbolName: "app",
            accessibilityDescription: nil
        ) ?? NSImage(size: NSSize(width: 32, height: 32))
    }
}
