import Foundation

public enum AppCorrectionMode: String, Codable, CaseIterable, Equatable, Sendable {
    case normal
    case manualOnly
    case disabled

    public var displayName: String {
        switch self {
        case .normal:
            return "Обычный"
        case .manualOnly:
            return "Только вручную"
        case .disabled:
            return "Выключено"
        }
    }
}
