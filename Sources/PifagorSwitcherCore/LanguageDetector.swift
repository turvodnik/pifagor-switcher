import Foundation

public struct DetectionResult: Equatable, Sendable {
    public let targetInputSource: InputSource?
    public let confidence: Double
    public let shouldCorrect: Bool

    public static let noCorrection = DetectionResult(
        targetInputSource: nil,
        confidence: 0,
        shouldCorrect: false
    )
}

public struct LanguageDetector: Sendable {
    private let minimumLength = 3
    private let correctionThreshold = 0.80
    private let adaptiveLexicon: AdaptiveLexiconSnapshot

    private let commonRussianWords: Set<String> = [
        "привет", "мир", "как", "дела", "спасибо", "пожалуйста", "да", "нет", "это", "что",
        "сегодня", "завтра", "почта", "текст", "сообщение", "работа", "можно", "нужно",
        "я", "и", "в", "к", "с", "у", "о", "а", "мы", "вы", "ты", "он", "она", "оно", "они",
        "не", "на", "по", "за", "из", "от", "до", "то", "же", "ли", "но", "или", "для", "про",
        "меня", "тебя", "нас", "вас", "мой", "твой", "наш", "ваш", "его", "ее", "их",
        "есть", "был", "была", "были", "будет", "буду", "будем", "хочу", "надо", "если",
        "тогда", "тут", "там", "где", "когда", "почему", "потому", "давай", "сделай",
        "проверь", "проверить", "исправь", "исправить", "напиши", "нужно", "можешь",
        "приложение", "раскладка", "клавиатура", "слово", "слова", "фраза", "предложение",
        "ошибка", "работает", "работать", "удаляет", "удалилось", "закрылось", "переключи",
        "переключить", "русский", "английский", "быстро", "удобно", "умно"
        , "туда", "логика", "логику", "переключение", "переключения", "исправление",
        "исправления", "исправлений", "потом", "мы", "ее", "её", "улучшим", "курсор",
        "поле", "поля", "момент", "момента", "поставил", "поставила", "поставить",
        "предыдущее", "написанное", "включая", "пробел", "пробелы", "целое",
        "автоматически", "неправильно", "откат", "откатить", "откатиться", "стрелка",
        "стрелки", "влево", "вправо", "после", "перед", "использовал", "использовала",
        "библиотека", "библиотеку", "понимает", "многие", "возьми", "оттуда"
    ]

    private let professionalRussianWords: Set<String> = [
        "вордпресс", "вордпресса", "вордпрессе", "плагин", "плагины", "плагина",
        "тема", "темы", "шаблон", "шаблоны", "сайт", "сайта", "сайты", "страница",
        "страницы", "лендинг", "лендинги", "реклама", "рекламы", "рекламу",
        "маркетинг", "таргет", "контекст", "директ", "аналитика", "аналитику",
        "метрика", "конверсия", "конверсии", "трафик", "лид", "лиды", "воронка",
        "кампания", "кампании", "клик", "клики", "бюджет", "ставка", "сегмент",
        "аудитория", "аудитории", "поиск", "запрос", "запросы", "ключи",
        "ключевики", "семантика", "сниппет", "индексация", "схема", "микроразметка",
        "бекенд", "бэкенд", "фронтенд", "фулстек", "верстка", "вёрстка",
        "разработка", "вебразработка", "домен", "хостинг", "сервер", "кэш", "кеш",
        "апи", "эндпоинт", "вебхук", "база", "данные", "нейросеть", "нейросети",
        "нейронка", "ии", "чатбот", "промпт", "промпты", "контент", "копирайтинг",
        "дизайн", "макет", "прототип", "бренд", "креатив", "оффер", "ретаргетинг",
        "пиксель", "тег", "теги", "событие", "события"
    ]

    private let commonEnglishWords: Set<String> = [
        "hello", "world", "thanks", "please", "yes", "no", "today", "tomorrow", "text",
        "message", "work", "user", "email", "code", "swift",
        "i", "a", "to", "in", "on", "of", "or", "we", "he", "it", "is", "am", "are", "be",
        "my", "me", "you", "your", "our", "us", "hi", "ok", "go", "do", "up", "if", "so",
        "the", "and", "for", "with", "that", "this", "from", "have", "not", "can", "will",
        "test", "testing", "keyboard", "layout", "switch", "switcher", "input", "source",
        "app", "application", "window", "word", "words", "phrase", "sentence", "space",
        "delete", "deleted", "close", "closed", "fix", "fixed", "correct", "correction",
        "paste", "copy", "notes", "textedit", "browser", "terminal", "settings", "access",
        "permission", "monitoring", "english", "russian", "fast", "smart", "local",
        "wordpress", "claude", "github", "openai", "chatgpt", "google", "chrome",
        "safari", "vscode", "cursor", "xcode", "swiftui", "macos", "linux", "docker",
        "api", "json", "http", "https", "url", "true", "false", "null"
    ]

