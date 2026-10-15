import AppKit
import Combine
import WindowGafferCore

struct ProfileWindowDraftRow: Identifiable {
    let entry: ProfileWindowEntry
    let registration: RegisteredWindow
    let availability: Bool?

    var id: UUID { entry.id }
}

private struct ProfileDraft {
    var profile: WindowProfile
    var registrations: [UUID: RegisteredWindow]
    var savedProfile: WindowProfile
    var savedRegistrations: [UUID: RegisteredWindow]

    var isDirty: Bool {
        profile != savedProfile || registrations != savedRegistrations
    }
}

final class ProfileEditorModel: ObservableObject {
    private let appModel: AppModel
    private var drafts: [UUID: ProfileDraft] = [:]
    private var cancellables: Set<AnyCancellable> = []

    @Published private(set) var selectedProfileID: UUID
    @Published private(set) var revision = 0
    @Published private(set) var errorMessage: String?

    init(appModel: AppModel) {
        self.appModel = appModel
        selectedProfileID = appModel.activeProfileID
        drafts[selectedProfileID] = Self.makeDraft(
            profileID: selectedProfileID,
            appModel: appModel
        )

        appModel.$revision
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                refreshCleanDraftFromSavedConfiguration()
                publishChange()
            }
            .store(in: &cancellables)
    }

    var profiles: [WindowProfile] {
        appModel.profiles
    }

    var profile: WindowProfile {
        draft.profile
    }

    var rows: [ProfileWindowDraftRow] {
        draft.profile.entries.compactMap { entry in
            guard let registration = draft.registrations[entry.registeredWindowID] else {
                return nil
            }
            return ProfileWindowDraftRow(
                entry: entry,
                registration: registration,
                availability: selectedProfileID == appModel.activeProfileID
                    ? appModel.isEntryAvailable(entry.id)
                    : nil
            )
        }
    }

    var isDirty: Bool {
        draft.isDirty
    }

    func selectProfile(_ id: UUID) {
        guard id != selectedProfileID,
              appModel.profiles.contains(where: { $0.id == id }) else {
            return
        }

        selectedProfileID = id
        if drafts[id] == nil {
            drafts[id] = Self.makeDraft(profileID: id, appModel: appModel)
        }
        appModel.activateProfile(id)
        errorMessage = nil
        publishChange()
    }

    func synchronizeWithActiveProfile() {
        let activeID = appModel.activeProfileID
        guard activeID != selectedProfileID else {
            refreshCleanDraftFromSavedConfiguration()
            publishChange()
            return
        }
        selectedProfileID = activeID
        if drafts[activeID] == nil || drafts[activeID]?.isDirty == false {
            drafts[activeID] = Self.makeDraft(
                profileID: activeID,
                appModel: appModel
            )
        }
        publishChange()
    }

    func createProfile() {
        let id = appModel.createProfile()
        selectedProfileID = id
        drafts[id] = Self.makeDraft(profileID: id, appModel: appModel)
        errorMessage = nil
        publishChange()
    }

    func deleteSelectedProfile() {
        guard !draft.profile.isDefault else { return }
        let deletedID = selectedProfileID
        appModel.deleteProfile(deletedID)
        drafts[deletedID] = nil
        selectedProfileID = appModel.activeProfileID
        if drafts[selectedProfileID] == nil {
            drafts[selectedProfileID] = Self.makeDraft(
                profileID: selectedProfileID,
                appModel: appModel
            )
        }
        errorMessage = nil
        publishChange()
    }

    func updateProfileName(_ name: String) {
        guard !draft.profile.isDefault else { return }
        mutateDraft { $0.profile.name = name }
    }

    func addWindow(candidate: WindowCandidate) {
        let registration = RegisteredWindow(
            target: candidate.handle.descriptor
        )
        let entry = ProfileWindowEntry(
            registeredWindowID: registration.id
        )

        mutateDraft { draft in
            draft.registrations[registration.id] = registration
            draft.profile.entries.append(entry)
        }
    }

    func removeEntry(_ id: UUID) {
        mutateDraft { draft in
            guard let entry = draft.profile.entries.first(where: { $0.id == id }) else {
                return
            }
            draft.profile.entries.removeAll { $0.id == id }
            if !draft.profile.entries.contains(where: {
                $0.registeredWindowID == entry.registeredWindowID
            }) {
                draft.registrations[entry.registeredWindowID] = nil
            }
        }
    }

    func updateNameOverride(entryID: UUID, value: String) {
        mutateDraft { draft in
            guard let entry = draft.profile.entries.first(where: { $0.id == entryID }),
                  var registration = draft.registrations[entry.registeredWindowID] else {
                return
            }
            let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            registration.nameOverride = cleanValue.isEmpty ? nil : value
            draft.registrations[registration.id] = registration
        }
    }

    func setOverlayEnabled(entryID: UUID, enabled: Bool) {
        mutateEntry(entryID) { entry, registration in
            if enabled, entry.access.overlay == nil {
                let text = registration.displayName
                entry.access.overlay = OverlayConfiguration(
                    text: text,
                    frame: appModel.suggestedOverlayFrame(text: text)
                )
            } else if !enabled {
                entry.access.overlay = nil
            }
        }
    }

    func updateOverlayText(entryID: UUID, text: String) {
        mutateEntry(entryID) { entry, _ in
            entry.access.overlay?.text = text
        }
    }

    func setHotKey(entryID: UUID, hotKey: HotKeyShortcut?) {
        mutateEntry(entryID) { entry, _ in
            entry.access.hotKey = hotKey
        }
    }

    func save() {
        let registrations = Array(draft.registrations.values)
        if let error = appModel.saveProfile(
            draft.profile,
            registrations: registrations
        ) {
            errorMessage = error
            return
        }

        var updated = draft
        updated.savedProfile = updated.profile
        updated.savedRegistrations = updated.registrations
        drafts[selectedProfileID] = updated
        errorMessage = nil
        publishChange()
    }

    func revert() {
        drafts[selectedProfileID] = Self.makeDraft(
            profileID: selectedProfileID,
            appModel: appModel
        )
        errorMessage = nil
        publishChange()
    }

    private var draft: ProfileDraft {
        get {
            drafts[selectedProfileID]
                ?? Self.makeDraft(profileID: selectedProfileID, appModel: appModel)
        }
        set {
            drafts[selectedProfileID] = newValue
        }
    }

    private func mutateDraft(_ mutation: (inout ProfileDraft) -> Void) {
        var updated = draft
        mutation(&updated)
        draft = updated
        errorMessage = nil
        publishChange()
    }

    private func mutateEntry(
        _ entryID: UUID,
        mutation: (
            inout ProfileWindowEntry,
            RegisteredWindow
        ) -> Void
    ) {
        mutateDraft { draft in
            guard let index = draft.profile.entries.firstIndex(where: {
                $0.id == entryID
            }), let registration = draft.registrations[
                draft.profile.entries[index].registeredWindowID
            ] else {
                return
            }
            mutation(&draft.profile.entries[index], registration)
        }
    }

    private func publishChange() {
        revision &+= 1
    }

    private func refreshCleanDraftFromSavedConfiguration() {
        guard let current = drafts[selectedProfileID], !current.isDirty else {
            return
        }
        drafts[selectedProfileID] = Self.makeDraft(
            profileID: selectedProfileID,
            appModel: appModel
        )
    }

    private static func makeDraft(
        profileID: UUID,
        appModel: AppModel
    ) -> ProfileDraft {
        let profile = appModel.profiles.first(where: { $0.id == profileID })
            ?? appModel.activeProfile
        let registrationIDs = Set(profile.entries.map(\.registeredWindowID))
        let registrations = Dictionary(
            uniqueKeysWithValues: appModel.configuration.registeredWindows
                .filter { registrationIDs.contains($0.id) }
                .map { ($0.id, $0) }
        )
        return ProfileDraft(
            profile: profile,
            registrations: registrations,
            savedProfile: profile,
            savedRegistrations: registrations
        )
    }
}
