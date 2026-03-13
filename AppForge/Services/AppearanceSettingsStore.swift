import Foundation

/// Persists the shell color palette across launches.
struct AppearanceSettingsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let selectedColorPalette = "AppForge.selectedColorPalette"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadColorPalette() -> AppColorPalette {
        guard let rawValue = defaults.string(forKey: Key.selectedColorPalette),
              let palette = AppColorPalette(rawValue: rawValue) else {
            return .harbor
        }

        return palette
    }

    func saveColorPalette(_ palette: AppColorPalette) {
        defaults.set(palette.rawValue, forKey: Key.selectedColorPalette)
    }
}
