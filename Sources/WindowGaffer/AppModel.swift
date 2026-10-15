import AppKit
import Combine
import WindowGafferCore

final class AppModel: ObservableObject {
    private let catalog: WindowCatalog
    private let focusService: WindowFocusService
    private let store: OverlayStore
    private let hotKeyManager: GlobalHotKeyManager

    @Published private(set) var configuration: WindowGafferConfiguration
    @Published private(set) var revision = 0

    private var handles: [UUID: WindowHandle] = [:]
    private var controllers: [UUID: OverlayWindowController] = [:]
    private var availability: [UUID: Bool] = [:]
    private var bindingRequestIDs: [UUID: UUID] = [:]
    private var focusRequestIDs: [UUID: UUID] = [:]

    private(set) var isEditing = false
    private(set) var areOverlaysVisible: Bool
    var onEditingChanged: ((Bool) -> Void)?
    var onOverlaysVisibilityChanged: ((Bool) -> Void)?
    var onActiveProfileChanged: (() -> Void)?
    var onOpenSettingsRequested: (() -> Void)?

    init(
        catalog: WindowCatalog,
        focusService: WindowFocusService,
        store: OverlayStore,
        hotKeyManager: GlobalHotKeyManager
    ) {
        self.catalog = catalog
        self.focusService = focusService
        self.store = store
        self.hotKeyManager = hotKeyManager
        configuration = store.loadConfiguration()
        areOverlaysVisible = store.loadOverlaysVisible()
    }

    var profiles: [WindowProfile] {
        configuration.profiles
    }

    var activeProfileID: UUID {
        configuration.activeProfileID
    }

    var activeProfile: WindowProfile {
        configuration.profiles.first(where: {
            $0.id == configuration.activeProfileID
        }) ?? configuration.profiles[0]
    }

    func registeredWindow(id: UUID) -> RegisteredWindow? {
        configuration.registeredWindows.first { $0.id == id }
    }

    func isEntryAvailable(_ id: UUID) -> Bool? {
        availability[id]
    }

    func restore() {
        loadActiveProfile()
    }

    func refreshAvailability() {
        for entry in activeProfile.entries
        where bindingRequestIDs[entry.id] == nil
            && focusRequestIDs[entry.id] == nil {
            rebind(entry.id, focusAfterBinding: false)
        }
    }

    func activateProfile(_ id: UUID) {
        guard id != configuration.activeProfileID,
              configuration.profiles.contains(where: { $0.id == id }) else {
            return
        }

        teardownActiveProfile()
        configuration.activeProfileID = id
        persistConfiguration()
        loadActiveProfile()
        publishChange()
        onActiveProfileChanged?()
    }

    @discardableResult
    func createProfile() -> UUID {
        let existingNames = Set(configuration.profiles.map { $0.name.lowercased() })
        var number = 1
        var name = "Profile \(number)"
        while existingNames.contains(name.lowercased()) {
            number += 1
            name = "Profile \(number)"
        }

        let profile = WindowProfile(name: name)
        configuration.profiles.append(profile)
        persistConfiguration()
        activateProfile(profile.id)
        return profile.id
    }

    func deleteProfile(_ id: UUID) {
        guard let profile = configuration.profiles.first(where: { $0.id == id }),
              !profile.isDefault else {
            return
        }

        let wasActive = id == configuration.activeProfileID
        if wasActive {
            teardownActiveProfile()
        }
        configuration.profiles.removeAll { $0.id == id }
        removeOrphanedRegistrations()

        if wasActive {
            configuration.activeProfileID = configuration.profiles.first(where: {
                $0.isDefault
            })?.id ?? configuration.profiles[0].id
        }

        persistConfiguration()
        if wasActive {
            loadActiveProfile()
            onActiveProfileChanged?()
        }
        publishChange()
    }

    /// Commits one complete profile draft. Runtime overlays and hotkeys are
    /// replaced only after this method is called, so edits remain harmless
    /// drafts until the user presses Save Profile.
    func saveProfile(
        _ profile: WindowProfile,
        registrations: [RegisteredWindow]
    ) -> String? {
        guard let profileIndex = configuration.profiles.firstIndex(where: {
            $0.id == profile.id
        }) else {
            return "The profile no longer exists."
        }

        let savedProfile = configuration.profiles[profileIndex]
        let requestedName = savedProfile.isDefault
            ? savedProfile.name
            : profile.name
        let cleanName = requestedName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleanName.isEmpty else {
            return "Enter a profile name."
        }
        if configuration.profiles.contains(where: {
            $0.id != profile.id
                && $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame
        }) {
            return "A profile named “\(cleanName)” already exists."
        }

        let duplicateHotKeys = Dictionary(
            grouping: profile.entries.compactMap { entry in
                entry.access.hotKey.map { (entry.id, $0) }
            },
            by: { pair in
                HotKeyIdentity(shortcut: pair.1)
            }
        ).first { $0.value.count > 1 }
        if let duplicateHotKeys {
            return "The hotkey \(duplicateHotKeys.value[0].1.displayName) is assigned more than once in this profile."
        }

        let wasActive = profile.id == configuration.activeProfileID
        if wasActive {
            teardownActiveProfile()
        }

        var committedProfile = profile
        committedProfile.name = cleanName
        committedProfile.isDefault = savedProfile.isDefault
        configuration.profiles[profileIndex] = committedProfile

        for registration in registrations {
            if let index = configuration.registeredWindows.firstIndex(where: {
                $0.id == registration.id
            }) {
                configuration.registeredWindows[index] = registration
            } else {
                configuration.registeredWindows.append(registration)
            }
        }
        removeOrphanedRegistrations()
        persistConfiguration()

        if wasActive {
            loadActiveProfile()
        }
        publishChange()
        return nil
    }

