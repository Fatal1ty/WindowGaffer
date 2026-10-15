import AppKit
import WindowGafferCore
import SwiftUI

struct RegisteredWindowRow: View {
    let row: ProfileWindowDraftRow
    @ObservedObject var editor: ProfileEditorModel
    let onConfigureHotKey: (UUID, HotKeyShortcut?) -> Void

    @State private var isEditingName = false
    @State private var pendingName = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(14)

            Divider()

            overlayRow
                .padding(.horizontal, 14)
                .frame(minHeight: 46)

            Divider()
                .padding(.leading, 44)

            hotKeyRow
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(.separator, lineWidth: 1)
        }
        .onChange(of: isNameFocused) { _, focused in
            if !focused, isEditingName {
                finishNameEditing()
            }
        }
        .onChange(of: row.registration.displayName) { _, name in
            if !isEditingName {
                pendingName = name
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(nsImage: applicationIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                if isEditingName {
                    TextField("Window name", text: $pendingName)
                        .textFieldStyle(.plain)
                        .font(.headline)
                        .focused($isNameFocused)
                        .onSubmit {
                            isNameFocused = false
                        }
                } else {
                    Button(action: beginNameEditing) {
                        HStack(spacing: 6) {
                            Text(row.registration.displayName)
                                .font(.headline)
                                .lineLimit(1)
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Rename Window")
                }

                Text(targetDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let availability = row.availability {
                HStack(spacing: 5) {
                    Circle()
                        .fill(availability ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(availability ? "Available" : "Unavailable")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                editor.removeEntry(row.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove from Profile")
        }
    }

    private var overlayRow: some View {
        HStack(spacing: 10) {
            settingLabel("Overlay", symbol: "rectangle.on.rectangle")

            if row.entry.access.overlay != nil {
                TextField("Text or emoji", text: overlayText)
                    .textFieldStyle(.roundedBorder)
            } else {
                Spacer()
            }

            Toggle("Overlay", isOn: overlayEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var hotKeyRow: some View {
        HStack(spacing: 10) {
            settingLabel("Hotkey", symbol: "command")

            Button(row.entry.access.hotKey?.displayName ?? "Set Hotkey…") {
                onConfigureHotKey(row.id, row.entry.access.hotKey)
            }

            if row.entry.access.hotKey != nil {
                Button {
                    editor.setHotKey(entryID: row.id, hotKey: nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove Hotkey")
            }

            Spacer()
        }
    }

    private var overlayEnabled: Binding<Bool> {
        Binding(
            get: { row.entry.access.overlay != nil },
            set: { editor.setOverlayEnabled(entryID: row.id, enabled: $0) }
        )
    }

    private var overlayText: Binding<String> {
        Binding(
            get: { row.entry.access.overlay?.text ?? "" },
            set: { editor.updateOverlayText(entryID: row.id, text: $0) }
        )
    }

    private var targetDescription: String {
        let target = row.registration.target
        let application = target.applicationName.isEmpty
            ? target.bundleIdentifier
            : target.applicationName
        let automaticName = row.registration.automaticDisplayName
        if automaticName.localizedCaseInsensitiveCompare(application) == .orderedSame
            || row.registration.nameOverride == nil {
            return application
        }
        return "\(application) · \(automaticName)"
    }

    private var applicationIcon: NSImage {
        let target = row.registration.target
        if let icon = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == target.bundleIdentifier
                || $0.localizedName?.localizedCaseInsensitiveCompare(
                    target.applicationName
                ) == .orderedSame
        })?.icon {
            return icon
        }
        if let executablePath = target.executablePath,
           !executablePath.isEmpty {
            return NSWorkspace.shared.icon(forFile: executablePath)
        }
        if !target.bundleIdentifier.isEmpty,
           let applicationURL = NSWorkspace.shared.urlForApplication(
               withBundleIdentifier: target.bundleIdentifier
           ) {
            return NSWorkspace.shared.icon(forFile: applicationURL.path)
        }
        return NSImage(
            systemSymbolName: "app",
            accessibilityDescription: target.applicationName
        ) ?? NSImage()
    }

    private func settingLabel(
        _ title: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 26, height: 26)
            Text(title)
        }
        .frame(width: 100, alignment: .leading)
    }

    private func beginNameEditing() {
        pendingName = row.registration.nameOverride
            ?? row.registration.automaticDisplayName
        isEditingName = true
        DispatchQueue.main.async {
            isNameFocused = true
        }
    }

    private func finishNameEditing() {
        guard isEditingName else { return }
        isEditingName = false
        let cleanName = pendingName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let automaticName = row.registration.automaticDisplayName
        editor.updateNameOverride(
            entryID: row.id,
            value: cleanName == automaticName ? "" : cleanName
        )
    }
}
