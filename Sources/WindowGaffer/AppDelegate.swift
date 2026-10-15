import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appModel: AppModel?
    private var mainWindowController: MainWindowController?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()

        let permissionService = AccessibilityPermissionService()
        let catalog = WindowCatalog(permissionService: permissionService)
        let model = AppModel(
            catalog: catalog,
            focusService: WindowFocusService(),
            store: OverlayStore(),
            hotKeyManager: GlobalHotKeyManager()
        )

        let mainWindowController = MainWindowController(
            appModel: model,
            catalog: catalog,
            permissionService: permissionService
        )

        appModel = model
        self.mainWindowController = mainWindowController
        menuBarController = MenuBarController(
            appModel: model,
            mainWindowController: mainWindowController
        )

        model.onOpenSettingsRequested = { [weak mainWindowController] in
            mainWindowController?.present()
        }
        model.onActiveProfileChanged = { [weak mainWindowController] in
            mainWindowController?.activeProfileDidChange()
        }

        model.restore()
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Window Gaffer")
        applicationMenu.addItem(
            NSMenuItem(
                title: "Quit Window Gaffer",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(
            NSMenuItem(
                title: "Undo",
                action: Selector(("undo:")),
                keyEquivalent: "z"
            )
        )
        editMenu.addItem(
            NSMenuItem(
                title: "Redo",
                action: Selector(("redo:")),
                keyEquivalent: "Z"
            )
        )
        editMenu.addItem(.separator())
        editMenu.addItem(
            NSMenuItem(
                title: "Cut",
                action: #selector(NSText.cut(_:)),
                keyEquivalent: "x"
            )
        )
        editMenu.addItem(
            NSMenuItem(
                title: "Copy",
                action: #selector(NSText.copy(_:)),
                keyEquivalent: "c"
            )
        )
        editMenu.addItem(
            NSMenuItem(
                title: "Paste",
                action: #selector(NSText.paste(_:)),
                keyEquivalent: "v"
            )
        )
        editMenu.addItem(
            NSMenuItem(
                title: "Select All",
                action: #selector(NSText.selectAll(_:)),
                keyEquivalent: "a"
            )
        )
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}
