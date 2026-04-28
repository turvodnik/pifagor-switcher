import Foundation

public final class SettingsStore: @unchecked Sendable {
    public struct State: Codable, Equatable, Sendable {
        public let enabledInputSources: [InputSource]
        public let appRules: [String: InputSource]
        public let urlRules: [String: InputSource]
        public let appCorrectionModes: [String: AppCorrectionMode]
        public let excludedAppBundleIdentifiers: Set<String>
        public let isEnabled: Bool
        public let isVisualIndicatorEnabled: Bool
        public let isSoundEnabled: Bool
        public let launchAtLogin: Bool
        public let isLiveCorrectionEnabled: Bool
        public let isAdaptiveLearningEnabled: Bool
        public let onboardingCompleted: Bool

        public init(
            enabledInputSources: [InputSource],
            appRules: [String: InputSource],
            urlRules: [String: InputSource] = Self.defaultURLRules,
            appCorrectionModes: [String: AppCorrectionMode] = Self.defaultAppCorrectionModes,
            excludedAppBundleIdentifiers: Set<String>,
            isEnabled: Bool,
            isVisualIndicatorEnabled: Bool,
            isSoundEnabled: Bool,
            launchAtLogin: Bool,
            isLiveCorrectionEnabled: Bool = true,
            isAdaptiveLearningEnabled: Bool = true,
            onboardingCompleted: Bool = false
        ) {
            self.enabledInputSources = enabledInputSources
            self.appRules = appRules
            self.urlRules = urlRules
            self.appCorrectionModes = appCorrectionModes
            self.excludedAppBundleIdentifiers = excludedAppBundleIdentifiers
            self.isEnabled = isEnabled
            self.isVisualIndicatorEnabled = isVisualIndicatorEnabled
            self.isSoundEnabled = isSoundEnabled
            self.launchAtLogin = launchAtLogin
            self.isLiveCorrectionEnabled = isLiveCorrectionEnabled
            self.isAdaptiveLearningEnabled = isAdaptiveLearningEnabled
            self.onboardingCompleted = onboardingCompleted
        }

