import Foundation

public struct AppRuleEngine: Sendable {
    private let settings: SettingsStore.State

    public init(settings: SettingsStore.State) {
        self.settings = settings
    }

    public func preferredInputSource(for bundleIdentifier: String?) -> InputSource? {
        guard let bundleIdentifier else {
            return nil
        }

        return settings.appRules[bundleIdentifier]
    }

    public func correctionMode(for bundleIdentifier: String?) -> AppCorrectionMode {
        guard let bundleIdentifier else {
            return .normal
        }

        return settings.appCorrectionModes[bundleIdentifier] ?? .normal
    }
}
