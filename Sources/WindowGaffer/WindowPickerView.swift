import AppKit
import SwiftUI

struct WindowPickerView: View {
    @ObservedObject var model: WindowPickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a window")
                .font(.title2.weight(.semibold))

            if model.permissionRequired {
                permissionView
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search windows", text: $model.searchText)
                        .textFieldStyle(.plain)
                    if !model.searchText.isEmpty {
                        Button {
                            model.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear Search")
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.separator, lineWidth: 1)
                }

                windowList
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                if !model.permissionRequired {
                    Button("Refresh") {
                        model.refresh()
                    }
                    .disabled(model.isLoading)
                }

                Spacer()

                Button("Cancel", role: .cancel) {
                    model.cancel()
                }

                Button("Register Window") {
                    model.create()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canCreate || model.permissionRequired)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 400)
        .onAppear {
            model.refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            model.refresh()
        }
    }

    private var windowList: some View {
        Group {
            if model.isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Reading open windows…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.groups.isEmpty {
                ContentUnavailableView(
                    "No Windows Found",
                    systemImage: "macwindow",
                    description: Text("Open a window in another application and refresh the list.")
                )
            } else if model.filteredGroups.isEmpty {
                ContentUnavailableView(
                    "No Matching Windows",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different application or window name.")
                )
            } else {
                List {
                    ForEach(model.filteredGroups) { group in
                        Section {
                            ForEach(group.windows) { candidate in
                                windowRow(candidate)
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Image(nsImage: group.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                Text(group.applicationName)
                                    .font(.headline)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionView: some View {
        ContentUnavailableView {
            Label("Accessibility Access Required", systemImage: "hand.raised.fill")
        } description: {
            Text("Window Gaffer uses Accessibility only to list and focus windows. It never captures their contents.")
        } actions: {
            HStack {
                Button("Grant Access") {
                    model.requestPermission()
                }
                .buttonStyle(.borderedProminent)

                Button("Open System Settings") {
                    model.openSystemSettings()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func windowRow(_ candidate: WindowCandidate) -> some View {
        Button {
            model.select(candidate)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: model.selectedWindowID == candidate.id
                      ? "checkmark.circle.fill"
                      : "circle")
                    .foregroundStyle(
                        model.selectedWindowID == candidate.id
                            ? Color.accentColor
                            : Color.secondary
                    )

                Text(candidate.title)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if candidate.isFullScreen {
                    Text("Full Screen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if candidate.isMinimized {
                    Text("Minimized")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if candidate.usesProcessFallback {
                    Text("Process")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(candidate.applicationName), \(candidate.title)")
    }
}
