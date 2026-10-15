import Foundation
import XCTest
@testable import WindowGafferCore

final class OverlayRecordTests: XCTestCase {
    func testDecodesDescriptorWithoutOptionalStableWindowFields() throws {
        let data = Data(
            """
            {
              "bundleIdentifier": "com.example.Editor",
              "applicationName": "Editor",
              "windowTitle": "Document"
            }
            """.utf8
        )

        let descriptor = try JSONDecoder().decode(
            WindowTargetDescriptor.self,
            from: data
        )

        XCTAssertEqual(descriptor.windowTitle, "Document")
        XCTAssertNil(descriptor.windowIdentifier)
        XCTAssertNil(descriptor.document)
        XCTAssertNil(descriptor.executablePath)
    }

    func testRegisteredWindowUsesBestAutomaticName() {
        let titled = RegisteredWindow(
            target: WindowTargetDescriptor(
                bundleIdentifier: "com.example.EVE",
                applicationName: "EVE",
                windowTitle: "EVE - Pilot"
            )
        )
        let untitled = RegisteredWindow(
            target: WindowTargetDescriptor(
                bundleIdentifier: "com.example.Editor",
                applicationName: "Editor",
                windowTitle: "  "
            )
        )

        XCTAssertEqual(titled.displayName, "EVE - Pilot")
        XCTAssertEqual(untitled.displayName, "Editor")
    }

    func testOptionalNameOverrideIsIndependentFromOverlayText() {
        let registration = RegisteredWindow(
            nameOverride: "Main character",
            target: WindowTargetDescriptor(
                bundleIdentifier: "com.example.EVE",
                applicationName: "EVE",
                windowTitle: "EVE - Pilot"
            )
        )
        let entry = ProfileWindowEntry(
            registeredWindowID: registration.id,
            access: WindowAccessConfiguration(
                overlay: OverlayConfiguration(
                    text: "🥷",
                    frame: CGRect(x: 10, y: 20, width: 100, height: 60)
                )
            )
        )

        XCTAssertEqual(registration.displayName, "Main character")
        XCTAssertEqual(entry.access.overlay?.text, "🥷")
    }

    func testEmptyConfigurationProvidesDefaultProfile() {
        let configuration = WindowGafferConfiguration.empty()

        XCTAssertEqual(configuration.profiles.count, 1)
        XCTAssertTrue(configuration.profiles[0].isDefault)
        XCTAssertEqual(configuration.activeProfileID, configuration.profiles[0].id)
    }

    func testConfigurationRoundTripsProfilesAndAccess() throws {
        let registration = RegisteredWindow(
            target: WindowTargetDescriptor(
                bundleIdentifier: "com.example.EVE",
                applicationName: "EVE",
                windowTitle: "EVE - Pilot"
            )
        )
        let entry = ProfileWindowEntry(
            registeredWindowID: registration.id,
            access: WindowAccessConfiguration(
                overlay: OverlayConfiguration(
                    text: "🥷",
                    frame: CGRect(x: 10, y: 20, width: 100, height: 60)
                ),
                hotKey: HotKeyShortcut(
                    keyCode: 18,
                    modifiers: [.control, .option],
                    keyDisplay: "1"
                )
            )
        )
        let profile = WindowProfile(name: "EVE", entries: [entry])
        let configuration = WindowGafferConfiguration(
            registeredWindows: [registration],
            profiles: [profile],
            activeProfileID: profile.id
        )

        let decoded = try JSONDecoder().decode(
            WindowGafferConfiguration.self,
            from: JSONEncoder().encode(configuration)
        )

        XCTAssertEqual(decoded, configuration)
    }

    func testAutomaticFallbackIsAllowedForOneSavedTarget() {
        let target = makeTarget(title: "Pilot One")

        XCTAssertTrue(
            AutomaticRebindingPolicy.allowsSingleCandidateFallback(
                for: target,
                among: [target]
            )
        )
    }

    func testAutomaticFallbackIsRejectedForDistinctTargetsOfSameApplication() {
        let first = makeTarget(title: "Pilot One")
        let second = makeTarget(title: "Pilot Two")

        XCTAssertFalse(
            AutomaticRebindingPolicy.allowsSingleCandidateFallback(
                for: first,
                among: [first, second]
            )
        )
    }

    func testAutomaticFallbackAllowsIntentionalDuplicateTargets() {
        let target = makeTarget(title: "Pilot One")

        XCTAssertTrue(
            AutomaticRebindingPolicy.allowsSingleCandidateFallback(
                for: target,
                among: [target, target]
            )
        )
    }

    func testAutomaticFallbackIgnoresTargetsFromOtherApplications() {
        let eve = makeTarget(title: "Pilot One")
        let editor = WindowTargetDescriptor(
            bundleIdentifier: "com.example.Editor",
            applicationName: "Editor",
            windowTitle: "Document"
        )

        XCTAssertTrue(
            AutomaticRebindingPolicy.allowsSingleCandidateFallback(
                for: eve,
                among: [eve, editor]
            )
        )
    }

    func testReusedAccessibilityIdentifierDoesNotOverrideDifferentTitles() {
        let saved = WindowTargetDescriptor(
            bundleIdentifier: "com.example.EVE",
            applicationName: "EVE",
            windowTitle: "Pilot One",
            windowIdentifier: "main-window"
        )
        let candidate = WindowTargetDescriptor(
            bundleIdentifier: "com.example.EVE",
            applicationName: "EVE",
            windowTitle: "Pilot Two",
            windowIdentifier: "main-window"
        )

        XCTAssertFalse(
            WindowTargetMatchingPolicy.isHighConfidenceMatch(candidate, saved)
        )
    }

    func testMatchingDocumentAllowsAChangedWindowTitle() {
        let saved = WindowTargetDescriptor(
            bundleIdentifier: "com.example.Editor",
            applicationName: "Editor",
            windowTitle: "Draft",
            document: "file:///tmp/report.txt"
        )
        let candidate = WindowTargetDescriptor(
            bundleIdentifier: "com.example.Editor",
            applicationName: "Editor",
            windowTitle: "Draft — Edited",
            document: "file:///tmp/report.txt"
        )

        XCTAssertTrue(
            WindowTargetMatchingPolicy.isHighConfidenceMatch(candidate, saved)
        )
    }

    private func makeTarget(title: String) -> WindowTargetDescriptor {
        WindowTargetDescriptor(
            bundleIdentifier: "com.example.EVE",
            applicationName: "EVE",
            windowTitle: title,
            executablePath: "/Applications/EVE.app/Contents/MacOS/EVE"
        )
    }
}
