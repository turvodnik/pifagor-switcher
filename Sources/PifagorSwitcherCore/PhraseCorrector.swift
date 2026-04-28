import Foundation

public struct PhraseCorrector: Sendable {
    private let detector: LanguageDetector

    public init(detector: LanguageDetector = LanguageDetector()) {
        self.detector = detector
    }

    public func correction(
        for phrase: String,
        currentInputSource: InputSource
    ) -> TextCorrection? {
        guard !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var corrected = ""
        var currentWord = ""
        var didChange = false
        var targetCounts: [InputSource: Int] = [:]

        func flushWord() {
            guard !currentWord.isEmpty else {
                return
            }

            if let candidate = bestCandidate(for: currentWord, preferredCurrentInputSource: currentInputSource) {
                let replacement = candidate.replacement
                corrected.append(replacement)
                didChange = didChange || replacement != currentWord
                targetCounts[candidate.targetInputSource, default: 0] += 1
            } else {
                corrected.append(currentWord)
            }

            currentWord = ""
        }

        for character in phrase {
            if character.isPhraseWordCharacter {
                currentWord.append(character)
            } else {
                flushWord()
                corrected.append(character)
            }
        }
        flushWord()

        guard didChange, corrected != phrase else {
            return nil
        }

        return TextCorrection(
            original: phrase,
            replacement: corrected,
            undoReplacement: phrase,
            targetInputSource: dominantTarget(from: targetCounts, currentInputSource),
            typedSuffix: ""
        )
    }

    private func bestCandidate(for word: String, preferredCurrentInputSource: InputSource) -> Candidate? {
        let candidates = InputSource.allCases.compactMap { source -> Candidate? in
            let result = detector.detect(word: word, currentInputSource: source)
            guard result.shouldCorrect, let target = result.targetInputSource else {
                return nil
            }
            let replacement = KeyboardLayoutConverter.convert(word, from: source, to: target)
            guard replacement != word else {
                return nil
            }

            return Candidate(
                replacement: replacement,
                targetInputSource: target,
                confidence: result.confidence,
                sourcePriority: source == preferredCurrentInputSource ? 1 : 0
            )
        }

        return candidates.sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence {
                return lhs.sourcePriority > rhs.sourcePriority
            }

            return lhs.confidence > rhs.confidence
        }.first
    }

    private func dominantTarget(from counts: [InputSource: Int], _ fallback: InputSource) -> InputSource {
        counts.sorted { lhs, rhs in
            lhs.value > rhs.value
        }.first?.key ?? (fallback == .english ? .russian : .english)
    }
}

private struct Candidate {
    let replacement: String
    let targetInputSource: InputSource
    let confidence: Double
    let sourcePriority: Int
}

private extension Character {
    var isPhraseWordCharacter: Bool {
        if String(self).unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
            return true
        }

        return "`[];',./-".contains(self)
    }
}
