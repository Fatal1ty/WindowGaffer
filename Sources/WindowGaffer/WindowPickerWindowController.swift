import AppKit
import SwiftUI

final class WindowPickerWindowController: NSWindowController, NSWindowDelegate {
    private var pickerModel: WindowPickerViewModel?

    init(
        catalog: WindowCatalog,
        permissionService: AccessibilityPermissionService
    ) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Add Window"
        panel.minSize = NSSize(width: 460, height: 400)
        panel.isReleasedWhenClosed = false

        super.init(window: panel)
        panel.delegate = self

        let model = WindowPickerViewModel(
            catalog: catalog,
            permissionService: permissionService,
            onCancel: { [weak self] in
                self?.close()
            }
        )
        pickerModel = model
        panel.contentViewController = NSHostingController(
            rootView: WindowPickerView(model: model)
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(onCreate: @escaping (WindowCandidate) -> Void) {
        guard let window else { return }
        pickerModel?.configure { [weak self] candidate in
            onCreate(candidate)
            self?.close()
        }
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        pickerModel?.refresh()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