    func setEditing(_ editing: Bool) {
        if editing && !areOverlaysVisible {
            setOverlaysVisible(true)
        }
        isEditing = editing
        controllers.values.forEach { $0.setEditing(editing) }
        onEditingChanged?(editing)
    }

    func toggleEditing() {
        setEditing(!isEditing)
    }

    func setOverlaysVisible(_ visible: Bool) {
        guard areOverlaysVisible != visible else { return }

        areOverlaysVisible = visible
        if visible {
            controllers.values.forEach { $0.show() }
        } else {
            if isEditing {
                isEditing = false
                controllers.values.forEach { $0.setEditing(false) }
                onEditingChanged?(false)
            }
            controllers.values.forEach { $0.hide() }
        }
        store.saveOverlaysVisible(visible)
        onOverlaysVisibilityChanged?(visible)
    }

    func toggleOverlaysVisibility() {
        setOverlaysVisible(!areOverlaysVisible)
    }

    func suggestedOverlayFrame(text: String) -> CGRect {
        let size = OverlayMetrics.size(for: text)
        return CGRect(origin: initialOrigin(for: size), size: size)
    }

    private func loadActiveProfile() {
        for entry in activeProfile.entries {
            guard let registration = registeredWindow(id: entry.registeredWindowID) else {
                continue
            }

            if let overlay = entry.access.overlay {
                createController(
                    for: entry,
                    registration: registration,
                    overlay: overlay,
                    available: false
                )
            }
            registerStoredHotKey(for: entry)
            rebind(entry.id, focusAfterBinding: false)
        }
    }

    private func teardownActiveProfile() {
        for entry in activeProfile.entries {
            hotKeyManager.unregister(owner: entry.id)
        }
        controllers.values.forEach { $0.close() }
        controllers.removeAll()
        handles.removeAll()
        availability.removeAll()
        bindingRequestIDs.removeAll()
        focusRequestIDs.removeAll()
    }

    private func createController(
        for entry: ProfileWindowEntry,
        registration: RegisteredWindow,
        overlay: OverlayConfiguration,
        available: Bool
    ) {
        let id = entry.id
        let controller = OverlayWindowController(
            label: overlay.text,
            frame: normalizedFrame(overlay.frame.cgRect),
            onActivate: { [weak self] in
                self?.activateEntry(id)
            },
            onSnapFrame: { [weak self] proposed in
                self?.snappedFrame(for: id, proposed: proposed) ?? proposed
            },
            onFrameChanged: { [weak self] frame in
                self?.updateOverlayFrame(frame, for: id)
            },
            onRename: { [weak self] text in
                self?.updateOverlayText(text, for: id)
            },
            onOpenSettings: { [weak self] in
                self?.onOpenSettingsRequested?()
            }
        )

        controller.setEditing(isEditing)
        controller.setAvailable(available)
        controllers[id] = controller
        if areOverlaysVisible {
            controller.show()
        }
    }

    private func activateEntry(_ id: UUID) {
        if let handle = handles[id] {
            performFocus(id: id, handle: handle, mayRebind: true)
        } else {
            rebind(id, focusAfterBinding: true)
        }
    }

    private func performFocus(
        id: UUID,
        handle: WindowHandle,
        mayRebind: Bool
    ) {
        let profileID = activeProfileID
        let requestID = UUID()
        focusRequestIDs[id] = requestID

        focusService.focus(handle) { [weak self] success in
            guard let self,
                  activeProfileID == profileID,
                  focusRequestIDs[id] == requestID else {
                return
            }
            focusRequestIDs[id] = nil

            updateAvailability(success, for: id)
            if !success {
                handles[id] = nil
                if mayRebind {
                    rebind(id, focusAfterBinding: true)
                }
            }
        }
    }

