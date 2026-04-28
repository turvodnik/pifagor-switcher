import AppKit
import ApplicationServices
import PifagorSwitcherCore

@MainActor
struct Diagnostics {
    let accessibilityTrusted: Bool
    let inputMonitoringTrusted: Bool
    let eventTapRunning: Bool
    let eventTapFailure: String?
    let currentInputSource: InputSource?
    let frontmostApplication: String
    let correctionMode: AppCorrectionMode
    let settingsEnabled: Bool
    let conflictingApps: [String]

    var report: String {
        [
            "Pifagor Switcher diagnostics",
            "",
            "Accessibility: \(accessibilityTrusted ? "OK" : "NO")",
            "Input Monitoring: \(inputMonitoringTrusted ? "OK" : "NO")",
            "Keyboard event tap: \(eventTapRunning ? "OK" : "NO")",
            "Event tap failure: \(eventTapFailure ?? "-")",
            "Current input source: \(currentInputSource?.displayName ?? "unknown")",
            "Frontmost app: \(frontmostApplication)",
            "Correction mode: \(correctionMode.displayName) (\(correctionMode.rawValue))",
            "Switcher enabled: \(settingsEnabled ? "YES" : "NO")",
            "Conflicting switchers: \(conflictingApps.isEmpty ? "-" : conflictingApps.joined(separator: ", "))",
            "",
            correctionMode == .manualOnly ? "Для текущего приложения включен режим только ручных исправлений: автопереключение при наборе не выполняется." : "",
            correctionMode == .disabled ? "Для текущего приложения исправления отключены полностью." : "",
            "Автоисправление слова выполняется на пробеле/пунктуации; двойной Ctrl/Shift исправляет выделение или текущую фразу вручную.",
            conflictingApps.isEmpty ? "" : "Закройте другие автопереключатели раскладки перед проверкой Pifagor Switcher.",
            "Если Input Monitoring или Accessibility = NO, включите разрешение в System Settings и перезапустите приложение.",
            "Если приложение открыто из zip или Downloads и macOS блокирует запуск, перенесите .app в Applications или запустите из терминала на время разработки."
        ].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

@MainActor
final class DiagnosticsWindow {
    private var window: NSWindow?

    func show(_ diagnostics: Diagnostics) {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 560, height: 320))
        textView.string = diagnostics.report
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 320))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Диагностика Pifagor Switcher"
        window.contentView = scrollView
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }
}
