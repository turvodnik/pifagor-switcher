import Foundation

public struct AdaptiveLexiconSnapshot: Equatable, Sendable {
    public static let empty = AdaptiveLexiconSnapshot(
        ignoredWords: [],
        confirmedTargets: [:],
        knownEnglishWords: [],
        knownRussianWords: [],
        customEnglishWords: [],
        customRussianWords: []
    )

    private let ignoredWords: Set<String>
    private let confirmedTargets: [String: InputSource]
    private let knownEnglishWords: Set<String>
    private let knownRussianWords: Set<String>
    private let customEnglishWords: Set<String>
    private let customRussianWords: Set<String>

    public init(
        ignoredWords: Set<String>,
        confirmedTargets: [String: InputSource],
        knownEnglishWords: Set<String>,
        knownRussianWords: Set<String>,
        customEnglishWords: Set<String>,
        customRussianWords: Set<String>
    ) {
        self.ignoredWords = ignoredWords
        self.confirmedTargets = confirmedTargets
        self.knownEnglishWords = knownEnglishWords
        self.knownRussianWords = knownRussianWords
        self.customEnglishWords = customEnglishWords
        self.customRussianWords = customRussianWords
    }

    public func isIgnored(_ word: String) -> Bool {
        ignoredWords.contains(Self.normalized(word))
    }

    public func isKnown(_ word: String, as inputSource: InputSource) -> Bool {
        let normalized = Self.normalized(word)
        switch inputSource {
        case .english:
            return knownEnglishWords.contains(normalized) || customEnglishWords.contains(normalized)
        case .russian:
            return knownRussianWords.contains(normalized) || customRussianWords.contains(normalized)
        }
    }

    public func confirmedTarget(for word: String, currentInputSource: InputSource) -> InputSource? {
        confirmedTargets[Self.confirmedKey(word: word, currentInputSource: currentInputSource)]
    }

    public var customDomainWords: Set<String> {
        customEnglishWords.union(customRussianWords)
    }

    static func normalized(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func confirmedKey(word: String, currentInputSource: InputSource) -> String {
        "\(currentInputSource.rawValue):\(normalized(word))"
    }
}

public final class AdaptiveLexiconStore: @unchecked Sendable {
    private struct State: Codable, Equatable {
        var ignoredWords: Set<String> = []
        var confirmedTargets: [String: InputSource] = [:]
        var manualCorrectionCounts: [String: Int] = [:]
        var acceptedWordCountsBySource: [String: [String: Int]] = [:]
        var customWordsBySource: [String: Set<String>] = [:]
    }

    private static let acceptedWordThreshold = 3
    private static let manualCorrectionThreshold = 2

    private let fileURL: URL
    private let queue = DispatchQueue(label: "app.pifagor.switcher.adaptive-lexicon")
    private var stateStorage: State

    public var snapshot: AdaptiveLexiconSnapshot {
        queue.sync { Self.snapshot(from: stateStorage) }
    }

    public func summaryLines(matching query: String = "") -> [String] {
        let normalizedQuery = AdaptiveLexiconSnapshot.normalized(query)
        return queue.sync {
            var lines: [String] = []
            lines += stateStorage.ignoredWords.sorted().map { "ignore: \($0)" }
            lines += stateStorage.confirmedTargets.sorted { $0.key < $1.key }.map { "rule: \($0.key) -> \($0.value.rawValue)" }
            for source in InputSource.allCases {
                let words = stateStorage.acceptedWordCountsBySource[source.rawValue, default: [:]]
                lines += words
                    .sorted { lhs, rhs in lhs.key < rhs.key }
                    .map { "known[\(source.rawValue)]: \($0.key) x\($0.value)" }
                let custom = stateStorage.customWordsBySource[source.rawValue, default: []]
                lines += custom.sorted().map { "custom[\(source.rawValue)]: \($0)" }
            }

            guard !normalizedQuery.isEmpty else {
                return lines
            }

            return lines.filter { $0.lowercased().contains(normalizedQuery) }
        }
    }

    public init(fileURL: URL? = nil) {
        let defaultURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("PifagorSwitcher", isDirectory: true)
            .appendingPathComponent("adaptive-lexicon.json")

        self.fileURL = fileURL ?? defaultURL ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pifagor-adaptive-lexicon.json")
        self.stateStorage = Self.load(from: self.fileURL)
    }

    public func recordManualCorrection(
        original: String,
        replacement: String,
        currentInputSource: InputSource
    ) {
        let original = AdaptiveLexiconSnapshot.normalized(original)
        let replacement = AdaptiveLexiconSnapshot.normalized(replacement)
        guard !original.isEmpty, !replacement.isEmpty, original != replacement else {
            return
        }

        let targetInputSource = currentInputSource == .english ? InputSource.russian : .english
        let converted = AdaptiveLexiconSnapshot.normalized(
            KeyboardLayoutConverter.convert(original, from: currentInputSource, to: targetInputSource)
        )

        queue.sync {
            if let replacementSource = Self.detectSource(for: replacement) {
                incrementAcceptedWord(replacement, inputSource: replacementSource, in: &stateStorage)
            }

            guard converted == replacement else {
                persistIgnoringErrors()
                return
            }

            let key = AdaptiveLexiconSnapshot.confirmedKey(word: original, currentInputSource: currentInputSource)
            stateStorage.manualCorrectionCounts[key, default: 0] += 1
            if stateStorage.manualCorrectionCounts[key, default: 0] >= Self.manualCorrectionThreshold {
                stateStorage.confirmedTargets[key] = targetInputSource
                stateStorage.ignoredWords.remove(original)
            }
            persistIgnoringErrors()
        }
    }