    private func rebind(_ id: UUID, focusAfterBinding: Bool) {
        guard let entry = activeProfile.entries.first(where: { $0.id == id }),
              let registration = registeredWindow(id: entry.registeredWindowID) else {
            return
        }

        let activeTargets = activeProfile.entries.compactMap { entry in
            registeredWindow(id: entry.registeredWindowID)?.target
        }
        let allowSingleCandidateFallback = AutomaticRebindingPolicy
            .allowsSingleCandidateFallback(
                for: registration.target,
                among: activeTargets
            )
        let profileID = activeProfileID
        let requestID = UUID()
        bindingRequestIDs[id] = requestID

        catalog.findBestMatch(
            for: registration.target,
            allowSingleCandidateFallback: allowSingleCandidateFallback
        ) { [weak self] handle in
            guard let self,
                  activeProfileID == profileID,
                  bindingRequestIDs[id] == requestID else {
                return
            }
            bindingRequestIDs[id] = nil

            guard let handle else {
                handles[id] = nil
                updateAvailability(false, for: id)
                return
            }

            handles[id] = handle
            updateAvailability(true, for: id)
            if focusAfterBinding {
                performFocus(id: id, handle: handle, mayRebind: false)
            }
        }
    }

    private func updateAvailability(_ available: Bool, for id: UUID) {
        guard availability[id] != available else { return }
        availability[id] = available
        controllers[id]?.setAvailable(available)
        publishChange()
    }

    private func registerStoredHotKey(for entry: ProfileWindowEntry) {
        guard let hotKey = entry.access.hotKey else { return }

        let status = hotKeyManager.register(
            owner: entry.id,
            shortcut: hotKey
        ) { [weak self] in
            self?.activateEntry(entry.id)
        }
        if status != noErr {
            NSLog(
                "Window Gaffer: unable to register hotkey %@ (status %d)",
                hotKey.displayName,
                status
            )
        }
    }

    private func snappedFrame(for id: UUID, proposed: CGRect) -> CGRect {
        let otherFrames = activeProfile.entries.compactMap { entry -> CGRect? in
            guard entry.id != id else { return nil }
            return entry.access.overlay?.frame.cgRect
        }
        let screenFrames = NSScreen.screens.map(\.frame)

        return SnapEngine.snap(
            proposed,
            to: otherFrames,
            screenFrames: screenFrames,
            threshold: 10
        ).frame
    }

    private func updateOverlayFrame(_ frame: CGRect, for id: UUID) {
        mutateActiveEntry(id) { entry in
            entry.access.overlay?.frame = StoredRect(frame.integral)
        }
    }

    private func updateOverlayText(_ text: String, for id: UUID) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        mutateActiveEntry(id) { entry in
            entry.access.overlay?.text = cleanText
        }
        controllers[id]?.setLabel(cleanText)
    }

    private func mutateActiveEntry(
        _ id: UUID,
        mutation: (inout ProfileWindowEntry) -> Void
    ) {
        guard let profileIndex = configuration.profiles.firstIndex(where: {
            $0.id == configuration.activeProfileID
        }), let entryIndex = configuration.profiles[profileIndex].entries.firstIndex(where: {
            $0.id == id
        }) else {
            return
        }
        mutation(&configuration.profiles[profileIndex].entries[entryIndex])
        persistConfiguration()
        publishChange()
    }

    private func removeOrphanedRegistrations() {
        let referencedIDs = Set(configuration.profiles.flatMap { profile in
            profile.entries.map(\.registeredWindowID)
        })
        configuration.registeredWindows.removeAll {
            !referencedIDs.contains($0.id)
        }
    }

    private func persistConfiguration() {
        store.saveConfiguration(configuration)
    }

    private func publishChange() {
        revision &+= 1
    }

    private func initialOrigin(for size: NSSize) -> CGPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? CGRect(
            x: 0,
            y: 0,
            width: 1440,
            height: 900
        )

        return CGPoint(
            x: min(max(mouse.x - size.width / 2, bounds.minX), bounds.maxX - size.width),
            y: min(max(mouse.y - size.height / 2, bounds.minY), bounds.maxY - size.height)
        ).integralPoint
    }

    private func normalizedFrame(_ storedFrame: CGRect) -> CGRect {
        guard !NSScreen.screens.contains(where: { $0.frame.intersects(storedFrame) }),
              let screen = NSScreen.main else {
            return storedFrame
        }

        var frame = storedFrame
        frame.origin = CGPoint(
            x: screen.visibleFrame.midX - frame.width / 2,
            y: screen.visibleFrame.midY - frame.height / 2
        )
        return frame.integral
    }
}

private struct HotKeyIdentity: Hashable {
    let keyCode: UInt16
    let modifiers: Set<HotKeyModifier>

    init(shortcut: HotKeyShortcut) {
        keyCode = shortcut.keyCode
        modifiers = shortcut.modifiers
    }
}

private extension CGPoint {
    var integralPoint: CGPoint {
        CGPoint(x: x.rounded(), y: y.rounded())
    }
}
