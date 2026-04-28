import Foundation
import PifagorSwitcherCore

@main
struct PifagorSwitcherCoreSpec {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() {
                failures.append(message)
            }
        }

        expect(
            KeyboardLayoutConverter.convert("ghbdtn", from: .english, to: .russian) == "привет",
            "English physical keys convert to Russian text"
        )
        expect(
            KeyboardLayoutConverter.convert("руддщ", from: .russian, to: .english) == "hello",
            "Russian physical keys convert to English text"
        )
        expect(
            KeyboardLayoutConverter.convert("Ghbdtn, Vbh!", from: .english, to: .russian) == "Привет, Мир!",
            "Converter preserves punctuation and capitalization"
        )
        expect(
            KeyboardLayoutConverter.convert("gthtrk.xtybz", from: .english, to: .russian) == "переключения",
            "Converter treats punctuation keys inside words as Russian letters"
        )

        let detector = LanguageDetector()
        let russianIntent = detector.detect(word: "ghbdtn", currentInputSource: .english)
        expect(russianIntent.targetInputSource == .russian, "Detector targets Russian for ghbdtn")
        expect(russianIntent.confidence >= 0.80, "Detector confidence is high for ghbdtn")
        expect(russianIntent.shouldCorrect, "Detector corrects ghbdtn")

        let englishIntent = detector.detect(word: "руддщ", currentInputSource: .russian)
        expect(englishIntent.targetInputSource == .english, "Detector targets English for руддщ")
        expect(englishIntent.confidence >= 0.80, "Detector confidence is high for руддщ")
        expect(englishIntent.shouldCorrect, "Detector corrects руддщ")

        expect(!detector.detect(word: "gh", currentInputSource: .english).shouldCorrect, "Detector skips short ambiguous words")
        expect(!detector.detect(word: "user_id42", currentInputSource: .english).shouldCorrect, "Detector skips code-like words")
        expect(detector.detect(word: "еуые", currentInputSource: .russian).targetInputSource == .english, "Detector understands common English word test")
        expect(detector.detect(word: "z", currentInputSource: .english).targetInputSource == .russian, "Detector understands short Russian word я")
        expect(!detector.detect(word: "wordpress", currentInputSource: .russian).shouldCorrect, "Detector skips already-correct English words")
        expect(!detector.detect(word: "afdsu", currentInputSource: .english).shouldCorrect, "Detector skips unknown English-looking tokens instead of guessing by vowels")
        expect(detector.detect(word: "здгпшт", currentInputSource: .russian).targetInputSource == .english, "Detector understands WordPress term plugin")
        expect(detector.detect(word: "ыущ", currentInputSource: .russian).targetInputSource == .english, "Detector understands marketing term seo")
        expect(detector.detect(word: "сфьзфшпт", currentInputSource: .russian).targetInputSource == .english, "Detector understands advertising term campaign")

        let correctionEngine = CorrectionEngine()
        let correction = correctionEngine.correction(
            for: "ghbdtn",
            currentInputSource: .english,
            targetInputSource: .russian
        )
        expect(correction?.original == "ghbdtn", "Correction stores original word")
        expect(correction?.replacement == "привет", "Correction stores replacement word")
        expect(correction?.undoReplacement == "ghbdtn", "Correction stores undo payload")
        expect(correction?.targetInputSource == .russian, "Correction stores target source")
        expect(!correctionEngine.shouldAttemptCorrection(trigger: .enter), "Correction is blocked after Enter")

        let correctionWithSpace = correctionEngine.correction(
            for: "ghbdtn",
            currentInputSource: .english,
            targetInputSource: .russian,
            typedSuffix: " "
        )
        expect(correctionWithSpace?.deleteLength == 7, "Correction deletes word and already typed suffix")
        expect(correctionWithSpace?.insertedText == "привет ", "Correction restores typed suffix after replacement")
        expect(correctionWithSpace?.undoDeleteLength == 7, "Undo deletes replacement and suffix")
        expect(correctionWithSpace?.undoInsertedText == "ghbdtn ", "Undo restores original word and suffix")

        let policy = SafetyPolicy()
        expect(
            !policy.allowsCorrection(
                in: TypingContext(
                    applicationBundleIdentifier: "com.apple.Terminal",
                    applicationName: "Terminal",
                    isSecureInputEnabled: false,
                    focusedElementRole: nil
                ),
                settings: .defaults
            ),
            "Safety policy blocks Terminal"
        )
        expect(
            !policy.allowsCorrection(
                in: TypingContext(
                    applicationBundleIdentifier: "com.apple.Spotlight",
                    applicationName: "Spotlight",
                    isSecureInputEnabled: false,
                    focusedElementRole: nil
                ),
                settings: .defaults
            ),
            "Safety policy blocks Spotlight"
        )
        expect(
            !policy.allowsCorrection(
                in: TypingContext(
                    applicationBundleIdentifier: "com.apple.Notes",
                    applicationName: "Notes",
                    isSecureInputEnabled: true,
                    focusedElementRole: nil
                ),
                settings: .defaults
            ),
            "Safety policy blocks secure input"
        )
        expect(
            !policy.allowsCorrection(
                in: TypingContext(
                    applicationBundleIdentifier: "com.apple.Notes",
                    applicationName: "Notes",
                    isSecureInputEnabled: false,
                    focusedElementRole: nil
                ),
                settings: SettingsStore.State.defaults.withExcludedApp("com.apple.Notes")
            ),
            "Safety policy blocks excluded apps"
        )

        let settingsWithRule = SettingsStore.State.defaults.withAppRule(
            bundleIdentifier: "com.microsoft.VSCode",
            inputSource: .english
        )
        let ruleEngine = AppRuleEngine(settings: settingsWithRule)
        expect(ruleEngine.preferredInputSource(for: "com.microsoft.VSCode") == .english, "App rule returns configured source")
        expect(settingsWithRule.appRules["com.microsoft.VSCode"] == .english, "App rule update returns immutable copy")
        expect(AppRuleEngine(settings: .defaults).preferredInputSource(for: "com.apple.Notes") == nil, "Missing app rule returns nil")
        expect(
            AppRuleEngine(settings: .defaults).correctionMode(for: "com.microsoft.VSCode") == .manualOnly,
            "App rule engine returns manual-only mode for coding apps"
        )
        expect(
            AppRuleEngine(settings: .defaults).correctionMode(for: "com.openai.codex") == .normal,
            "Codex chat uses normal auto-correction mode by default"
        )

        let modeSettings = SettingsStore.State.defaults.withAppCorrectionMode(
            bundleIdentifier: "org.telegram.desktop",
            mode: .normal
        )
        expect(
            AppRuleEngine(settings: modeSettings).correctionMode(for: "org.telegram.desktop") == .normal,
            "App correction mode can be overridden"
        )

        let urlEngine = URLRuleEngine(rules: SettingsStore.State.defaultURLRules)
        expect(
            urlEngine.preferredInputSource(for: "https://example.com/wp-admin/post.php") == .english,
            "URL rules switch WordPress admin to English"
        )
        expect(
            urlEngine.preferredInputSource(for: "https://mail.google.com/mail/u/0/#inbox") == .russian,
            "URL rules switch Gmail to Russian by default"
        )

        var buffer = TypingBuffer()
        _ = buffer.record(.character("g"))
        _ = buffer.record(.character("h"))
        expect(buffer.record(.wordBoundary) == "gh", "Typing buffer returns completed word")
        buffer.appendBoundary(" ")
        _ = buffer.record(.character("v"))
        _ = buffer.record(.character("b"))
        _ = buffer.record(.character("h"))
        expect(buffer.currentPhrase == "gh vbh", "Typing buffer keeps phrase with spaces")
        buffer.replaceCurrentPhrase(with: "привет мир")
        expect(buffer.currentPhrase == "привет мир", "Typing buffer replaces full phrase")
        expect(buffer.currentWord == "мир", "Typing buffer derives current word after phrase replacement")
        _ = buffer.record(.character("x"))
        _ = buffer.record(.enter)
        expect(buffer.currentWord.isEmpty, "Typing buffer resets on Enter")
        expect(buffer.currentPhrase.isEmpty, "Typing buffer resets phrase on Enter")
        _ = buffer.record(.character("g"))
        buffer.appendBoundary(" ")
        _ = buffer.record(.character("v"))
        _ = buffer.record(.cursorMoved)
        expect(buffer.currentPhrase.isEmpty, "Typing buffer resets phrase after cursor movement")
        _ = buffer.record(.character("ц"))
        _ = buffer.record(.character("щ"))
        buffer.replaceCurrentWord(with: "wo")
        expect(buffer.currentWord == "wo", "Typing buffer can update word after manual correction")
        var backspaceBuffer = TypingBuffer()
        for character in "hello " {
            if character == " " {
                _ = backspaceBuffer.record(.wordBoundary)
                backspaceBuffer.appendBoundary(" ")
            } else {
                _ = backspaceBuffer.record(.character(character))
            }
        }
        _ = backspaceBuffer.record(.backspace)
        expect(backspaceBuffer.currentPhrase == "hello", "Typing buffer removes the last typed character on Backspace")
        expect(backspaceBuffer.currentWord == "hello", "Typing buffer restores the trailing word after deleting a boundary")

        let phraseCorrector = PhraseCorrector()
        let englishPhrase = phraseCorrector.correction(
            for: "руддщ цщкдв",
            currentInputSource: .russian
        )
        expect(englishPhrase?.replacement == "hello world", "Phrase corrector converts a full English sentence typed in Russian layout")
        expect(englishPhrase?.deleteLength == 11, "Phrase correction deletes the whole original sentence")
        expect(englishPhrase?.insertedText == "hello world", "Phrase correction inserts the full replacement sentence")

        let mixedPhrase = phraseCorrector.correction(
            for: "привет цщкдв",
            currentInputSource: .russian
        )
        expect(mixedPhrase?.replacement == "привет world", "Phrase corrector keeps already-correct words and fixes wrong-layout words")

        let requestedPhrase = phraseCorrector.correction(
            for: "nelf kjubre gthtrk.xtybz b bcghfdktybq b gjnjv vs tt ekexibv",
            currentInputSource: .english
        )
        expect(
            requestedPhrase?.replacement == "туда логику переключения и исправлений и потом мы ее улучшим",
            "Phrase corrector handles the user's long mixed switching sentence: \(requestedPhrase?.replacement ?? "nil")"
        )

        let requestedPhraseAfterAutoSwitch = phraseCorrector.correction(
            for: "nelf kjubre gthtrk.xtybz b bcghfdktybq b gjnjv vs tt ekexibv",
            currentInputSource: .russian
        )
        expect(
            requestedPhraseAfterAutoSwitch?.replacement == "туда логику переключения и исправлений и потом мы ее улучшим",
            "Phrase corrector handles a wrong English-layout phrase even if current source has already switched to Russian: \(requestedPhraseAfterAutoSwitch?.replacement ?? "nil")"
        )

        let mixedWithEnglishTerms = phraseCorrector.correction(
            for: "ghbdtn wordpress world claude code",
            currentInputSource: .english
        )
        expect(
            mixedWithEnglishTerms?.replacement == "привет wordpress world claude code",
            "Phrase corrector keeps already-correct English terms while fixing the wrong-layout word"
        )
        expect(
            mixedWithEnglishTerms?.targetInputSource == .russian,
            "Phrase correction target is based only on words that actually changed"
        )

        let mixedRussianWithEnglishTerm = phraseCorrector.correction(
            for: "итак афдыу но claude code",
            currentInputSource: .russian
        )
        expect(
            mixedRussianWithEnglishTerm?.replacement == "итак false но claude code",
            "Phrase corrector fixes wrong-layout technical words without touching normal English terms"
        )

        let englishDomainPhrase = phraseCorrector.correction(
            for: "цщквзкуыы здгпшт еруьу ыущ сфьзфшпт ьфклуештп",
            currentInputSource: .russian
        )
        expect(
            englishDomainPhrase?.replacement == "wordpress plugin theme seo campaign marketing",
            "Phrase corrector handles WordPress, web development and advertising English terms"
        )

        let russianDomainPhrase = "вордпресс реклама вебразработка нейросеть аналитика лендинг"
        let russianDomainTypedInEnglish = KeyboardLayoutConverter.convert(
            russianDomainPhrase,
            from: .russian,
            to: .english
        )
        let russianDomainCorrection = phraseCorrector.correction(
            for: russianDomainTypedInEnglish,
            currentInputSource: .english
        )
        expect(
            russianDomainCorrection?.replacement == russianDomainPhrase,
            "Phrase corrector handles Russian professional WordPress, ads and web development words"
        )

        let capsCorrector = CapitalizationCorrector()
        expect(
            capsCorrector.corrected("WOrd") == "Word",
            "Capitalization corrector fixes English double capitals"
        )
        expect(
            capsCorrector.corrected("ПРивет") == "Привет",
            "Capitalization corrector fixes Russian double capitals"
        )
        expect(
            capsCorrector.corrected("API") == nil,
            "Capitalization corrector keeps acronyms"
        )

        let adaptiveURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pifagor-adaptive-\(UUID().uuidString).json")
        let adaptiveStore = AdaptiveLexiconStore(fileURL: adaptiveURL)
        adaptiveStore.recordManualCorrection(
            original: "дкуврсут",
            replacement: "leadgen",
            currentInputSource: .russian
        )
        adaptiveStore.recordManualCorrection(
            original: "дкуврсут",
            replacement: "leadgen",
            currentInputSource: .russian
        )
        var adaptiveDetector = LanguageDetector(adaptiveLexicon: adaptiveStore.snapshot)
        expect(
            adaptiveDetector.detect(word: "дкуврсут", currentInputSource: .russian).targetInputSource == .english,
            "Adaptive lexicon learns confirmed manual layout corrections"
        )

        adaptiveStore.recordRejectedCorrection(original: "ghbdtn", replacement: "привет")
        adaptiveDetector = LanguageDetector(adaptiveLexicon: adaptiveStore.snapshot)
        expect(
            !adaptiveDetector.detect(word: "ghbdtn", currentInputSource: .english).shouldCorrect,
            "Adaptive lexicon suppresses corrections rejected by undo or immediate backspace"
        )

        adaptiveStore.recordAcceptedWord("leadgen", inputSource: .english)
        adaptiveStore.recordAcceptedWord("leadgen", inputSource: .english)
        adaptiveStore.recordAcceptedWord("leadgen", inputSource: .english)
        expect(
            adaptiveStore.snapshot.isKnown("leadgen", as: .english),
            "Adaptive lexicon promotes frequently accepted words"
        )

        adaptiveStore.setCustomDomainWords(["roas", "семантика"])
        expect(
            adaptiveStore.snapshot.isKnown("roas", as: .english),
            "Adaptive lexicon stores custom English domain words"
        )
        expect(
            adaptiveStore.snapshot.isKnown("семантика", as: .russian),
            "Adaptive lexicon stores custom Russian domain words"
        )

        let persistedAdaptiveStore = AdaptiveLexiconStore(fileURL: adaptiveURL)
        expect(
            persistedAdaptiveStore.snapshot.isIgnored("ghbdtn"),
            "Adaptive lexicon persists rejected words locally"
        )
        try? FileManager.default.removeItem(at: adaptiveURL)

        if failures.isEmpty {
            print("PifagorSwitcherCoreSpec: all checks passed")
            return
        }

        print("PifagorSwitcherCoreSpec: \(failures.count) failure(s)")
        for failure in failures {
            print("- \(failure)")
        }
        exit(1)
    }
}