    private let professionalEnglishWords: Set<String> = [
        "wordpress", "plugin", "plugins", "theme", "themes", "template", "templates",
        "woocommerce", "elementor", "gutenberg", "acf", "yoast", "rankmath",
        "seo", "sem", "smm", "ppc", "cpc", "cpa", "cpm", "roi", "utm", "ads", "ad",
        "campaign", "campaigns", "marketing", "advertising", "analytics", "metric",
        "metrics", "conversion", "conversions", "traffic", "landing", "funnel",
        "lead", "leads", "click", "clicks", "pixel", "tag", "tags", "event", "events",
        "content", "keyword", "keywords", "query", "queries", "search", "ranking",
        "crawl", "index", "sitemap", "schema", "snippet", "backlink", "backlinks",
        "domain", "hosting", "server", "frontend", "backend", "fullstack",
        "javascript", "typescript", "react", "nextjs", "node", "npm", "css", "html",
        "php", "mysql", "database", "endpoint", "webhook", "cache", "cms", "page",
        "pages", "site", "website", "design", "prototype", "brand", "creative",
        "offer", "retargeting", "facebook", "instagram", "tiktok", "linkedin",
        "meta", "ai", "chatbot", "prompt", "prompts"
    ]

    public init(adaptiveLexicon: AdaptiveLexiconSnapshot = .empty) {
        self.adaptiveLexicon = adaptiveLexicon
    }

    public func detect(word: String, currentInputSource: InputSource) -> DetectionResult {
        guard isStructurallyCandidate(word) else {
            return .noCorrection
        }
        if adaptiveLexicon.isIgnored(word) || adaptiveLexicon.isKnown(word, as: currentInputSource) {
            return .noCorrection
        }

        if let confirmedTarget = adaptiveLexicon.confirmedTarget(for: word, currentInputSource: currentInputSource) {
            return DetectionResult(
                targetInputSource: confirmedTarget,
                confidence: 0.99,
                shouldCorrect: true
            )
        }

        let target: InputSource = currentInputSource == .english ? .russian : .english
        let converted = KeyboardLayoutConverter.convert(word, from: currentInputSource, to: target)
        guard converted != word else {
            return .noCorrection
        }

        guard word.count >= minimumLength || isKnownShortWord(converted, as: target) else {
            return .noCorrection
        }

        let confidence = score(converted, as: target)

        guard confidence >= correctionThreshold else {
            return .noCorrection
        }

        return DetectionResult(
            targetInputSource: target,
            confidence: confidence,
            shouldCorrect: true
        )
    }

    private func isStructurallyCandidate(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        if trimmed.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
            return false
        }

        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "`[];',./-"))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func isKnownShortWord(_ word: String, as source: InputSource) -> Bool {
        isKnownWord(word, as: source)
    }

    private func isKnownWord(_ word: String, as source: InputSource) -> Bool {
        let normalized = word.lowercased()
        switch source {
        case .russian:
            return commonRussianWords.contains(normalized)
                || professionalRussianWords.contains(normalized)
                || adaptiveLexicon.isKnown(normalized, as: .russian)
        case .english:
            return commonEnglishWords.contains(normalized)
                || professionalEnglishWords.contains(normalized)
                || adaptiveLexicon.isKnown(normalized, as: .english)
        }
    }

    private func score(_ word: String, as source: InputSource) -> Double {
        let normalized = word.lowercased()
        switch source {
        case .russian:
            if isKnownWord(normalized, as: .russian) {
                return 0.98
            }
            return russianHeuristicScore(normalized)
        case .english:
            if isKnownWord(normalized, as: .english) {
                return 0.98
            }
            return englishHeuristicScore(normalized)
        }
    }

    private func russianHeuristicScore(_ word: String) -> Double {
        let scalars = Array(word.unicodeScalars)
        guard scalars.allSatisfy({ CharacterSet(charactersIn: "абвгдеёжзийклмнопрстуфхцчшщъыьэюя-").contains($0) }) else {
            return 0
        }

        let vowels = "аеёиоуыэюяи"
        let vowelCount = word.filter { vowels.contains($0) }.count
        let hasCommonPair = [
            "пр", "ст", "но", "то", "ен", "ов", "ра", "ри", "на", "по", "ко", "го",
            "ре", "ли", "ла", "за", "ка", "та", "ет", "ел", "ль", "ни"
        ].contains { word.contains($0) }

        guard hasCommonPair, vowelCount > 0 else {
            return min(0.75, 0.35 + Double(vowelCount) / Double(max(word.count, 1)))
        }

        return min(0.95, 0.45 + Double(vowelCount) / Double(max(word.count, 1)) + (hasCommonPair ? 0.30 : 0))
    }

    private func englishHeuristicScore(_ word: String) -> Double {
        let scalars = Array(word.unicodeScalars)
        guard scalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz-").contains($0) }) else {
            return 0
        }

        let vowels = "aeiouy"
        let vowelCount = word.filter { vowels.contains($0) }.count
        let hasCommonPair = [
            "he", "th", "er", "in", "on", "ll", "or", "te", "st", "es", "ar", "al",
            "an", "en", "ed", "ou", "ng", "io", "le", "el", "re", "it", "is"
        ].contains { word.contains($0) }

        guard hasCommonPair, vowelCount > 0 else {
            return min(0.75, 0.35 + Double(vowelCount) / Double(max(word.count, 1)))
        }

        return min(0.95, 0.45 + Double(vowelCount) / Double(max(word.count, 1)) + (hasCommonPair ? 0.30 : 0))
    }
}
