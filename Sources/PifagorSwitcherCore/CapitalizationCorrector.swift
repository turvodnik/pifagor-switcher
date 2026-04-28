import Foundation

public struct CapitalizationCorrector: Sendable {
    public init() {}

    public func correction(
        for word: String,
        currentInputSource: InputSource,
        typedSuffix: String = ""
    ) -> TextCorrection? {
        guard let replacement = corrected(word), replacement != word else {
            return nil
        }

        return TextCorrection(
            original: word,
            replacement: replacement,
            undoReplacement: word,
            targetInputSource: currentInputSource,
            typedSuffix: typedSuffix
        )
    }

    public func corrected(_ word: String) -> String? {
        let characters = Array(word)
        guard characters.count >= 3,
              characters[0].isUppercaseLetter,
              characters[1].isUppercaseLetter else {
            return nil
        }

        let tail = characters.dropFirst(2)
        guard tail.contains(where: \.isLowercaseLetter),
              !characters.allSatisfy(\.isUppercaseLetter) else {
            return nil
        }

        let first = String(characters[0])
        let rest = String(characters.dropFirst()).lowercased()
        return first + rest
    }
}

private extension Character {
    var isUppercaseLetter: Bool {
        let string = String(self)
        return string.rangeOfCharacter(from: .letters) != nil
            && string == string.uppercased()
            && string != string.lowercased()
    }

    var isLowercaseLetter: Bool {
        let string = String(self)
        return string.rangeOfCharacter(from: .letters) != nil
            && string == string.lowercased()
            && string != string.uppercased()
    }
}
