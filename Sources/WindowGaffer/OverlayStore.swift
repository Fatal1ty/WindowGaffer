import WindowGafferCore
import Foundation

final class OverlayStore {
    private let defaults: UserDefaults
    private let configurationKey = "window-gaffer-configuration-v1"
    private let overlaysVisibleKey = "window-gaffer-overlays-visible-v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadConfiguration() -> WindowGafferConfiguration {
        guard let data = defaults.data(forKey: configurationKey) else {
            return .empty()
        }

        do {
            let configuration = try JSONDecoder().decode(
                WindowGafferConfiguration.self,
                from: data
            )
            guard configuration.version == WindowGafferConfiguration.schemaVersion,
                  !configuration.profiles.isEmpty,
                  configuration.profiles.contains(where: {
                      $0.id == configuration.activeProfileID
                  }) else {
                return .empty()
            }
            return configuration
        } catch {
            NSLog("Window Gaffer: unable to decode configuration: \(error)")
            return .empty()
        }
    }

    func saveConfiguration(_ configuration: WindowGafferConfiguration) {
        do {
            let data = try JSONEncoder().encode(configuration)
            defaults.set(data, forKey: configurationKey)
        } catch {
            NSLog("Window Gaffer: unable to save configuration: \(error)")
        }
    }

    func loadOverlaysVisible() -> Bool {
        guard defaults.object(forKey: overlaysVisibleKey) != nil else {
            return true
        }
        return defaults.bool(forKey: overlaysVisibleKey)
    }

    func saveOverlaysVisible(_ visible: Bool) {
        defaults.set(visible, forKey: overlaysVisibleKey)
    }
}
