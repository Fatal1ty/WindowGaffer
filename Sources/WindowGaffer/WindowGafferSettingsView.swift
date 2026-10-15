import AppKit
import WindowGafferCore
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case windows
    case permissions

    var id: Self { self }

    var title: String {
        switch self {
        case .windows: "Windows"
        case .permissions: "Support"
        }
    }

    var symbol: String {
        switch self {
        case .windows: "macwindow.on.rectangle"
        case .permissions: "lock.shield"
        }
    }
}

final class SettingsNavigationModel: ObservableObject {
    @Published var selection: SettingsSection = .windows
}

struct WindowGafferSettingsView: View {
    @ObservedObject var editor: ProfileEditorModel
    @ObservedObject var diagnostics: DiagnosticsViewModel
    @ObservedObject var navigation: SettingsNavigationModel

    let onAddWindow: () -> Void
    let onConfigureHotKey: (UUID, HotKeyShortcut?) -> Void

    var body: some View {
        Group {
            switch navigation.selection {
            case .windows:
                windowsView
            case .permissions:
                permissionsView
            }
        }
        .frame(width: 440, height: 430)
    }

    private var windowsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileHeader
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 14)

            Divider()

            if editor.rows.isEmpty {
                ContentUnavailableView {
                    Label("No Registered Windows", systemImage: "macwindow.badge.plus")
                } description: {
                    Text("Add a window, then enable its overlay or assign a hotkey.")
                } actions: {
                    Button("Add Window…", action: onAddWindow)
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(editor.rows) { row in
                            RegisteredWindowRow(
                                row: row,
                                editor: editor,
                                onConfigureHotKey: onConfigureHotKey
                            )
                        }
                    }
                    .padding(16)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button("Add Window…", action: onAddWindow)

                Spacer()

                if let error = editor.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

                Button("Revert") {
                    editor.revert()
                }
                .disabled(!editor.isDirty)
                .help("Revert Unsaved Changes")

                Button("Save Profile") {
                    editor.save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!editor.isDirty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Profile")
                    .font(.headline)

                Spacer()

                Picker("Active profile", selection: profileSelection) {
                    ForEach(editor.profiles) { profile in
                        Text(profileLabel(profile)).tag(profile.id)
                    }
                }
                .labelsHidden()
                .frame(width: 180)

                Button {
                    editor.createProfile()
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create Profile")

                Button(role: .destructive) {
                    editor.deleteSelectedProfile()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete Profile")
                .disabled(editor.profile.isDefault)
            }

            if !editor.profile.isDefault {
                HStack(spacing: 10) {
                    Text("Profile name")
                        .foregroundStyle(.secondary)
                    TextField("Profile name", text: profileName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                }
            }
        }
    }

    private var permissionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                settingsCard(
                    title: "Accessibility",
                    description: "Required to list windows and ask macOS to focus the selected one.",
                    enabled: diagnostics.accessibilityEnabled
                ) {
                    if diagnostics.accessibilityEnabled {
                        Button("Open System Settings") {
                            diagnostics.openAccessibilitySettings()
                        }
                    } else {
                        Button("Grant Access") {
                            diagnostics.requestAccessibilityAccess()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Open System Settings") {
                            diagnostics.openAccessibilitySettings()
                        }
                    }
                }

                settingsCard(
                    title: "Detailed Window Names",
                    description: "Optional. Lets Window Gaffer read better metadata for apps and game runtimes that hide their window titles. No screenshots or pixels are read.",
                    enabled: diagnostics.detailedNamesEnabled
                ) {
                    if diagnostics.detailedNamesEnabled {
                        Text("Enabled")
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Enable Detailed Window Names…") {
                            diagnostics.enableDetailedWindowNames()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Diagnostics")
                        .font(.headline)
                    Text("Copy a metadata-only report to include in a future bug report. It contains window and process names, but never screenshots or pixels.")
                        .foregroundStyle(.secondary)
                    Button(
                        diagnostics.isCopyingDiagnostics
                            ? "Collecting…"
                            : diagnostics.diagnosticsCopied
                                ? "Copied"
                                : "Copy Window Diagnostics"
                    ) {
                        diagnostics.copyWindowDiagnostics()
                    }
                    .disabled(diagnostics.isCopyingDiagnostics)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))

                if let message = diagnostics.statusMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: 440, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear {
            diagnostics.refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            diagnostics.refresh()
        }
    }

    private func settingsCard<Actions: View>(
        title: String,
        description: String,
        enabled: Bool,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(enabled ? .green : .secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10, content: actions)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var profileSelection: Binding<UUID> {
        Binding(
            get: { editor.selectedProfileID },
            set: { editor.selectProfile($0) }
        )
    }

    private var profileName: Binding<String> {
        Binding(
            get: { editor.profile.name },
            set: { editor.updateProfileName($0) }
        )
    }

    private func profileLabel(_ profile: WindowProfile) -> String {
        if profile.id == editor.selectedProfileID {
            return editor.profile.name
        }
        return profile.name
    }
}
