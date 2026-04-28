import ApplicationServices
import Carbon
import PifagorSwitcherCore
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var accessibilityTrusted: Bool
    @Published var inputMonitoringTrusted: Bool
    @Published var eventTapRunning: Bool
    @Published var conflictingApps: [String]

    private let settingsStore: SettingsStore
    private let eventTapStatus: () -> Bool
    private let conflictProvider: () -> [String]
    private let onClose: () -> Void

    init(
        settingsStore: SettingsStore,
        eventTapStatus: @escaping () -> Bool,
        conflictProvider: @escaping () -> [String],
        onClose: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.eventTapStatus = eventTapStatus
        self.conflictProvider = conflictProvider
        self.onClose = onClose
        self.accessibilityTrusted = AXIsProcessTrusted()
        self.inputMonitoringTrusted = CGPreflightListenEventAccess()
        self.eventTapRunning = eventTapStatus()
        self.conflictingApps = conflictProvider()
    }

    func refresh() {
        accessibilityTrusted = AXIsProcessTrusted()
        inputMonitoringTrusted = CGPreflightListenEventAccess()
        eventTapRunning = eventTapStatus()
        conflictingApps = conflictProvider()
    }

    func openAccessibility() {
        openPrivacyPane(anchor: "Privacy_Accessibility")
    }

    func openInputMonitoring() {
        openPrivacyPane(anchor: "Privacy_ListenEvent")
    }

    func finish() {
        try? settingsStore.update { state in
            state.withOnboardingCompleted(true)
        }
        onClose()
    }

    private func openPrivacyPane(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Настройка Pifagor Switcher")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                statusRow("Accessibility", viewModel.accessibilityTrusted)
                statusRow("Input Monitoring", viewModel.inputMonitoringTrusted)
                statusRow("Keyboard event tap", viewModel.eventTapRunning)
                statusRow(
                    "Конфликты",
                    viewModel.conflictingApps.isEmpty,
                    value: viewModel.conflictingApps.isEmpty ? "нет" : viewModel.conflictingApps.joined(separator: ", ")
                )
            }

            HStack {
                Button("Открыть Accessibility") {
                    viewModel.openAccessibility()
                }
                Button("Открыть Input Monitoring") {
                    viewModel.openInputMonitoring()
                }
            }

            HStack {
                Button("Проверить снова") {
                    viewModel.refresh()
                }
                Spacer()
                Button("Готово") {
                    viewModel.finish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func statusRow(_ title: String, _ ok: Bool, value: String? = nil) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? Color.green : Color.orange)
            Text(title)
            Spacer()
            Text(value ?? (ok ? "OK" : "NO"))
                .foregroundStyle(.secondary)
        }
    }
}
