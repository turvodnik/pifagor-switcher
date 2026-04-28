import Foundation

#if os(macOS)
import Carbon

public struct InputSourceDescriptor: Equatable, Sendable {
    public let id: String
    public let localizedName: String
    public let source: InputSource?

    public init(id: String, localizedName: String, source: InputSource?) {
        self.id = id
        self.localizedName = localizedName
        self.source = source
    }
}

public protocol InputSourceManaging: Sendable {
    func currentInputSource() -> InputSource?
    func select(_ source: InputSource) -> Bool
}

public final class InputSourceManager: InputSourceManaging, @unchecked Sendable {
    public init() {}

    public func currentInputSource() -> InputSource? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let id = sourceIdentifier(for: source) else {
            return nil
        }

        return inputSource(fromIdentifier: id)
    }

    public func select(_ source: InputSource) -> Bool {
        guard let inputSource = keyboardInputSources().first(where: { descriptor in
            descriptor.source == source
        }) else {
            return false
        }

        return TISSelectInputSource(inputSource.rawSource) == noErr
    }

    public func availableInputSources() -> [InputSourceDescriptor] {
        keyboardInputSources().map { descriptor in
            InputSourceDescriptor(
                id: descriptor.id,
                localizedName: descriptor.localizedName,
                source: descriptor.source
            )
        }
    }

    private struct RawInputSource {
        let rawSource: TISInputSource
        let id: String
        let localizedName: String
        let source: InputSource?
    }

    private func keyboardInputSources() -> [RawInputSource] {
        let properties: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String
        ]

        guard let sources = TISCreateInputSourceList(properties as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }

        return sources.compactMap { source in
            guard let id = sourceIdentifier(for: source) else {
                return nil
            }

            return RawInputSource(
                rawSource: source,
                id: id,
                localizedName: localizedName(for: source) ?? id,
                source: inputSource(fromIdentifier: id)
            )
        }
    }

    private func sourceIdentifier(for source: TISInputSource) -> String? {
        unsafeBitCast(
            TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
            to: CFString?.self
        ) as String?
    }

    private func localizedName(for source: TISInputSource) -> String? {
        unsafeBitCast(
            TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
            to: CFString?.self
        ) as String?
    }

    private func inputSource(fromIdentifier identifier: String) -> InputSource? {
        let lowercased = identifier.lowercased()
        if lowercased.contains("russian") || lowercased.contains(".ru") {
            return .russian
        }

        if lowercased.contains("abc") || lowercased.contains("roman") || lowercased.contains("us") {
            return .english
        }

        return nil
    }
}
#endif
