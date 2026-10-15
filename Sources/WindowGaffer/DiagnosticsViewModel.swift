import AppKit
import Combine
import CoreGraphics

final class DiagnosticsViewModel: ObservableObject {
    private let catalog: WindowCatalog
    private let permissionService: AccessibilityPermissionService

    @Published private(set) var accessibilityEnabled = false
    @Published private(set) var detailedNamesEnabled = false
    @Published private(set) var isCopyingDiagnostics = false
    @Published private(set) var diagnosticsCopied = false
    @Published private(set) var statusMessage: String?

    init(
        catalog: WindowCatalog,
        permissionService: AccessibilityPermissionService
    ) {
        self.catalog = catalog
        self.permissionService = permissionService
        refresh()
    }

    func refresh() {
        accessibilityEnabled = permissionService.isTrusted
        detailedNamesEnabled = CGPreflightScreenCaptureAccess()
    }

    func requestAccessibilityAccess() {
        accessibilityEnabled = permissionService.requestAccess()
        statusMessage = nil
    }

    func openAccessibilitySettings() {
        permissionService.openSystemSettings()
    }

    func enableDetailedWindowNames() {
        if CGPreflightScreenCaptureAccess() {
            detailedNamesEnabled = true
            return
        }

        let alert = NSAlert()
        alert.messageText = "Enable Detailed Window Names?"
        alert.informativeText = "macOS limits access to some window names unless Window Gaffer has Screen & System Audio Recording permission. Window Gaffer uses this permission only to read window metadata; it does not capture or store images."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let granted = CGRequestScreenCaptureAccess()
        refresh()
        if granted {
            statusMessage = "Detailed names enabled. Restart Window Gaffer if some names do not update immediately."
            return
        }

        statusMessage = "Detailed names are still disabled. You can enable them in System Settings."
        guard let settingsURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(settingsURL)
    }

    func copyWindowDiagnostics() {
        guard !isCopyingDiagnostics else { return }
        isCopyingDiagnostics = true
        diagnosticsCopied = false

        catalog.diagnosticReport { [weak self] report in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(report, forType: .string)
            self?.isCopyingDiagnostics = false
            self?.diagnosticsCopied = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.diagnosticsCopied = false
            }
        }
    }
}
