import AppKit
import Carbon
import PifagorSwitcherCore

@MainActor
final class TypingController {
    enum Event {
        case character(Character)
        case wordBoundary(String)
        case backspace
        case enter
        case escape
        case appChanged
        case cursorMoved
        case manualSwitch
        case doubleControl
        case manualCorrectSelection
        case manualCorrectCurrentWord
        case toggleEnabled
        case undoLastCorrection
    }

    private let settingsStore: SettingsStore
    private let adaptiveLexiconStore: AdaptiveLexiconStore
    private let inputSourceManager: InputSourceManager
    private let correctionEngine = CorrectionEngine()
    private let capitalizationCorrector = CapitalizationCorrector()
    private let liveCorrectionPolicy = LiveCorrectionPolicy()
    private let safetyPolicy = SafetyPolicy()
    private let indicator: InputSourceIndicator
    private let textReplayer: TextReplayer
    private let selectedTextReader = SelectedTextReader()
    private let browserURLProvider = BrowserURLProvider()

    private var buffer = TypingBuffer()
    private var lastCorrection: TextCorrection?
    private var recentRejectedCorrection: TextCorrection?
    private var liveCorrectionWorkItem: DispatchWorkItem?
    private var liveCorrectionGeneration: Int = 0
    private(set) var lastCorrectionSkipReason: String = "-"

