import AppKit
import PifagorSwitcherCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isEnabled: Bool
    @Published var visualIndicator: Bool
    @Published var sound: Bool
    @Published var launchAtLogin: Bool
    @Published var adaptiveLearning: Bool
    @Published var excludedAppsText: String
    @Published var customDomainWordsText: String
    @Published var urlRulesText: String
    @Published var appModesText: String
    @Published var ignoredWordText: String = ""
    @Published var dictionarySearchText: String = ""
    @Published var dictionaryPreviewText: String

    private let settingsStore: SettingsStore
    private let adaptiveLexiconStore: AdaptiveLexiconStore

    init(settingsStore: SettingsStore, adaptiveLexiconStore: AdaptiveLexiconStore) {
        self.settingsStore = settingsStore
        self.adaptiveLexiconStore = adaptiveLexiconStore
        let state = settingsStore.state
        isEnabled = state.isEnabled
        visualIndicator = state.isVisualIndicatorEnabled
        sound = state.isSoundEnabled
        launchAtLogin = state.launchAtLogin
        adaptiveLearning = state.isAdaptiveLearningEnabled
        excludedAppsText = state.excludedAppBundleIdentifiers.sorted().joined(separator: "\n")
        customDomainWordsText = adaptiveLexiconStore.snapshot.customDomainWords.sorted().joined(separator: "\n")
        urlRulesText = Self.formatInputRules(state.urlRules)
        appModesText = Self.formatAppModes(state.appCorrectionModes)
        dictionaryPreviewText = adaptiveLexiconStore.summaryLines().joined(separator: "\n")
    }

    func save() {
        let excluded = Set(
            excludedAppsText
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        try? settingsStore.update { state in
            SettingsStore.State(
                enabledInputSources: state.enabledInputSources,
                appRules: state.appRules,
                urlRules: Self.parseInputRules(urlRulesText),
                appCorrectionModes: Self.parseAppModes(appModesText),
                excludedAppBundleIdentifiers: excluded,
                isEnabled: isEnabled,
                isVisualIndicatorEnabled: visualIndicator,
                isSoundEnabled: sound,
                launchAtLogin: launchAtLogin,
                isAdaptiveLearningEnabled: adaptiveLearning,
                onboardingCompleted: state.onboardingCompleted
            )
        }
        adaptiveLexiconStore.setCustomDomainWords(Self.words(from: customDomainWordsText))
        refreshDictionaryPreview()

        updateLaunchAtLogin()
    }

    func clearLearning() {
        adaptiveLexiconStore.clearLearning(keepingCustomWords: true)
        refreshDictionaryPreview()
    }

    func ignoreWord() {
        let word = ignoredWordText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else {
            return
        }

        adaptiveLexiconStore.recordIgnoredWord(word)
        ignoredWordText = ""
        refreshDictionaryPreview()
    }

    func refreshDictionaryPreview() {
        dictionaryPreviewText = adaptiveLexiconStore
            .summaryLines(matching: dictionarySearchText)
            .joined(separator: "\n")
    }

    func exportDictionary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "pifagor-adaptive-lexicon.json"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try adaptiveLexiconStore.export(to: url)
        } catch {
            NSLog("PifagorSwitcher dictionary export failed: \(error.localizedDescription)")
        }
    }

    func importDictionary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try adaptiveLexiconStore.importFrom(url: url)
            customDomainWordsText = adaptiveLexiconStore.snapshot.customDomainWords.sorted().joined(separator: "\n")
            refreshDictionaryPreview()
        } catch {
            NSLog("PifagorSwitcher dictionary import failed: \(error.localizedDescription)")
        }
    }

    private static func words(from text: String) -> Set<String> {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;"))
        return Set(
            text
                .components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
    }

    private static func formatInputRules(_ rules: [String: InputSource]) -> String {
        rules
            .sorted { $0.key < $1.key }
            .map { "\($0.key) = \($0.value.rawValue)" }
            .joined(separator: "\n")
    }

    private static func parseInputRules(_ text: String) -> [String: InputSource] {
        var rules: [String: InputSource] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2, let source = InputSource(rawValue: parts[1]), !parts[0].isEmpty else {
                continue
            }
            rules[parts[0]] = source
        }
        return rules
    }

    private static func formatAppModes(_ modes: [String: AppCorrectionMode]) -> String {
        modes
            .sorted { $0.key < $1.key }
            .map { "\($0.key) = \($0.value.rawValue)" }
            .joined(separator: "\n")
    }

    private static func parseAppModes(_ text: String) -> [String: AppCorrectionMode] {
        var modes: [String: AppCorrectionMode] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2, let mode = AppCorrectionMode(rawValue: parts[1]), !parts[0].isEmpty else {
                continue
            }
            modes[parts[0]] = mode
        }
        return modes
    }

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Launch at login update failed: \(error.localizedDescription)")
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            Text("Pifagor Switcher")
                .font(.title2.weight(.semibold))
            HStack(spacing: 4) {
                Text("Разработчик:")
                    .foregroundStyle(.secondary)
                Link(AppBrand.developerName, destination: AppBrand.websiteURL)
                Text("(\(AppBrand.websiteDisplayName))")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            Toggle("Автопереключение включено", isOn: $viewModel.isEnabled)
            Toggle("Показывать индикатор", isOn: $viewModel.visualIndicator)
            Toggle("Звук при исправлении", isOn: $viewModel.sound)
            Toggle("Запускать при входе в систему", isOn: $viewModel.launchAtLogin)
            Toggle("Самообучение", isOn: $viewModel.adaptiveLearning)

            VStack(alignment: .leading, spacing: 8) {
                Text("Исключенные приложения")
                    .font(.headline)
                TextEditor(text: $viewModel.excludedAppsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 130)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("URL-правила")
                    .font(.headline)
                TextEditor(text: $viewModel.urlRulesText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Режимы приложений")
                    .font(.headline)
                TextEditor(text: $viewModel.appModesText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 105)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Пользовательские слова")
                    .font(.headline)
                TextEditor(text: $viewModel.customDomainWordsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 110)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Адаптивный словарь")
                    .font(.headline)
                HStack {
                    TextField("Найти", text: $viewModel.dictionarySearchText)
                        .onChange(of: viewModel.dictionarySearchText) { _, _ in
                            viewModel.refreshDictionaryPreview()
                        }
                    TextField("Не исправлять слово", text: $viewModel.ignoredWordText)
                    Button("Добавить") {
                        viewModel.ignoreWord()
                    }
                }
                TextEditor(text: $viewModel.dictionaryPreviewText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )
                HStack {
                    Button("Импорт") {
                        viewModel.importDictionary()
                    }
                    Button("Экспорт") {
                        viewModel.exportDictionary()
                    }
                }
            }

            HStack {
                Button("Очистить обучение") {
                    viewModel.clearLearning()
                }
                Spacer()
                Button("Сохранить") {
                    viewModel.save()
                }
                .keyboardShortcut(.defaultAction)
            }
            }
        }
        .padding(22)
        .frame(width: 620, height: 760)
    }
}
