import CoreGraphics
import Foundation

public struct WindowTargetDescriptor: Codable, Equatable, Sendable {
    public var bundleIdentifier: String
    public var applicationName: String
    public var windowTitle: String
    public var windowIdentifier: String?
    public var document: String?
    public var executablePath: String?

    public init(
        bundleIdentifier: String,
        applicationName: String,
        windowTitle: String,
        windowIdentifier: String? = nil,
        document: String? = nil,
        executablePath: String? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.windowIdentifier = windowIdentifier
        self.document = document
        self.executablePath = executablePath
    }
}

public enum HotKeyModifier: String, Codable, CaseIterable, Sendable {
    case control
    case option
    case shift
    case command
}

public struct HotKeyShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Set<HotKeyModifier>
    public var keyDisplay: String

    public init(
        keyCode: UInt16,
        modifiers: Set<HotKeyModifier>,
        keyDisplay: String
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyDisplay = keyDisplay
    }
}

public struct OverlayConfiguration: Codable, Equatable, Sendable {
    public var text: String
    public var frame: StoredRect

    public init(text: String, frame: CGRect) {
        self.text = text
        self.frame = StoredRect(frame)
    }
}

/// Window access belongs to a profile entry, not to the registered target.
/// A target can therefore have a different overlay or hotkey per profile.
public struct WindowAccessConfiguration: Codable, Equatable, Sendable {
    public var overlay: OverlayConfiguration?
    public var hotKey: HotKeyShortcut?

    public init(
        overlay: OverlayConfiguration? = nil,
        hotKey: HotKeyShortcut? = nil
    ) {
        self.overlay = overlay
        self.hotKey = hotKey
    }
}

public struct RegisteredWindow: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var nameOverride: String?
    public var target: WindowTargetDescriptor

    public init(
        id: UUID = UUID(),
        nameOverride: String? = nil,
        target: WindowTargetDescriptor
    ) {
        self.id = id
        self.nameOverride = nameOverride
        self.target = target
    }

    public var automaticDisplayName: String {
        let title = target.windowTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !title.isEmpty {
            return title
        }

        let applicationName = target.applicationName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return applicationName.isEmpty ? "Window" : applicationName
    }

    public var displayName: String {
        let override = nameOverride?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        return override.isEmpty ? automaticDisplayName : override
    }
}

public struct ProfileWindowEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var registeredWindowID: UUID
    public var access: WindowAccessConfiguration

    public init(
        id: UUID = UUID(),
        registeredWindowID: UUID,
        access: WindowAccessConfiguration = WindowAccessConfiguration()
    ) {
        self.id = id
        self.registeredWindowID = registeredWindowID
        self.access = access
    }
}

public struct WindowProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var isDefault: Bool
    public var entries: [ProfileWindowEntry]

    public init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool = false,
        entries: [ProfileWindowEntry] = []
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.entries = entries
    }
}

public struct WindowGafferConfiguration: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public var version: Int
    public var registeredWindows: [RegisteredWindow]
    public var profiles: [WindowProfile]
    public var activeProfileID: UUID

    public init(
        version: Int = Self.schemaVersion,
        registeredWindows: [RegisteredWindow],
        profiles: [WindowProfile],
        activeProfileID: UUID
    ) {
        self.version = version
        self.registeredWindows = registeredWindows
        self.profiles = profiles
        self.activeProfileID = activeProfileID
    }

    public static func empty() -> WindowGafferConfiguration {
        let profile = WindowProfile(name: "Default", isDefault: true)
        return WindowGafferConfiguration(
            registeredWindows: [],
            profiles: [profile],
            activeProfileID: profile.id
        )
    }
}

public struct StoredRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
