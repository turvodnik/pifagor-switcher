import AppKit
import ApplicationServices
import Carbon
import PifagorSwitcherCore
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settingsStore = SettingsStore()
    private let adaptiveLexiconStore = AdaptiveLexiconStore()
    private let inputSourceManager = InputSourceManager()
    private let indicator = InputSourceIndicator()
    private let textReplayer = TextReplayer()
    private let diagnosticsWindow = DiagnosticsWindow()

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var monitor: KeyboardEventMonitor?
    private var controller: TypingController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        requestAccessibilityPermissionIfNeeded()

        let controller = TypingController(
            settingsStore: settingsStore,
            adaptiveLexiconStore: adaptiveLexiconStore,
            inputSourceManager: inputSourceManager,
            indicator: indicator,
            textReplayer: textReplayer
        )
        self.controller = controller

        monitor = KeyboardEventMonitor { [weak controller] event in
            controller?.handle(event)
        }
        if monitor?.start() == false {
            indicator.show(text: "Нужен Input Monitoring")
        }
        showOnboardingIfNeeded()
    }

    private func configureStatusItem() {
        if let iconURL = Bundle.main.url(forResource: "StatusIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "П"
        }
        statusItem.button?.toolTip = "Pifagor Switcher"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "О приложении...", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Настройки...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Первичная настройка...", action: #selector(openOnboarding), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Диагностика...", action: #selector(openDiagnostics), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "Сайт разработчика", action: #selector(openDeveloperWebsite), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Двойной Ctrl: исправить фразу", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Пауза", action: #selector(toggleEnabled), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Отменить исправление", action: #selector(undoLastCorrection), keyEquivalent: "z"))
        menu.addItem(NSMenuItem(title: "Исправить текущее слово: Ctrl+Option+C", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Открыть Accessibility", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Открыть Input Monitoring", action: #selector(openInputMonitoringSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let viewModel = SettingsViewModel(
                settingsStore: settingsStore,
                adaptiveLexiconStore: adaptiveLexiconStore
            )
            let view = SettingsView(viewModel: viewModel)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 760),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Pifagor Switcher"
            window.contentView = NSHostingView(rootView: view)
            window.center()
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAbout() {
        let alert = NSAlert()
        alert.messageText = "Pifagor Switcher"
        alert.informativeText = "Разработчик: \(AppBrand.developerName)\nСайт: \(AppBrand.websiteDisplayName)"
        alert.addButton(withTitle: "Открыть сайт")
        alert.addButton(withTitle: "Закрыть")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(AppBrand.websiteURL)
        }
    }

    @objc private func openDeveloperWebsite() {
        NSWorkspace.shared.open(AppBrand.websiteURL)
    }

    @objc private func openOnboarding() {
        showOnboarding()
    }

    @objc private func toggleEnabled() {
        controller?.handle(.toggleEnabled)
    }

    @objc private func undoLastCorrection() {
        controller?.undoLastCorrection()
    }

    @objc private func openDiagnostics() {
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        diagnosticsWindow.show(
            Diagnostics(
                accessibilityTrusted: AXIsProcessTrusted(),
                inputMonitoringTrusted: CGPreflightListenEventAccess(),
                eventTapRunning: monitor?.isRunning ?? false,
                eventTapFailure: monitor?.lastStartFailure,
                currentInputSource: inputSourceManager.currentInputSource(),
                frontmostApplication: frontmostBundleIdentifier,
                correctionMode: AppRuleEngine(settings: settingsStore.state)
                    .correctionMode(for: frontmostBundleIdentifier),
                liveCorrectionEnabled: settingsStore.state.isLiveCorrectionEnabled,
                lastCorrectionSkipReason: controller?.lastCorrectionSkipReason ?? "-",
                settingsEnabled: settingsStore.state.isEnabled,
                conflictingApps: runningConflictingSwitchers()
            )
        )
    }

    private func runningConflictingSwitchers() -> [String] {
        let conflicts: Set<String> = [
            "ru.yandex.desktop.PuntoSwitcher",
            "ru.yandex.punto",
            "com.keywiz.keywiz",
            "com.caramba-switcher.CarambaSwitcher"
        ]

        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bundleIdentifier = app.bundleIdentifier,
                  bundleIdentifier != Bundle.main.bundleIdentifier,
                  conflicts.contains(bundleIdentifier) else {
                return nil
            }

            return app.localizedName ?? bundleIdentifier
        }
    }

    private func showOnboardingIfNeeded() {
        let needsPermissions = !AXIsProcessTrusted()
            || !CGPreflightListenEventAccess()
            || !(monitor?.isRunning ?? false)
        if !settingsStore.state.onboardingCompleted || needsPermissions || !runningConflictingSwitchers().isEmpty {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            let viewModel = OnboardingViewModel(
                settingsStore: settingsStore,
                eventTapStatus: { [weak self] in self?.monitor?.isRunning ?? false },
                conflictProvider: { [weak self] in self?.runningConflictingSwitchers() ?? [] },
                onClose: { [weak self] in self?.onboardingWindow?.close() }
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Настройка Pifagor Switcher"
            window.contentView = NSHostingView(rootView: OnboardingView(viewModel: viewModel))
            window.center()
            onboardingWindow = window
        }

        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openAccessibilitySettings() {
        openPrivacyPane(anchor: "Privacy_Accessibility")
    }

    @objc private func openInputMonitoringSettings() {
        openPrivacyPane(anchor: "Privacy_ListenEvent")
    }

    private func openPrivacyPane(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else {
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
