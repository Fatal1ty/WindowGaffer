import AppKit

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class OverlayWindowController: NSWindowController {
    private let overlayView: OverlayView

    init(
        label: String,
        frame: CGRect,
        onActivate: @escaping () -> Void,
        onSnapFrame: @escaping (CGRect) -> CGRect,
        onFrameChanged: @escaping (CGRect) -> Void,
        onRename: @escaping (String) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        let panel = OverlayPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlayView = OverlayView(frame: CGRect(origin: .zero, size: frame.size))

        super.init(window: panel)

        panel.contentView = overlayView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .none
        panel.worksWhenModal = true
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .canJoinAllApplications,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        overlayView.setLabel(label)
        overlayView.onActivate = onActivate
        overlayView.onSnapFrame = onSnapFrame
        overlayView.onFrameChanged = onFrameChanged
        overlayView.onRename = onRename
        overlayView.onOpenSettings = onOpenSettings
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func setEditing(_ editing: Bool) {
        overlayView.setEditing(editing)
    }

    func setLabel(_ label: String) {
        overlayView.setLabel(label)
    }

    func setAvailable(_ available: Bool) {
        overlayView.setAvailable(available)
    }
}