    init(
        settingsStore: SettingsStore,
        adaptiveLexiconStore: AdaptiveLexiconStore,
        inputSourceManager: InputSourceManager,
        indicator: InputSourceIndicator,
        textReplayer: TextReplayer
    ) {
        self.settingsStore = settingsStore
        self.adaptiveLexiconStore = adaptiveLexiconStore
        self.inputSourceManager = inputSourceManager
        self.indicator = indicator
        self.textReplayer = textReplayer

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostApplicationChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func handle(_ event: Event) {
        switch event {
        case .character(let character):
            cancelPendingLiveCorrection()
            lastCorrection = nil
            _ = buffer.record(.character(character))
            scheduleLiveCorrectionIfNeeded()
        case .wordBoundary(let typedSuffix):
            cancelPendingLiveCorrection(reason: "live cancelled by word boundary")
            applyContextRuleIfNeeded()
            if let word = buffer.record(.wordBoundary) {
                if let correction = attemptCorrection(word: word, trigger: .wordBoundary, typedSuffix: typedSuffix) {
                    buffer.replaceTrailingText(characterCount: word.count, with: correction.insertedText)
                } else if let correction = attemptCapitalizationCorrection(word: word, typedSuffix: typedSuffix) {
                    textReplayer.replaceText(characterCount: correction.deleteLength, replacement: correction.insertedText)
                    buffer.replaceTrailingText(characterCount: word.count, with: correction.insertedText)
                    lastCorrection = correction
                } else {
                    confirmRetypedRejectedWordIfNeeded(word)
                    learnAcceptedWordIfAllowed(word)
                    buffer.appendBoundary(typedSuffix)
                }
            } else {
                buffer.appendBoundary(typedSuffix)
            }
        case .backspace:
            cancelPendingLiveCorrection(reason: "live cancelled by Backspace")
            rejectLastCorrectionIfBackspacingAtCursor()
            lastCorrection = nil
            _ = buffer.record(.backspace)
        case .enter:
            cancelPendingLiveCorrection(reason: "live cancelled by Enter")
            lastCorrection = nil
            _ = buffer.record(.enter)
        case .escape:
            cancelPendingLiveCorrection(reason: "live cancelled by Escape")
            lastCorrection = nil
            _ = buffer.record(.escape)
        case .appChanged:
            cancelPendingLiveCorrection(reason: "live cancelled by app change")
            lastCorrection = nil
            _ = buffer.record(.appChanged)
            applyContextRuleIfNeeded()
        case .cursorMoved:
            cancelPendingLiveCorrection(reason: "live cancelled by cursor movement")
            lastCorrection = nil
            _ = buffer.record(.cursorMoved)
            applyContextRuleIfNeeded()
        case .manualSwitch:
            cancelPendingLiveCorrection(reason: "live cancelled by manual switch")
            manualSwitch()
        case .doubleControl:
            cancelPendingLiveCorrection(reason: "live cancelled by manual correction")
            manualCorrectPreviousTextOrSwitch()
        case .manualCorrectSelection:
            cancelPendingLiveCorrection(reason: "live cancelled by selected text correction")
            if !manualCorrectSelectedText() {
                manualCorrectPreviousTextOrSwitch()
            }
        case .manualCorrectCurrentWord:
            cancelPendingLiveCorrection(reason: "live cancelled by manual word correction")
            manualCorrectCurrentWord()
        case .toggleEnabled:
            cancelPendingLiveCorrection(reason: "live cancelled by pause toggle")
            toggleEnabled()
        case .undoLastCorrection:
            cancelPendingLiveCorrection(reason: "live cancelled by undo")
            undoLastCorrection()
        }
    }

    func undoLastCorrection() {
        guard let correction = lastCorrection else {
            return
        }

        recordRejectedCorrectionIfAllowed(correction)
        textReplayer.replaceText(characterCount: correction.undoDeleteLength, replacement: correction.undoInsertedText)
        buffer.replaceTrailingText(characterCount: correction.insertedText.count, with: correction.undoInsertedText)
        indicator.show(text: "Отменено")
        lastCorrection = nil
    }

    @objc private func frontmostApplicationChanged() {
        handle(.appChanged)
    }

    @discardableResult
    private func attemptCorrection(word: String, trigger: CorrectionTrigger, typedSuffix: String) -> TextCorrection? {
        guard correctionEngine.shouldAttemptCorrection(trigger: trigger) else {
            lastCorrectionSkipReason = "\(trigger) correction disabled for trigger"
            return nil
        }

        let settings = settingsStore.state
        let context = currentTypingContext()
        guard settings.isEnabled else {
            lastCorrectionSkipReason = "switcher disabled"
            return nil
        }
        guard safetyPolicy.allowsCorrection(in: context, settings: settings) else {
            lastCorrectionSkipReason = "blocked by safety policy"
            return nil
        }
        guard allowsCorrectionMode(trigger: trigger, settings: settings) else {
            lastCorrectionSkipReason = "blocked by app correction mode"
            return nil
        }
        guard let currentInputSource = inputSourceManager.currentInputSource() else {
            lastCorrectionSkipReason = "unknown input source"
            return nil
        }

        let detector = LanguageDetector(adaptiveLexicon: adaptiveSnapshot(for: settings))
        let result = detector.detect(word: word, currentInputSource: currentInputSource, trigger: trigger)
        guard result.shouldCorrect, let targetInputSource = result.targetInputSource,
              let correction = correctionEngine.correction(
                for: word,
                currentInputSource: currentInputSource,
                targetInputSource: targetInputSource,
                typedSuffix: typedSuffix
            ) else {
            lastCorrectionSkipReason = "\(trigger) confidence too low or protected token"
            return nil
        }

        _ = inputSourceManager.select(targetInputSource)
        textReplayer.replaceText(characterCount: correction.deleteLength, replacement: correction.insertedText)
        lastCorrection = correction
        lastCorrectionSkipReason = "corrected \(trigger)"
        if trigger == .manual, settings.isAdaptiveLearningEnabled {
            adaptiveLexiconStore.recordManualCorrection(
                original: correction.original,
                replacement: correction.replacement,
                currentInputSource: currentInputSource
            )
        }

        if settings.isVisualIndicatorEnabled {
            indicator.show(text: targetInputSource.displayName)
        }
        if settings.isSoundEnabled {
            NSSound.beep()
        }

        return correction
    }

    private func scheduleLiveCorrectionIfNeeded() {
        let word = buffer.currentWord
        let settings = settingsStore.state
        let context = currentTypingContext()
        let mode = currentCorrectionMode(settings: settings)

        guard liveCorrectionPolicy.allowsLiveCorrection(
            word: word,
            settings: settings,
            correctionMode: mode,
            context: context
        ) else {
            lastCorrectionSkipReason = liveCorrectionSkipReason(
                word: word,
                settings: settings,
                correctionMode: mode,
                context: context
            )
            return
        }

        liveCorrectionGeneration += 1
        let generation = liveCorrectionGeneration
        let workItem = DispatchWorkItem { [weak self] in
            self?.performLiveCorrection(expectedWord: word, generation: generation)
        }
        liveCorrectionWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + liveCorrectionPolicy.idleDelay,
            execute: workItem
        )
    }

