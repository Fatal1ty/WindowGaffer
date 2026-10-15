import AppKit
import WindowGafferCore
import SwiftUI

final class MainWindowController: NSWindowController, NSWindowDelegate,
    NSToolbarDelegate {
    private static let contentSize = NSSize(width: 440, height: 430)
    private static let windowsToolbarItem = NSToolbarItem.Identifier(
        "io.windowgaffer.toolbar.windows"
    )
    private static let supportToolbarItem = NSToolbarItem.Identifier(
        "io.windowgaffer.toolbar.support"
    )

    private let appModel: AppModel
    private let editor: ProfileEditorModel
    private let diagnostics: DiagnosticsViewModel
    private let pickerController: WindowPickerWindowController
    private let navigation = SettingsNavigationModel()
    private var editingDismissalMonitor: Any?
    private var availabilityRefreshTimer: Timer?

    init(
        appModel: AppModel,
        catalog: WindowCatalog,
        permissionService: AccessibilityPermissionService
    ) {
        self.appModel = appModel
        editor = ProfileEditorModel(appModel: appModel)
        diagnostics = DiagnosticsViewModel(
            catalog: catalog,
            permissionService: permissionService
        )
        pickerController = WindowPickerWindowController(
            catalog: catalog,
            permissionService: permissionService
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = SettingsSection.windows.title
        window.isReleasedWhenClosed = false
        window.isRestorable = false

        super.init(window: window)
        window.delegate = self
        configureToolbar(for: window)
        let contentController = NSHostingController(
            rootView: WindowGafferSettingsView(
                editor: editor,
                diagnostics: diagnostics,
                navigation: navigation,
                onAddWindow: { [weak self] in
                    self?.presentWindowPicker()
                },
                onConfigureHotKey: { [weak self] entryID, current in
                    self?.configureHotKey(entryID: entryID, current: current)
                }
            )
        )
        contentController.preferredContentSize = Self.contentSize
        window.contentViewController = contentController
        window.setContentSize(Self.contentSize)
        configureEditingDismissal(for: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        availabilityRefreshTimer?.invalidate()
        if let editingDismissalMonitor {
            NSEvent.removeMonitor(editingDismissalMonitor)
        }
    }

    func present() {
        editor.synchronizeWithActiveProfile()
        diagnostics.refresh()
        startAvailabilityRefresh()
        guard let window else { return }
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func presentAndAddWindow() {
        present()
        presentWindowPicker()
    }

    func activeProfileDidChange() {
        editor.synchronizeWithActiveProfile()
    }

    func createProfileAndPresent() {
        present()
        editor.createProfile()
    }

    func windowWillClose(_ notification: Notification) {
        stopAvailabilityRefresh()
        NSApp.setActivationPolicy(.accessory)
    }

    private func startAvailabilityRefresh() {
        stopAvailabilityRefresh()
        appModel.refreshAvailability()

        let timer = Timer(
            timeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            self?.appModel.refreshAvailability()
        }
        availabilityRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopAvailabilityRefresh() {
        availabilityRefreshTimer?.invalidate()
        availabilityRefreshTimer = nil
    }

    func toolbarAllowedItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            Self.windowsToolbarItem,
            Self.supportToolbarItem
        ]
    }

    func toolbarDefaultItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        [
            Self.windowsToolbarItem,
            Self.supportToolbarItem,
            .flexibleSpace
        ]
    }

    func toolbarSelectableItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        [Self.windowsToolbarItem, Self.supportToolbarItem]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let section: SettingsSection
        let action: Selector
        switch itemIdentifier {
        case Self.windowsToolbarItem:
            section = .windows
            action = #selector(showWindows)
        case Self.supportToolbarItem:
            section = .permissions
            action = #selector(showSupport)
        default:
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = section.title
        item.paletteLabel = section.title
        item.toolTip = section.title
        item.image = NSImage(
            systemSymbolName: section.symbol,
            accessibilityDescription: section.title
        )
        item.target = self
        item.action = action
        return item
    }

    private func presentWindowPicker() {
        pickerController.present { [weak self] candidate in
            self?.editor.addWindow(candidate: candidate)
        }
    }

    private func configureToolbar(for window: NSWindow) {
        let toolbar = NSToolbar(identifier: "WindowGafferSettingsToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = Self.windowsToolbarItem
        window.toolbar = toolbar
        window.toolbarStyle = .preference
    }

    private func configureEditingDismissal(for window: NSWindow) {
        editingDismissalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak window] event in
            guard let window,
                  event.window === window,
                  let fieldEditor = window.firstResponder as? NSTextView,
                  let textField = fieldEditor.delegate as? NSTextField,
                  let hitView = window.contentView?.hitTest(
                      event.locationInWindow
                  ) else {
                return event
            }

            let clickedInsideEditor = hitView === fieldEditor
                || hitView === textField
                || hitView.isDescendant(of: textField)
            guard !clickedInsideEditor else { return event }

            DispatchQueue.main.async { [weak window, weak fieldEditor] in
                guard let window, let fieldEditor,
                      window.firstResponder === fieldEditor else {
                    return
                }
                window.makeFirstResponder(nil)
            }
            return event
        }
    }

    @objc private func showWindows() {
        selectSection(.windows, toolbarItem: Self.windowsToolbarItem)
    }

    @objc private func showSupport() {
        selectSection(.permissions, toolbarItem: Self.supportToolbarItem)
    }

    private func selectSection(
        _ section: SettingsSection,
        toolbarItem: NSToolbarItem.Identifier
    ) {
        navigation.selection = section
        window?.title = section.title
        window?.toolbar?.selectedItemIdentifier = toolbarItem
    }

    private func configureHotKey(
        entryID: UUID,
        current: HotKeyShortcut?
    ) {
        let recorder = HotKeyRecorderView(shortcut: current)
        let alert = NSAlert()
        alert.messageText = "Set Window Hotkey"
        alert.informativeText = "Press a modifier plus one key. Window Gaffer registers the shortcut with macOS; it does not synthesize keyboard events. Some games may still observe the physical key press before macOS switches windows."
        alert.accessoryView = recorder
        alert.addButton(withTitle: "Assign")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].isEnabled = current != nil
        recorder.onShortcutChanged = { shortcut in
            alert.buttons[0].isEnabled = shortcut != nil
        }

        var monitor: Any?
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                return event
            }
            return recorder.record(event) ? nil : event
        }
        defer {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        alert.window.initialFirstResponder = recorder
        guard alert.runModal() == .alertFirstButtonReturn,
              let shortcut = recorder.shortcut else {
            return
        }
        editor.setHotKey(entryID: entryID, hotKey: shortcut)
    }
}
