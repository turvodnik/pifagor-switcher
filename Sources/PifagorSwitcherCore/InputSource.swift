import Foundation

public enum InputSource: String, Codable, CaseIterable, Equatable, Sendable {
    case english
    case russian

    public var languageCode: String {
        switch self {
        case .english:
            return "en"
        case .russian:
            return "ru"
        }
    }

    public var displayName: String {
        switch self {
        case .english:
            return "English"
        case .russian:
            return "Русский"
        }
    }
}
