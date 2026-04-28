import Foundation

public struct LiveCorrectionPolicy: Sendable {
    public let idleDelay: TimeInterval
    public let liveConfidenceThreshold: Double

    public init(idleDelay: TimeInterval = 0.16, liveConfidenceThreshold: Double = 0.92) {
        self.idleDelay = idleDelay
        self.liveConfidenceThreshold = liveConfidenceThreshold
    }

    public func allowsLiveCorrection(
        word: String,
        settings: SettingsStore.State,
        correctionMode: AppCorrectionMode,
        context: TypingContext
    ) -> Bool {
        guard settings.isLiveCorrectionEnabled,
              settings.isEnabled,
              correctionMode == .normal,
              word.count >= 3 else {
            return false
        }

        return SafetyPolicy().allowsCorrection(in: context, settings: settings)
    }

    public func cancelsPendingLiveCorrection(on event: TypingEvent) -> Bool {
        switch event {
        case .character:
            return false
        case .wordBoundary, .backspace, .enter, .escape, .appChanged, .cursorMoved:
            return true
        }
    }
}