    private func performLiveCorrection(expectedWord: String, generation: Int) {
        guard generation == liveCorrectionGeneration else {
            return
        }

        liveCorrectionWorkItem = nil
        guard buffer.currentWord == expectedWord else {
            lastCorrectionSkipReason = "live skipped stale word"
            return
        }

        guard let correction = attemptCorrection(word: expectedWord, trigger: .live, typedSuffix: "") else {
            return
        }

        buffer.replaceCurrentWord(with: correction.replacement)
    }

    private func cancelPendingLiveCorrection(reason: String? = nil) {
        guard liveCorrectionWorkItem != nil else {
            return
        }

        liveCorrectionWorkItem?.cancel()
        liveCorrectionWorkItem = nil
        liveCorrectionGeneration += 1
        if let reason {
            lastCorrectionSkipReason = reason
        }
    }

    private func liveCorrectionSkipReason(
        word: String,
        settings: SettingsStore.State,
        correctionMode: AppCorrectionMode,
        context: TypingContext
    ) -> String {
        if !settings.isEnabled {
            return "live skipped: switcher disabled"
        }
        if !settings.isLiveCorrectionEnabled {
            return "live skipped: disabled in settings"
        }
        if correctionMode != .normal {
            return "live skipped: app mode \(correctionMode.rawValue)"
        }
        if word.count < 3 {
            return "live skipped: word shorter than 3"
        }
        if !safetyPolicy.allowsCorrection(in: context, settings: settings) {
            return "live skipped: blocked by safety policy"
        }

        return "live skipped"
    }

    private func applyContextRuleIfNeeded() {
        let settings = settingsStore.state
        let engine = AppRuleEngine(settings: settings)
        let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        if let urlSource = URLRuleEngine(rules: settings.urlRules)
            .preferredInputSource(for: browserURLProvider.currentURL(for: NSWorkspace.shared.frontmostApplication)) {
            if inputSourceManager.select(urlSource), settings.isVisualIndicatorEnabled {
                indicator.show(text: urlSource.displayName)
            }
            return
        }

        guard let source = engine.preferredInputSource(for: bundleIdentifier) else {
            return
        }

        if inputSourceManager.select(source), settings.isVisualIndicatorEnabled {
            indicator.show(text: source.displayName)
        }
    }

    private func manualSwitch() {
        guard let current = inputSourceManager.currentInputSource() else {
            return
        }

        let target: InputSource = current == .english ? .russian : .english
        if inputSourceManager.select(target), settingsStore.state.isVisualIndicatorEnabled {
            indicator.show(text: target.displayName)
        }
    }

    private func manualCorrectPreviousTextOrSwitch() {
        if manualCorrectSelectedText() {
            return
        }

        if canUndoLastCorrectionAtCursor() {
            undoLastCorrection()
            return
        }

        let phrase = buffer.currentPhrase
        guard !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            manualSwitch()
            return
        }

        let settings = settingsStore.state
        let context = currentTypingContext()
        guard settings.isEnabled,
              safetyPolicy.allowsCorrection(in: context, settings: settings),
              allowsCorrectionMode(trigger: .manual, settings: settings),
              let currentInputSource = inputSourceManager.currentInputSource(),
              let correction = PhraseCorrector(
                detector: LanguageDetector(adaptiveLexicon: adaptiveSnapshot(for: settings))
              ).correction(for: phrase, currentInputSource: currentInputSource) else {
            manualSwitch()
            return
        }

