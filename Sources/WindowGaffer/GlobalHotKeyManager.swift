import Carbon.HIToolbox
import Foundation
import WindowGafferCore

private func windowGafferHotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    var identifier = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identifier
    )
    guard status == noErr else { return status }

    let manager = Unmanaged<GlobalHotKeyManager>
        .fromOpaque(userData)
        .takeUnretainedValue()
    return manager.handle(identifier: identifier.id)
}

final class GlobalHotKeyManager {
    private struct Registration {
        let identifier: UInt32
        let shortcut: HotKeyShortcut
        let reference: EventHotKeyRef
        let action: () -> Void
    }

    private static let signature: OSType = 0x57474146 // "WGAF"

    private var eventHandler: EventHandlerRef?
    private var registrationsByOwner: [UUID: Registration] = [:]
    private var ownersByIdentifier: [UInt32: UUID] = [:]
    private var nextIdentifier: UInt32 = 1

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            windowGafferHotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        if status != noErr {
            NSLog("Window Gaffer: unable to install hotkey event handler (status %d)", status)
        }
    }

    deinit {
        for registration in registrationsByOwner.values {
            UnregisterEventHotKey(registration.reference)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    @discardableResult
    func register(
        owner: UUID,
        shortcut: HotKeyShortcut,
        action: @escaping () -> Void
    ) -> OSStatus {
        if let existing = registrationsByOwner[owner],
           existing.shortcut.usesSameRegistration(as: shortcut) {
            registrationsByOwner[owner] = Registration(
                identifier: existing.identifier,
                shortcut: shortcut,
                reference: existing.reference,
                action: action
            )
            return noErr
        }

        let identifier = nextIdentifier
        nextIdentifier &+= 1
        if nextIdentifier == 0 {
            nextIdentifier = 1
        }

        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: identifier
        )
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers(for: shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else {
            return status
        }

        unregister(owner: owner)
        registrationsByOwner[owner] = Registration(
            identifier: identifier,
            shortcut: shortcut,
            reference: reference,
            action: action
        )
        ownersByIdentifier[identifier] = owner
        return noErr
    }

    func unregister(owner: UUID) {
        guard let registration = registrationsByOwner.removeValue(forKey: owner) else {
            return
        }
        ownersByIdentifier[registration.identifier] = nil
        UnregisterEventHotKey(registration.reference)
    }

    fileprivate func handle(identifier: UInt32) -> OSStatus {
        guard let owner = ownersByIdentifier[identifier],
              let registration = registrationsByOwner[owner] else {
            return OSStatus(eventNotHandledErr)
        }

        registration.action()
        return noErr
    }

    private func carbonModifiers(
        for modifiers: Set<HotKeyModifier>
    ) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
