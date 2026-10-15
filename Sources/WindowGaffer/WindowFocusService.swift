import AppKit
import ApplicationServices

final class WindowFocusService {
    private let workerQueue = DispatchQueue(
        label: "io.windowgaffer.window-focus",
        qos: .userInitiated
    )

    func focus(
        _ handle: WindowHandle,
        completion: @escaping (Bool) -> Void
    ) {
        workerQueue.async {
            let application = NSRunningApplication(
                processIdentifier: handle.processIdentifier
            )
            if application?.isTerminated == true {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let applicationElement = AXUIElementCreateApplication(
                handle.processIdentifier
            )
            AXUIElementSetMessagingTimeout(applicationElement, 0.6)

            _ = application?.unhide()
            let activationRequested = application?.activate(options: []) ?? false
            let frontmostResult = AXUIElementSetAttributeValue(
                applicationElement,
                kAXFrontmostAttribute as CFString,
                kCFBooleanTrue
            )

            guard let windowElement = handle.element else {
                let success = activationRequested || frontmostResult == .success
                DispatchQueue.main.async { completion(success) }
                return
            }

            AXUIElementSetMessagingTimeout(windowElement, 0.6)

            if let minimized = Self.boolAttribute(
                windowElement,
                kAXMinimizedAttribute as CFString
            ), minimized {
                AXUIElementSetAttributeValue(
                    windowElement,
                    kAXMinimizedAttribute as CFString,
                    kCFBooleanFalse
                )
            }

            AXUIElementSetAttributeValue(
                applicationElement,
                kAXFocusedWindowAttribute as CFString,
                windowElement
            )
            AXUIElementSetAttributeValue(
                windowElement,
                kAXMainAttribute as CFString,
                kCFBooleanTrue
            )
            let raiseResult = AXUIElementPerformAction(
                windowElement,
                kAXRaiseAction as CFString
            )

            let success = (activationRequested || frontmostResult == .success)
                && (raiseResult == .success || raiseResult == .cannotComplete)

            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    private static func boolAttribute(
        _ element: AXUIElement,
        _ name: CFString
    ) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success
        else {
            return nil
        }
        return value as? Bool
    }
}
