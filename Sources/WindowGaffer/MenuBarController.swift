import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let appModel: AppModel
    private let mainWindowController: MainWindowController
    private let editItem: NSMenuItem
    private let overlaysVisibilityItem: NSMenuItem
    private let profilesSubmenu = NSMenu(title: "Profiles")

    init(
        appModel: AppModel,
        mainWindowController: MainWindowController
    ) {
        self.appModel = appModel
        self.mainWindowController = mainWindowController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        editItem = NSMenuItem(
            title: "Edit Overlays",
            action: #selector(toggleEditing),
            keyEquivalent: "e"
        )
        overlaysVisibilityItem = NSMenuItem(
            title: appModel.areOverlaysVisible ? "Hide Overlays" : "Show Overlays",
            action: #selector(toggleOverlaysVisibility),
            keyEquivalent: ""
        )

        super.init()
        configureStatusItem()
        configureMenu()

        appModel.onEditingChanged = { [weak self] editing in
            self?.editItem.state = editing ? .on : .off
        }
        appModel.onOverlaysVisibilityChanged = { [weak self] visible in
            self?.overlaysVisibilityItem.title = visible ? "Hide Overlays" : "Show Overlays"
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(
                systemSymbolName: "rectangle.on.rectangle",
                accessibilityDescription: "Window Gaffer"
            )
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = "Window Gaffer"
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let openItem = NSMenuItem(
            title: "Open Window Gaffer…",
            action: #selector(openWindowGaffer),
            keyEquivalent: ","
        )
        openItem.target = self

        let addItem = NSMenuItem(
            title: "Add Window…",
            action: #selector(addWindow),
            keyEquivalent: "n"
        )
        addItem.target = self

        let profilesItem = NSMenuItem(title: "Profiles", action: nil, keyEquivalent: "")
        profilesItem.submenu = profilesSubmenu

        editItem.target = self
        overlaysVisibilityItem.target = self

        let quitItem = NSMenuItem(
            title: "Quit Window Gaffer",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self

        menu.addItem(openItem)
        menu.addItem(addItem)
        menu.addItem(.separator())
        menu.addItem(profilesItem)
        menu.addItem(.separator())
        menu.addItem(editItem)
        menu.addItem(overlaysVisibilityItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        editItem.state = appModel.isEditing ? .on : .off
        overlaysVisibilityItem.title = appModel.areOverlaysVisible
            ? "Hide Overlays"
            : "Show Overlays"
        rebuildProfilesMenu()
    }

    private func rebuildProfilesMenu() {
        profilesSubmenu.removeAllItems()

        for profile in appModel.profiles {
            let item = NSMenuItem(
                title: profile.name,
                action: #selector(selectProfile(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = profile.id.uuidString
            item.state = profile.id == appModel.activeProfileID ? .on : .off
            profilesSubmenu.addItem(item)
        }

        profilesSubmenu.addItem(.separator())

        let newProfileItem = NSMenuItem(
            title: "New Profile…",
            action: #selector(newProfile),
            keyEquivalent: ""
        )
        newProfileItem.target = self
        profilesSubmenu.addItem(newProfileItem)

        let manageItem = NSMenuItem(
            title: "Manage Profiles…",
            action: #selector(openWindowGaffer),
            keyEquivalent: ""
        )
        manageItem.target = self
        profilesSubmenu.addItem(manageItem)
    }

    @objc private func openWindowGaffer() {
        mainWindowController.present()
    }

    @objc private func addWindow() {
        mainWindowController.presentAndAddWindow()
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let rawID = sender.representedObject as? String,
              let id = UUID(uuidString: rawID) else { return }
        appModel.activateProfile(id)
    }

    @objc private func newProfile() {
        mainWindowController.createProfileAndPresent()
    }

    @objc private func toggleEditing() {
        appModel.toggleEditing()
    }

    @objc private func toggleOverlaysVisibility() {
        appModel.toggleOverlaysVisibility()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