        _ = inputSourceManager.select(correction.targetInputSource)
        textReplayer.replaceText(characterCount: correction.deleteLength, replacement: correction.insertedText)
        buffer.replaceCurrentPhrase(with: correction.replacement)
        lastCorrection = correction

        if settings.isVisualIndicatorEnabled {
            indicator.show(text: correction.targetInputSource.displayName)
        }
        if settings.isSoundEnabled {
            NSSound.beep()
        }
    }

    private func canUndoLastCorrectionAtCursor() -> Bool {
        guard let correction = lastCorrection else {
            return false
        }

        return buffer.currentPhrase.hasSuffix(correction.insertedText)
    }

    private func manualCorrectCurrentWord() {
        let word = buffer.currentWord
        guard !word.isEmpty else {
            return
        }

        if let correction = attemptCorrection(word: word, trigger: .manual, typedSuffix: "") {
            buffer.replaceCurrentWord(with: correction.replacement)
            return
        }

        forceManualCorrectionCurrentWord(word)
    }

    private func forceManualCorrectionCurrentWord(_ word: String) {
        let settings = settingsStore.state
        let context = currentTypingContext()
        guard settings.isEnabled,
              safetyPolicy.allowsCorrection(in: context, settings: settings),
              allowsCorrectionMode(trigger: .manual, settings: settings),
              let currentInputSource = inputSourceManager.currentInputSource() else {
            return
        }

        let targetInputSource: InputSource = currentInputSource == .english ? .russian : .english
        guard let correction = correctionEngine.correction(
            for: word,
            currentInputSource: currentInputSource,
            targetInputSource: targetInputSource,
            typedSuffix: ""
        ) else {
            return
        }

        _ = inputSourceManager.select(targetInputSource)
        textReplayer.replaceText(characterCount: correction.deleteLength, replacement: correction.insertedText)
        buffer.replaceCurrentWord(with: correction.replacement)
        lastCorrection = correction
        if settings.isAdaptiveLearningEnabled {
            adaptiveLexiconStore.recordManualCorrection(
                original: correction.original,
                replacement: correction.replacement,
                currentInputSource: currentInputSource
            )
        }

        if settings.isVisualIndicatorEnabled {
            indicator.show(text: targetInputSource.displayName)
        }
    }

    private func manualCorrectSelectedText() -> Bool {
        let settings = settingsStore.state
        let context = currentTypingContext()
        guard settings.isEnabled,
              safetyPolicy.allowsCorrection(in: context, settings: settings),
              allowsCorrectionMode(trigger: .manual, settings: settings),
              let currentInputSource = inputSourceManager.currentInputSource(),
              let selectedText = selectedTextReader.selectedText(in: NSWorkspace.shared.frontmostApplication),
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let detector = LanguageDetector(adaptiveLexicon: adaptiveSnapshot(for: settings))
        let correction = PhraseCorrector(detector: detector)
            .correction(for: selectedText, currentInputSource: currentInputSource)
            ?? forcedSelectionCorrection(for: selectedText, currentInputSource: currentInputSource)

        guard let correction else {
            return false
        }

        _ = inputSourceManager.select(correction.targetInputSource)
        textReplayer.replaceSelection(with: correction.replacement)
        buffer.replaceCurrentPhrase(with: correction.replacement)
        lastCorrection = correction

        if settings.isAdaptiveLearningEnabled {
            adaptiveLexiconStore.recordManualCorrection(
                original: correction.original,
                replacement: correction.replacement,
                currentInputSource: currentInputSource
            )
        }
        if settings.isVisualIndicatorEnabled {
            indicator.show(text: correction.targetInputSource.displayName)
        }
        return true
    }

    private func forcedSelectionCorrection(for text: String, currentInputSource: InputSource) -> TextCorrection? {
        let targetInputSource: InputSource = currentInputSource == .english ? .russian : .english
        let replacement = KeyboardLayoutConverter.convert(text, from: currentInputSource, to: targetInputSource)
        guard replacement != text else {
            return nil
        }

        return TextCorrection(
            original: text,
            replacement: replacement,
            undoReplacement: text,
            targetInputSource: targetInputSource,
            typedSuffix: ""
        )
    }

    private func attemptCapitalizationCorrection(word: String, typedSuffix: String) -> TextCorrection? {
        let settings = settingsStore.state
        let context = currentTypingContext()
        guard settings.isEnabled,
              safetyPolicy.allowsCorrection(in: context, settings: settings),
              allowsCorrectionMode(trigger: .wordBoundary, settings: settings),
              let currentInputSource = inputSourceManager.currentInputSource() else {
            return nil
        }

        return capitalizationCorrector.correction(
            for: word,
            currentInputSource: currentInputSource,
            typedSuffix: typedSuffix
        )
    }

    private func toggleEnabled() {
        try? settingsStore.update { state in
            state.withEnabled(!state.isEnabled)
        }
        let title = settingsStore.state.isEnabled ? "Включено" : "Пауза"
        indicator.show(text: title)
    }

    private func currentTypingContext() -> TypingContext {
        let app = NSWorkspace.shared.frontmostApplication
        return TypingContext(
            applicationBundleIdentifier: app?.bundleIdentifier,
            applicationName: app?.localizedName,
            isSecureInputEnabled: IsSecureEventInputEnabled(),
            focusedElementRole: focusedElementRole(for: app)
        )
    }

    private func adaptiveSnapshot(for settings: SettingsStore.State) -> AdaptiveLexiconSnapshot {
        settings.isAdaptiveLearningEnabled ? adaptiveLexiconStore.snapshot : .empty
    }

    private func learnAcceptedWordIfAllowed(_ word: String) {
        let settings = settingsStore.state
        guard settings.isAdaptiveLearningEnabled,
              settings.isEnabled,
              safetyPolicy.allowsCorrection(in: currentTypingContext(), settings: settings),
              let currentInputSource = inputSourceManager.currentInputSource() else {
            return
        }

        adaptiveLexiconStore.recordAcceptedWord(word, inputSource: currentInputSource)
    }

    private func allowsCorrectionMode(trigger: CorrectionTrigger, settings: SettingsStore.State) -> Bool {
        let mode = currentCorrectionMode(settings: settings)

        switch mode {
        case .normal:
            return true
        case .manualOnly:
            return trigger == .manual
        case .disabled:
            return false
        }
    }

    private func currentCorrectionMode(settings: SettingsStore.State) -> AppCorrectionMode {
        AppRuleEngine(settings: settings)
            .correctionMode(for: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    private func rejectLastCorrectionIfBackspacingAtCursor() {
        guard let correction = lastCorrection,
              buffer.currentPhrase.hasSuffix(correction.insertedText) else {
            return
        }

        recordRejectedCorrectionIfAllowed(correction)
        recentRejectedCorrection = correction
    }

    private func recordRejectedCorrectionIfAllowed(_ correction: TextCorrection) {
        let settings = settingsStore.state
        guard settings.isAdaptiveLearningEnabled,
              safetyPolicy.allowsCorrection(in: currentTypingContext(), settings: settings) else {
            return
        }

        adaptiveLexiconStore.recordRejectedCorrection(
            original: correction.original,
            replacement: correction.replacement
        )
    }

    private func confirmRetypedRejectedWordIfNeeded(_ word: String) {
        guard let correction = recentRejectedCorrection,
              word.lowercased() == correction.original.lowercased(),
              let currentInputSource = inputSourceManager.currentInputSource() else {
            return
        }

        adaptiveLexiconStore.recordAcceptedWord(word, inputSource: currentInputSource)
        recentRejectedCorrection = nil
    }

    private func focusedElementRole(for app: NSRunningApplication?) -> String? {
        guard AXIsProcessTrusted(), let app else {
            return nil
        }

        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(applicationElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let focusedElement else {
            return nil
        }

        var role: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXRoleAttribute as CFString, &role) == .success else {
            return nil
        }

        return role as? String
    }
}
