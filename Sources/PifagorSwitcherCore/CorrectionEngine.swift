import Foundation

public enum CorrectionTrigger: Equatable, Sendable {
    case live
    case wordBoundary
    case punctuation
    case manual
    case enter
    case escape
}

public struct TextCorrection: Equatable, Sendable {
    public let original: String
    public let replacement: String
    public let undoReplacement: String
    public let targetInputSource: InputSource
    public let typedSuffix: String
    public let deleteLength: Int
    public let insertedText: String
    public let undoDeleteLength: Int
    public let undoInsertedText: String

    public init(
        original: String,
        replacement: String,
        undoReplacement: String,
        targetInputSource: InputSource,
        typedSuffix: String
    ) {
        self.original = original
        self.replacement = replacement
        self.undoReplacement = undoReplacement
        self.targetInputSource = targetInputSource
        self.typedSuffix = typedSuffix
        self.deleteLength = original.count + typedSuffix.count
        self.insertedText = replacement + typedSuffix
        self.undoDeleteLength = replacement.count + typedSuffix.count
        self.undoInsertedText = undoReplacement + typedSuffix
    }
}

public struct CorrectionEngine: Sendable {
    public init() {}

    public func shouldAttemptCorrection(trigger: CorrectionTrigger) -> Bool {
        switch trigger {
        case .live, .wordBoundary, .punctuation, .manual:
            return true
        case .enter, .escape:
            return false
        }
    }

    public func correction(
        for word: String,
        currentInputSource: InputSource,
        targetInputSource: InputSource,
        typedSuffix: String = ""
    ) -> TextCorrection? {
        guard !word.isEmpty, currentInputSource != targetInputSource else {
            return nil
        }

        let replacement = KeyboardLayoutConverter.convert(word, from: currentInputSource, to: targetInputSource)
        guard replacement != word else {
            return nil
        }

        return TextCorrection(
            original: word,
            replacement: replacement,
            undoReplacement: word,
            targetInputSource: targetInputSource,
            typedSuffix: typedSuffix
        )
    }
}
