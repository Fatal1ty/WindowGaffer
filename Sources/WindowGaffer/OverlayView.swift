import AppKit

final class OverlayView: NSView {
    private enum ResizeHandle: CaseIterable {
        case bottomLeft
        case bottomRight
        case topLeft
        case topRight

        var affectsLeftEdge: Bool {
            self == .bottomLeft || self == .topLeft
        }

        var affectsBottomEdge: Bool {
            self == .bottomLeft || self == .bottomRight
        }
    }

    private let labelField = NSTextField(labelWithString: "")
    private var trackingAreaReference: NSTrackingArea?
    private var mouseDownLocation = CGPoint.zero
    private var startingWindowFrame = CGRect.zero
    private var didDrag = false
    private var activeResizeHandle: ResizeHandle?

    private let resizeHandleHitSize: CGFloat = 18
    private let resizeHandleVisualSize: CGFloat = 6

    private(set) var isEditing = false
    private(set) var isAvailable = true

    var onActivate: (() -> Void)?
    var onSnapFrame: ((CGRect) -> CGRect)?
    var onFrameChanged: ((CGRect) -> Void)?
    var onRename: ((String) -> Void)?
    var onOpenSettings: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.masksToBounds = false

        labelField.font = OverlayMetrics.font
        labelField.alignment = .center
        labelField.textColor = .labelColor
        labelField.lineBreakMode = .byWordWrapping
        labelField.maximumNumberOfLines = 3
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.isSelectable = false
        labelField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addSubview(labelField)
        NSLayoutConstraint.activate([
            labelField.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: OverlayMetrics.horizontalPadding
            ),
            labelField.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -OverlayMetrics.horizontalPadding
            ),
            labelField.topAnchor.constraint(
                equalTo: topAnchor,
                constant: OverlayMetrics.verticalPadding
            ),
            labelField.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -OverlayMetrics.verticalPadding
            )
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [
                .activeAlways,
                .inVisibleRect,
                .mouseEnteredAndExited,
                .mouseMoved
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
        super.updateTrackingAreas()
    }

    // A nonactivating panel does not opt into mouse-move delivery by default.
    // Explicitly consuming these events prevents AppKit from routing hover
    // traffic to the full-screen window underneath the overlay.
    override func mouseMoved(with event: NSEvent) {}

    override func mouseEntered(with event: NSEvent) {}

    override func mouseExited(with event: NSEvent) {}

    func setLabel(_ label: String) {
        labelField.stringValue = label
        setAccessibilityLabel(label)
    }

    func setEditing(_ editing: Bool) {
        isEditing = editing
        activeResizeHandle = nil
        updateToolTip()
        needsDisplay = true
        discardCursorRects()
        window?.invalidateCursorRects(for: self)
    }

    func setAvailable(_ available: Bool) {
        isAvailable = available
        labelField.alphaValue = available ? 1 : 0.55
        updateToolTip()
        needsDisplay = true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isEditing ? .openHand : .pointingHand)

        if isEditing {
            for handle in ResizeHandle.allCases {
                addCursorRect(hitRect(for: handle), cursor: .crosshair)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let shapeRect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(
            roundedRect: shapeRect,
            xRadius: 11,
            yRadius: 11
        )

        NSColor.controlBackgroundColor
            .withAlphaComponent(isAvailable ? 0.94 : 0.76)
            .setFill()
        path.fill()

        if isEditing {
            NSColor(
                calibratedRed: 0.78,
                green: 1,
                blue: 0.24,
                alpha: 0.95
            ).setStroke()
            path.lineWidth = 2
            path.stroke()
            drawResizeHandles()
        } else if !isAvailable {
            NSColor.systemOrange.withAlphaComponent(0.8).setStroke()
            path.lineWidth = 1.5
            path.setLineDash([4, 3], count: 2, phase: 0)
            path.stroke()
        } else {
            NSColor.separatorColor.withAlphaComponent(0.45).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        mouseDownLocation = NSEvent.mouseLocation
        startingWindowFrame = window?.frame ?? .zero
        activeResizeHandle = nil

        if isEditing {
            let location = convert(event.locationInWindow, from: nil)
            activeResizeHandle = resizeHandle(at: location)

            if event.clickCount == 2, activeResizeHandle == nil {
                presentRenameDialog()
                return
            }

            (activeResizeHandle == nil ? NSCursor.closedHand : NSCursor.crosshair)
                .set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEditing, let window else {
            return
        }

        let current = NSEvent.mouseLocation
        let delta = CGPoint(
            x: current.x - mouseDownLocation.x,
            y: current.y - mouseDownLocation.y
        )

        if abs(delta.x) > 2 || abs(delta.y) > 2 {
            didDrag = true
        }

        if let activeResizeHandle {
            let resized = resizedFrame(
                from: startingWindowFrame,
                delta: delta,
                handle: activeResizeHandle
            )
            window.setFrame(resized, display: true)
        } else {
            var proposed = startingWindowFrame
            proposed.origin = CGPoint(
                x: startingWindowFrame.origin.x + delta.x,
                y: startingWindowFrame.origin.y + delta.y
            )

            let snapped = onSnapFrame?(proposed) ?? proposed.integral
            window.setFrameOrigin(snapped.origin)
        }
        onFrameChanged?(window.frame)
    }

    override func mouseUp(with event: NSEvent) {
        if isEditing {
            activeResizeHandle = nil
            NSCursor.openHand.set()
            if let frame = window?.frame {
                onFrameChanged?(frame)
            }
            return
        }

        guard !didDrag else {
            return
        }
        onActivate?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard isEditing else { return nil }

        let menu = NSMenu()
        let renameItem = NSMenuItem(
            title: "Rename…",
            action: #selector(renameFromMenu),
            keyEquivalent: ""
        )
        renameItem.target = self
        menu.addItem(renameItem)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: "Open Window Gaffer…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        return menu
    }

    private func resizeHandle(at point: CGPoint) -> ResizeHandle? {
        ResizeHandle.allCases.first { hitRect(for: $0).contains(point) }
    }

    private func hitRect(for handle: ResizeHandle) -> CGRect {
        let center = handleCenter(for: handle)
        return CGRect(
            x: center.x - resizeHandleHitSize / 2,
            y: center.y - resizeHandleHitSize / 2,
            width: resizeHandleHitSize,
            height: resizeHandleHitSize
        )
    }

    private func handleCenter(for handle: ResizeHandle) -> CGPoint {
        let inset = resizeHandleHitSize / 3

        switch handle {
        case .bottomLeft:
            return CGPoint(x: inset, y: inset)
        case .bottomRight:
            return CGPoint(x: bounds.maxX - inset, y: inset)
        case .topLeft:
            return CGPoint(x: inset, y: bounds.maxY - inset)
        case .topRight:
            return CGPoint(x: bounds.maxX - inset, y: bounds.maxY - inset)
        }
    }

    private func drawResizeHandles() {
        for handle in ResizeHandle.allCases {
            let center = handleCenter(for: handle)
            let rect = CGRect(
                x: center.x - resizeHandleVisualSize / 2,
                y: center.y - resizeHandleVisualSize / 2,
                width: resizeHandleVisualSize,
                height: resizeHandleVisualSize
            )
            NSColor.controlBackgroundColor.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: -1, dy: -1)).fill()
            NSColor(
                calibratedRed: 0.56,
                green: 0.78,
                blue: 0.08,
                alpha: 1
            ).setFill()
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    private func resizedFrame(
        from initialFrame: CGRect,
        delta: CGPoint,
        handle: ResizeHandle
    ) -> CGRect {
        let rawWidth = handle.affectsLeftEdge
            ? initialFrame.width - delta.x
            : initialFrame.width + delta.x
        let rawHeight = handle.affectsBottomEdge
            ? initialFrame.height - delta.y
            : initialFrame.height + delta.y
        let steppedSize = OverlayMetrics.steppedSize(
            for: NSSize(width: rawWidth, height: rawHeight)
        )

        var result = initialFrame
        result.size = steppedSize

        if handle.affectsLeftEdge {
            result.origin.x = initialFrame.maxX - steppedSize.width
        }
        if handle.affectsBottomEdge {
            result.origin.y = initialFrame.maxY - steppedSize.height
        }

        return result.integral
    }

    @objc private func renameFromMenu() {
        presentRenameDialog()
    }

    @objc private func openSettingsFromMenu() {
        onOpenSettings?()
    }

    private func presentRenameDialog() {
        guard isEditing else { return }

        NSApp.activate(ignoringOtherApps: true)
        let input = NSTextField(string: labelField.stringValue)
        input.frame = NSRect(x: 0, y: 0, width: 260, height: 24)

        let alert = NSAlert()
        alert.messageText = "Rename Overlay"
        alert.informativeText = "Enter any text or emoji."
        alert.accessoryView = input
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        alert.window.initialFirstResponder = input
        input.selectText(nil)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let cleanLabel = input.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleanLabel.isEmpty else { return }
        onRename?(cleanLabel)
    }

    private func updateToolTip() {
        if !isAvailable {
            toolTip = "The linked window is no longer available."
            return
        }

        toolTip = isEditing
            ? "Drag to move · Drag a corner to resize · Double-click to edit overlay text"
            : nil
    }
}
