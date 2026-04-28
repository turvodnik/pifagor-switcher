import Foundation

public enum KeyboardLayoutConverter {
    private static let englishToRussian: [Character: Character] = [
        "`": "ё",
        "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н", "u": "г", "i": "ш", "o": "щ", "p": "з", "[": "х", "]": "ъ",
        "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р", "j": "о", "k": "л", "l": "д", ";": "ж", "'": "э",
        "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т", "m": "ь"
    ]

    private static let russianToEnglish: [Character: Character] = Dictionary(
        uniqueKeysWithValues: englishToRussian.map { ($0.value, $0.key) } + [
            ("б", ","),
            ("ю", ".")
        ]
    )

    public static func convert(_ text: String, from source: InputSource, to target: InputSource) -> String {
        guard source != target else {
            return text
        }

        let map = source == .english ? englishToRussian : russianToEnglish
        let characters = Array(text)
        return String(characters.enumerated().map { index, character in
            converted(character, at: index, in: characters, from: source, to: target, using: map)
        })
    }

    private static func converted(
        _ character: Character,
        at index: Int,
        in text: [Character],
        from source: InputSource,
        to target: InputSource,
        using map: [Character: Character]
    ) -> Character {
        if source == .english, target == .russian,
           let embeddedReplacement = embeddedRussianLetter(for: character, at: index, in: text) {
            return embeddedReplacement
        }

        if let replacement = map[character] {
            return replacement
        }

        let lowercased = Character(String(character).lowercased())
        guard let lowerReplacement = map[lowercased] else {
            return character
        }

        let original = String(character)
        if original == original.uppercased(), original != original.lowercased() {
            return Character(String(lowerReplacement).uppercased())
        }

        return lowerReplacement
    }

    private static func embeddedRussianLetter(for character: Character, at index: Int, in text: [Character]) -> Character? {
        let embeddedMap: [Character: Character] = [
            ",": "б",
            ".": "ю"
        ]

        guard let replacement = embeddedMap[character],
              index > 0,
              index < text.count - 1,
              text[index - 1].isLetterLike,
              text[index + 1].isLetterLike else {
            return nil
        }

        return replacement
    }
}

private extension Character {
    var isLetterLike: Bool {
        String(self).unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }
}
