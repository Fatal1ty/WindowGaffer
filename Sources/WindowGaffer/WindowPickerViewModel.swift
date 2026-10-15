import Combine
import Foundation

final class WindowPickerViewModel: ObservableObject {
    @Published private(set) var groups: [ApplicationWindowGroup] = []
    @Published var selectedWindowID: UUID?
    @Published var searchText = ""
    @Published private(set) var isLoading = false
    @Published private(set) var permissionRequired = false
    @Published private(set) var errorMessage: String?

    private let catalog: WindowCatalog
    private let permissionService: AccessibilityPermissionService
    private var onCreate: ((WindowCandidate) -> Void)?
    private let onCancel: () -> Void

    init(
        catalog: WindowCatalog,
        permissionService: AccessibilityPermissionService,
        onCancel: @escaping () -> Void
    ) {
        self.catalog = catalog
        self.permissionService = permissionService
        self.onCancel = onCancel
    }

    var selectedWindow: WindowCandidate? {
        filteredGroups.lazy
            .flatMap(\.windows)
            .first { $0.id == selectedWindowID }
    }

    var canCreate: Bool {
        selectedWindow != nil
    }

    var filteredGroups: [ApplicationWindowGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return groups }

        return groups.compactMap { group in
            let windows = group.windows.filter { candidate in
                Self.matches(candidate.applicationName, query: query)
                    || Self.matches(candidate.title, query: query)
                    || Self.matches(
                        candidate.handle.descriptor.bundleIdentifier,
                        query: query
                    )
            }
            guard !windows.isEmpty else { return nil }
            return ApplicationWindowGroup(
                id: group.id,
                applicationName: group.applicationName,
                icon: group.icon,
                windows: windows,
                isActive: group.isActive
            )
        }
    }

    func configure(onCreate: @escaping (WindowCandidate) -> Void) {
        self.onCreate = onCreate
        selectedWindowID = nil
        searchText = ""
    }

    func refresh() {
        errorMessage = nil
        permissionRequired = !permissionService.isTrusted

        guard !permissionRequired else {
            groups = []
            selectedWindowID = nil
            isLoading = false
            return
        }

        isLoading = true
        catalog.fetchGroups { [weak self] result in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case let .success(groups):
                self.groups = groups
                self.permissionRequired = false

                if let selectedWindowID,
                   groups.contains(where: {
                       $0.windows.contains(where: { $0.id == selectedWindowID })
                   }) {
                    return
                }

                if let first = groups.first?.windows.first {
                    self.select(first)
                } else {
                    self.selectedWindowID = nil
                }

            case let .failure(error as WindowCatalogError):
                self.permissionRequired = true
                self.errorMessage = error.localizedDescription

            case let .failure(error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func select(_ candidate: WindowCandidate) {
        selectedWindowID = candidate.id
    }

    func requestPermission() {
        if permissionService.requestAccess() {
            refresh()
        } else {
            permissionRequired = true
        }
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }

    func create() {
        guard let selectedWindow, canCreate else { return }
        onCreate?(selectedWindow)
    }

    func cancel() {
        onCancel()
    }

    private static func matches(_ value: String, query: String) -> Bool {
        value.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }
}
