import Foundation

public enum TypingEvent: Equatable, Sendable {
    case character(Character)
    case wordBoundary
    case backspace
    case enter
    case escape
    case appChanged
    case cursorMoved
}

public struct LastTypedWord: Equatable, Sendable {
    public let word: String
    public let trailingSuffix: String

    public init(word: String, trailingSuffix: String) {
        self.word = word
        self.trailingSuffix = trailingSuffix
    }
}

public struct TypingBuffer: Equatable, Sendable {
    private static let maximumPhraseLength = 500

    public private(set) var currentWord: String
    public private(set) var currentPhrase: String

    public init(currentWord: String = "", currentPhrase: String = "") {
        self.currentWord = currentWord
        self.currentPhrase = currentPhrase
    }

    public var currentOrLastWord: LastTypedWord? {
        if !currentWord.isEmpty {
            return LastTypedWord(word: currentWord, trailingSuffix: "")
        }

        let characters = Array(currentPhrase)
        guard !characters.isEmpty else {
            return nil
        }

        var suffixStart = characters.count
        while suffixStart > 0, !characters[suffixStart - 1].isTypingWordCharacter {
            suffixStart -= 1
        }

        var wordStart = suffixStart
        while wordStart > 0, characters[wordStart - 1].isTypingWordCharacter {
            wordStart -= 1
        }

        guard wordStart < suffixStart else {
            return nil
        }

        return LastTypedWord(
            word: String(characters[wordStart..<suffixStart]),
            trailingSuffix: String(characters[suffixStart..<characters.count])
        )
    }

    public mutating func record(_ event: TypingEvent) -> String? {
        switch event {
        case .character(let character):
            currentWord.append(character)
            currentPhrase.append(character)
            trimPhraseIfNeeded()
            return nil
        case .wordBoundary:
            let completed = currentWord
            currentWord = ""
            return completed.isEmpty ? nil : completed
        case .backspace:
            guard !currentPhrase.isEmpty else {
                currentWord = ""
                return nil
            }

            currentPhrase.removeLast()
            currentWord = Self.trailingWord(in: currentPhrase)
            return nil
        case .enter, .escape, .appChanged, .cursorMoved:
            currentWord = ""
            currentPhrase = ""
            return nil
        }
    }

    public mutating func appendBoundary(_ boundary: String) {
        guard !boundary.isEmpty else {
            return
        }

        currentPhrase.append(contentsOf: boundary)
        trimPhraseIfNeeded()
    }

    public mutating func replaceCurrentWord(with replacement: String) {
        replaceTrailingText(characterCount: currentWord.count, with: replacement)
        currentWord = replacement
    }

    public mutating func replaceCurrentPhrase(with replacement: String) {
        currentPhrase = replacement
        currentWord = Self.trailingWord(in: replacement)
        trimPhraseIfNeeded()
    }

    public mutating func replaceLastTypedWord(_ lastTypedWord: LastTypedWord, with replacement: String) {
        replaceTrailingText(
            characterCount: lastTypedWord.word.count + lastTypedWord.trailingSuffix.count,
            with: replacement + lastTypedWord.trailingSuffix
        )
    }

    public mutating func replaceTrailingText(characterCount: Int, with replacement: String) {
        guard characterCount > 0, characterCount <= currentPhrase.count else {
            return
        }

        currentPhrase.removeLast(characterCount)
        currentPhrase.append(contentsOf: replacement)
        currentWord = Self.trailingWord(in: currentPhrase)
        trimPhraseIfNeeded()
    }

    private mutating func trimPhraseIfNeeded() {
        guard currentPhrase.count > Self.maximumPhraseLength else {
            return
        }

        currentPhrase = String(currentPhrase.suffix(Self.maximumPhraseLength))
        currentWord = Self.trailingWord(in: currentPhrase)
    }

    private static func trailingWord(in text: String) -> String {
        let reversedWord = text.reversed().prefix { character in
            character.isTypingWordCharacter
        }
        return String(reversedWord.reversed())
    }
}

private extension Character {
    var isTypingWordCharacter: Bool {
        if String(self).unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
            return true
        }

        return "`[];',./-".contains(self)
    }
}