    public func recordRejectedCorrection(original: String, replacement: String) {
        let original = AdaptiveLexiconSnapshot.normalized(original)
        let replacement = AdaptiveLexiconSnapshot.normalized(replacement)
        guard !original.isEmpty else {
            return
        }

        queue.sync {
            stateStorage.ignoredWords.insert(original)
            if !replacement.isEmpty {
                stateStorage.ignoredWords.remove(replacement)
            }
            stateStorage.confirmedTargets = stateStorage.confirmedTargets.filter { key, _ in
                !key.hasSuffix(":\(original)")
            }
            persistIgnoringErrors()
        }
    }

    public func recordIgnoredWord(_ word: String) {
        let word = AdaptiveLexiconSnapshot.normalized(word)
        guard Self.canLearnWord(word) else {
            return
        }

        queue.sync {
            stateStorage.ignoredWords.insert(word)
            persistIgnoringErrors()
        }
    }

    public func recordAcceptedWord(_ word: String, inputSource: InputSource) {
        let word = AdaptiveLexiconSnapshot.normalized(word)
        guard Self.canLearnWord(word) else {
            return
        }

        queue.sync {
            let newCount = incrementAcceptedWord(word, inputSource: inputSource, in: &stateStorage)
            if newCount == Self.acceptedWordThreshold {
                persistIgnoringErrors()
            }
        }
    }

    public func setCustomDomainWords(_ words: Set<String>) {
        var next: [String: Set<String>] = [:]
        for word in words.map(AdaptiveLexiconSnapshot.normalized) where Self.canLearnWord(word) {
            guard let inputSource = Self.detectSource(for: word) else {
                continue
            }
            next[inputSource.rawValue, default: []].insert(word)
        }

        queue.sync {
            stateStorage.customWordsBySource = next
            persistIgnoringErrors()
        }
    }

    public func clearLearning(keepingCustomWords: Bool = true) {
        queue.sync {
            let customWords = keepingCustomWords ? stateStorage.customWordsBySource : [:]
            stateStorage = State(customWordsBySource: customWords)
            persistIgnoringErrors()
        }
    }

    public func export(to url: URL) throws {
        let data = try queue.sync {
            try JSONEncoder().encode(stateStorage)
        }
        try data.write(to: url, options: [.atomic])
    }

    public func importFrom(url: URL) throws {
        let data = try Data(contentsOf: url)
        let imported = try JSONDecoder().decode(State.self, from: data)
        try queue.sync {
            stateStorage = imported
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(stateStorage)
            try data.write(to: fileURL, options: [.atomic])
        }
    }

    private static func snapshot(from state: State) -> AdaptiveLexiconSnapshot {
        let acceptedEnglish = Set(
            state.acceptedWordCountsBySource[InputSource.english.rawValue, default: [:]]
                .filter { $0.value >= acceptedWordThreshold }
                .map(\.key)
        )
        let acceptedRussian = Set(
            state.acceptedWordCountsBySource[InputSource.russian.rawValue, default: [:]]
                .filter { $0.value >= acceptedWordThreshold }
                .map(\.key)
        )

        return AdaptiveLexiconSnapshot(
            ignoredWords: state.ignoredWords,
            confirmedTargets: state.confirmedTargets,
            knownEnglishWords: acceptedEnglish,
            knownRussianWords: acceptedRussian,
            customEnglishWords: state.customWordsBySource[InputSource.english.rawValue, default: []],
            customRussianWords: state.customWordsBySource[InputSource.russian.rawValue, default: []]
        )
    }

    @discardableResult
    private func incrementAcceptedWord(_ word: String, inputSource: InputSource, in state: inout State) -> Int {
        let source = inputSource.rawValue
        let current = state.acceptedWordCountsBySource[source, default: [:]][word, default: 0]
        guard current < Self.acceptedWordThreshold else {
            return current
        }

        let next = current + 1
        state.acceptedWordCountsBySource[source, default: [:]][word] = next
        return next
    }

    private static func detectSource(for word: String) -> InputSource? {
        let scalars = word.unicodeScalars
        guard !scalars.isEmpty else {
            return nil
        }

        let latin = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz-")
        let cyrillic = CharacterSet(charactersIn: "абвгдеёжзийклмнопрстуфхцчшщъыьэюя-")
        if scalars.allSatisfy({ latin.contains($0) }) {
            return .english
        }
        if scalars.allSatisfy({ cyrillic.contains($0) }) {
            return .russian
        }
        return nil
    }

    private static func canLearnWord(_ word: String) -> Bool {
        guard word.count >= 2 else {
            return false
        }

        return word.unicodeScalars.allSatisfy {
            CharacterSet.letters.contains($0) || CharacterSet(charactersIn: "-").contains($0)
        }
    }

    private static func load(from url: URL) -> State {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(State.self, from: data) else {
            return State()
        }
        return decoded
    }

    private func persistIgnoringErrors() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(stateStorage)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("PifagorSwitcher adaptive lexicon persist failed: \(error.localizedDescription)")
        }
    }
}
