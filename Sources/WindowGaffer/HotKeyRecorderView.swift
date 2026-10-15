import AppKit
import WindowGafferCore

extension HotKeyShortcut {
    var displayName: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + keyDisplay
    }

    func usesSameRegistration(as other: HotKeyShortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }
}

final class HotKeyRecorderView: NSView {
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let guidanceLabel = NSTextField(labelWithString: "")

    private(set) var shortcut: HotKeyShortcut? {
        didSet {
            updateLabels()
            onShortcutChanged?(shortcut)
        }
    }

    var onShortcutChanged: ((HotKeyShortcut?) -> Void)?

    init(shortcut: HotKeyShortcut?) {
        self.shortcut = shortcut
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 74))

        wantsLayer = true
        layer?.cornerRadius = 8

        shortcutLabel.font = .monospacedSystemFont(ofSize: 22, weight: .medium)
        shortcutLabel.alignment = .center
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false

        guidanceLabel.font = .systemFont(ofSize: 11)
        guidanceLabel.textColor = .secondaryLabelColor
        guidanceLabel.alignment = .center
        guidanceLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(shortcutLabel)
        addSubview(guidanceLabel)
        NSLayoutConstraint.activate([
            shortcutLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            shortcutLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            guidanceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            guidanceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            guidanceLabel.topAnchor.constraint(equalTo: shortcutLabel.bottomAnchor, constant: 6)
        ])
        updateLabels()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var wantsUpdateLayer: Bool { true }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func keyDown(with event: NSEvent) {
        if !record(event) {
            super.keyDown(with: event)
        }
    }

    @discardableResult
    func record(_ event: NSEvent) -> Bool {
        guard !event.isARepeat else { return true }
        guard event.keyCode != 53, event.keyCode != 36,
              event.keyCode != 76, event.keyCode != 48 else {
            return false
        }

        let modifiers = hotKeyModifiers(from: event.modifierFlags)
        guard !modifiers.isEmpty else {
            guidanceLabel.stringValue = "Include ⌃, ⌥, ⇧, or ⌘"
            NSSound.beep()
            return true
        }
        guard let keyDisplay = keyDisplay(for: event) else {
            NSSound.beep()
            return true
        }

        shortcut = HotKeyShortcut(
            keyCode: event.keyCode,
            modifiers: modifiers,
            keyDisplay: keyDisplay
        )
        return true
    }

    override func updateLayer() {
        super.updateLayer()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = (window?.firstResponder === self
                ? NSColor.controlAccentColor
                : NSColor.separatorColor).cgColor
        }
        layer?.borderWidth = window?.firstResponder === self ? 2 : 1
    }

    private func updateLabels() {
        shortcutLabel.stringValue = shortcut?.displayName ?? "Press a shortcut"
        guidanceLabel.stringValue = "Use a modifier plus one key"
    }

    private func hotKeyModifiers(
        from flags: NSEvent.ModifierFlags
    ) -> Set<HotKeyModifier> {
        var result: Set<HotKeyModifier> = []
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        return result
    }

    private func keyDisplay(for event: NSEvent) -> String? {
        let specialKeys: [UInt16: String] = [
            49: "Space",
            51: "⌫",
            117: "⌦",
            115: "Home",
            119: "End",
            116: "Page Up",
            121: "Page Down",
            123: "←",
            124: "→",
            125: "↓",
            126: "↑",
            122: "F1",
            120: "F2",
            99: "F3",
            118: "F4",
            96: "F5",
            97: "F6",
            98: "F7",
            100: "F8",
            101: "F9",
            109: "F10",
            103: "F11",
            111: "F12",
            105: "F13",
            107: "F14",
            113: "F15",
            106: "F16",
            64: "F17",
            79: "F18",
            80: "F19",
            90: "F20"
        ]
        if let name = specialKeys[event.keyCode] {
            return name
        }

        guard let characters = event.charactersIgnoringModifiers,
              !characters.isEmpty,
              characters.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            return nil
        }
        return characters.uppercased()
    }
}