        private enum CodingKeys: String, CodingKey {
            case enabledInputSources
            case appRules
            case urlRules
            case appCorrectionModes
            case excludedAppBundleIdentifiers
            case isEnabled
            case isVisualIndicatorEnabled
            case isSoundEnabled
            case launchAtLogin
            case isLiveCorrectionEnabled
            case isAdaptiveLearningEnabled
            case onboardingCompleted
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.enabledInputSources = try container.decodeIfPresent([InputSource].self, forKey: .enabledInputSources) ?? Self.defaults.enabledInputSources
            self.appRules = try container.decodeIfPresent([String: InputSource].self, forKey: .appRules) ?? Self.defaults.appRules
            self.urlRules = try container.decodeIfPresent([String: InputSource].self, forKey: .urlRules) ?? Self.defaultURLRules
            self.appCorrectionModes = try container.decodeIfPresent([String: AppCorrectionMode].self, forKey: .appCorrectionModes) ?? Self.defaultAppCorrectionModes
            self.excludedAppBundleIdentifiers = try container.decodeIfPresent(Set<String>.self, forKey: .excludedAppBundleIdentifiers) ?? Self.defaults.excludedAppBundleIdentifiers
            self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? Self.defaults.isEnabled
            self.isVisualIndicatorEnabled = try container.decodeIfPresent(Bool.self, forKey: .isVisualIndicatorEnabled) ?? Self.defaults.isVisualIndicatorEnabled
            self.isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? Self.defaults.isSoundEnabled
            self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? Self.defaults.launchAtLogin
            self.isLiveCorrectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLiveCorrectionEnabled) ?? Self.defaults.isLiveCorrectionEnabled
            self.isAdaptiveLearningEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAdaptiveLearningEnabled) ?? Self.defaults.isAdaptiveLearningEnabled
            self.onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? Self.defaults.onboardingCompleted
        }

        public static let defaultURLRules: [String: InputSource] = [
            "github.com": .english,
            "wp-admin": .english,
            "wordpress.com": .english,
            "ads.google.com": .english,
            "business.facebook.com": .english,
            "facebook.com/ads": .english,
            "claude.ai": .english,
            "chatgpt.com": .english,
            "platform.openai.com": .english,
            "docs.google.com": .russian,
            "mail.google.com": .russian
        ]

        public static let defaultAppCorrectionModes: [String: AppCorrectionMode] = [
            "com.microsoft.VSCode": .manualOnly,
            "com.todesktop.230313mzl4w4u92": .manualOnly,
            "com.apple.Terminal": .disabled,
            "com.googlecode.iterm2": .disabled
        ]

        public static let defaults = State(
            enabledInputSources: [.english, .russian],
            appRules: [:],
            urlRules: defaultURLRules,
            appCorrectionModes: defaultAppCorrectionModes,
            excludedAppBundleIdentifiers: [
                "com.apple.Terminal",
                "com.googlecode.iterm2",
                "com.apple.Spotlight"
            ],
            isEnabled: true,
            isVisualIndicatorEnabled: true,
            isSoundEnabled: false,
            launchAtLogin: false,
            isLiveCorrectionEnabled: true,
            isAdaptiveLearningEnabled: true,
            onboardingCompleted: false
        )

        public func withAppRule(bundleIdentifier: String, inputSource: InputSource) -> State {
            var rules = appRules
            rules[bundleIdentifier] = inputSource
            return State(
                enabledInputSources: enabledInputSources,
                appRules: rules,
                urlRules: urlRules,
                appCorrectionModes: appCorrectionModes,
                excludedAppBundleIdentifiers: excludedAppBundleIdentifiers,
                isEnabled: isEnabled,
                isVisualIndicatorEnabled: isVisualIndicatorEnabled,
                isSoundEnabled: isSoundEnabled,
                launchAtLogin: launchAtLogin,
                isLiveCorrectionEnabled: isLiveCorrectionEnabled,
                isAdaptiveLearningEnabled: isAdaptiveLearningEnabled,
                onboardingCompleted: onboardingCompleted
            )
        }

        public func withURLRule(pattern: String, inputSource: InputSource) -> State {
            var rules = urlRules
            rules[pattern] = inputSource
            return State(
                enabledInputSources: enabledInputSources,
                appRules: appRules,
                urlRules: rules,
                appCorrectionModes: appCorrectionModes,
                excludedAppBundleIdentifiers: excludedAppBundleIdentifiers,
                isEnabled: isEnabled,
                isVisualIndicatorEnabled: isVisualIndicatorEnabled,
                isSoundEnabled: isSoundEnabled,
                launchAtLogin: launchAtLogin,
                isLiveCorrectionEnabled: isLiveCorrectionEnabled,
                isAdaptiveLearningEnabled: isAdaptiveLearningEnabled,
                onboardingCompleted: onboardingCompleted
            )
        }

        public func withAppCorrectionMode(bundleIdentifier: String, mode: AppCorrectionMode) -> State {
            var modes = appCorrectionModes
            modes[bundleIdentifier] = mode
            return State(
                enabledInputSources: enabledInputSources,
                appRules: appRules,
                urlRules: urlRules,
                appCorrectionModes: modes,
                excludedAppBundleIdentifiers: excludedAppBundleIdentifiers,
                isEnabled: isEnabled,
                isVisualIndicatorEnabled: isVisualIndicatorEnabled,
                isSoundEnabled: isSoundEnabled,
                launchAtLogin: launchAtLogin,
                isLiveCorrectionEnabled: isLiveCorrectionEnabled,
                isAdaptiveLearningEnabled: isAdaptiveLearningEnabled,
                onboardingCompleted: onboardingCompleted
            )
        }

        public func withExcludedApp(_ bundleIdentifier: String) -> State {
            var excluded = excludedAppBundleIdentifiers
            excluded.insert(bundleIdentifier)
            return State(
                enabledInputSources: enabledInputSources,
                appRules: appRules,
                urlRules: urlRules,
                appCorrectionModes: appCorrectionModes,
                excludedAppBundleIdentifiers: excluded,
                isEnabled: isEnabled,
                isVisualIndicatorEnabled: isVisualIndicatorEnabled,
                isSoundEnabled: isSoundEnabled,
                launchAtLogin: launchAtLogin,
                isLiveCorrectionEnabled: isLiveCorrectionEnabled,
                isAdaptiveLearningEnabled: isAdaptiveLearningEnabled,
                onboardingCompleted: onboardingCompleted
            )
        }

        public func withEnabled(_ enabled: Bool) -> State {
            State(
                enabledInputSources: enabledInputSources,
                appRules: appRules,
                urlRules: urlRules,
                appCorrectionModes: appCorrectionModes,
                excludedAppBundleIdentifiers: excludedAppBundleIdentifiers,
                isEnabled: enabled,
                isVisualIndicatorEnabled: isVisualIndicatorEnabled,
                isSoundEnabled: isSoundEnabled,
                launchAtLogin: launchAtLogin,
                isLiveCorrectionEnabled: isLiveCorrectionEnabled,
                isAdaptiveLearningEnabled: isAdaptiveLearningEnabled,
                onboardingCompleted: onboardingCompleted
            )
        }

        public func withAdaptiveLearningEnabled(_ enabled: Bool) -> State {
            State(
                enabledInputSources: enabledInputSources,
                appRules: appRules,
                urlRules: urlRules,
                appCorrectionModes: appCorrectionModes,
                excludedAppBundleIdentifiers: excludedAppBundleIdentifiers,
                isEnabled: isEnabled,
                isVisualIndicatorEnabled: isVisualIndicatorEnabled,
                isSoundEnabled: isSoundEnabled,
                launchAtLogin: launchAtLogin,
                isLiveCorrectionEnabled: isLiveCorrectionEnabled,
                isAdaptiveLearningEnabled: enabled,
                onboardingCompleted: onboardingCompleted
            )
        }

        public func withLiveCorrectionEnabled(_ enabled: Bool) -> State {
            State(
                enabledInputSources: enabledInputSources,
                appRules: appRules,
                urlRules: urlRules,
                appCorrectionModes: appCorrectionModes,
                excludedAppBundleIdentifiers: excludedAppBundleIdentifiers,
                isEnabled: isEnabled,
                isVisualIndicatorEnabled: isVisualIndicatorEnabled,
                isSoundEnabled: isSoundEnabled,
                launchAtLogin: launchAtLogin,
                isLiveCorrectionEnabled: enabled,
                isAdaptiveLearningEnabled: isAdaptiveLearningEnabled,
                onboardingCompleted: onboardingCompleted
            )
        }

        public func withOnboardingCompleted(_ completed: Bool) -> State {
            State(
                enabledInputSources: enabledInputSources,
                appRules: appRules,
                urlRules: urlRules,
                appCorrectionModes: appCorrectionModes,
                excludedAppBundleIdentifiers: excludedAppBundleIdentifiers,
                isEnabled: isEnabled,
                isVisualIndicatorEnabled: isVisualIndicatorEnabled,
                isSoundEnabled: isSoundEnabled,
                launchAtLogin: launchAtLogin,
                isLiveCorrectionEnabled: isLiveCorrectionEnabled,
                isAdaptiveLearningEnabled: isAdaptiveLearningEnabled,
                onboardingCompleted: completed
            )
        }
    }

    private let fileURL: URL
    private let queue = DispatchQueue(label: "app.pifagor.switcher.settings")
    private var stateStorage: State

    public var state: State {
        queue.sync { stateStorage }
    }

    public init(fileURL: URL? = nil) {
        let defaultURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("PifagorSwitcher", isDirectory: true)
            .appendingPathComponent("settings.json")

        self.fileURL = fileURL ?? defaultURL ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pifagor-settings.json")
        self.stateStorage = Self.load(from: self.fileURL)
    }

    public func update(_ transform: (State) -> State) throws {
        try queue.sync {
            let newState = transform(stateStorage)
            try persist(newState)
            stateStorage = newState
        }
    }

    private static func load(from url: URL) -> State {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(State.self, from: data) else {
            return .defaults
        }

        return decoded
    }

    private func persist(_ state: State) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }
}
