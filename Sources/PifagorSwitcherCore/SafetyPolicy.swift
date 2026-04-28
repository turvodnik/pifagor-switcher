import Foundation

public struct TypingContext: Equatable, Sendable {
    public let applicationBundleIdentifier: String?
    public let applicationName: String?
    public let isSecureInputEnabled: Bool
    public let focusedElementRole: String?

    public init(
        applicationBundleIdentifier: String?,
        applicationName: String?,
        isSecureInputEnabled: Bool,
        focusedElementRole: String?
    ) {
        self.applicationBundleIdentifier = applicationBundleIdentifier
        self.applicationName = applicationName
        self.isSecureInputEnabled = isSecureInputEnabled
        self.focusedElementRole = focusedElementRole
    }
}

public struct SafetyPolicy: Sendable {
    private let blockedBundleIdentifiers: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.apple.Spotlight"
    ]

    private let blockedElementRoles: Set<String> = [
        "AXSecureTextField"
    ]

    public init() {}

    public func allowsCorrection(in context: TypingContext, settings: SettingsStore.State) -> Bool {
        guard settings.isEnabled else {
            return false
        }

        if context.isSecureInputEnabled {
            return false
        }

        if let role = context.focusedElementRole, blockedElementRoles.contains(role) {
            return false
        }

        if let bundleIdentifier = context.applicationBundleIdentifier {
            if blockedBundleIdentifiers.contains(bundleIdentifier) {
                return false
            }

            if settings.excludedAppBundleIdentifiers.contains(bundleIdentifier) {
                return false
            }
        }

        return true
    }
}
