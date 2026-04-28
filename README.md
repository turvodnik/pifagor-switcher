# Pifagor Switcher

Нативная macOS-утилита для локального RU/EN автопереключения раскладки и консервативного исправления последнего слова.

Разработчик: [Pifagor Apps](https://pifagor.studio).

## Возможности MVP

- RU/EN определение неправильной раскладки без облака и телеметрии.
- Исправление последнего слова до `Enter`.
- Исправление накопленной фразы по двойному `Control`, включая пробелы и пунктуацию.
- Локальное самообучение без отправки текста в облако.
- Исправление выделенного текста по двойному `Control` или двойному `Shift`.
- URL-правила для браузеров и режимы коррекции по приложениям.
- Исправление двойных заглавных вроде `WOrd -> Word` и `ПРивет -> Привет`.
- Исключения для Terminal, iTerm, Spotlight, secure input и пользовательских bundle id.
- Меню-бар приложение с настройками, паузой и undo последнего исправления.
- Глобальные хоткеи:
  - двойной `Control` — исправить предыдущую фразу целиком; если фразы нет, переключить RU/EN;
  - двойной `Shift` — исправить выделенный текст; если выделения нет, исправить предыдущую фразу;
  - `Control` + `Option` + `Space` — ручное переключение RU/EN;
  - `Control` + `Option` + `C` — исправить текущее слово без пробела;
  - `Control` + `Option` + `P` — пауза/включение;
  - `Control` + `Option` + `Z` — отмена последнего исправления.

## Правила и режимы

В настройках можно редактировать:

- URL-правила в формате `pattern = english` или `pattern = russian`.
- Режимы приложений в формате `bundle.id = normal`, `manualOnly` или `disabled`.
- Пользовательские слова, исключения и адаптивный словарь.

По умолчанию VS Code/Cursor работают в `manualOnly`, Terminal/iTerm в `disabled`, а Codex/Claude-чат остаются в `normal`, чтобы русско-английский набор в чате переключался автоматически.

Для Safari, Chrome, Brave, Arc и Edge URL читается локально через macOS Automation/AppleScript. Если macOS запросит доступ к браузеру, его нужно разрешить.

## Самообучение

Pifagor Switcher хранит адаптивный словарь локально в `Application Support/PifagorSwitcher/adaptive-lexicon.json`.

- Если ручное исправление одной пары повторяется два раза, пара считается надежной.
- Если исправление отменено через undo или сразу стерто Backspace, исходное слово попадает в исключения.
- Если слово несколько раз набрано без исправления, оно становится знакомым словом пользователя.
- Пользовательские профессиональные слова можно добавить в настройках.

В адаптивный словарь пишутся только отдельные слова и пары исправлений, не полные фразы.

## Сборка

```bash
swift build --product PifagorSwitcher
```

## Проверка ядра

```bash
swift run PifagorSwitcherCoreSpec
```

## Упаковка приложения

```bash
chmod +x scripts/package_app.sh
scripts/package_app.sh
```

Готовые артефакты появятся в `dist/`:

- `Pifagor Switcher.app`
- `PifagorSwitcher-0.1.0.zip`

Для реального распространения zip нужно подписать Developer ID сертификатом и notarize через Apple.

## Локальная установка для проверки разрешений

Для Accessibility/Input Monitoring лучше запускать приложение из `/Applications`, а не из `dist/`:

```bash
chmod +x scripts/install_dev_app.sh
scripts/install_dev_app.sh
open "/Applications/Pifagor Switcher.app"
```

Скрипт переустанавливает приложение, убирает quarantine/provenance xattr и подписывает bundle со стабильным designated requirement `identifier "app.pifagor.switcher"`. Это важно для TCC: без стабильного requirement macOS может показывать старый включенный пункт в Privacy Settings, но фактически возвращать `Accessibility: NO` и `Input Monitoring: NO` после каждой пересборки.

Если после смены подписи разрешения уже застряли в старом состоянии, один раз сбросьте TCC-записи и выдайте разрешения заново:

```bash
scripts/install_dev_app.sh --reset-permissions
```

## Разрешения macOS

Приложению нужны:

- Accessibility — для определения focused element и отправки исправления.
- Input Monitoring — для глобального чтения клавиатурных событий.

Настройки находятся в `System Settings -> Privacy & Security`.

Если приложение запустилось, но не реагирует на набор:

1. Откройте меню-бар пункт `П`.
2. Нажмите `Диагностика...` и проверьте строки `Input Monitoring`, `Accessibility` и `Keyboard event tap`.
3. Нажмите `Открыть Input Monitoring` и включите `Pifagor Switcher`.
4. Нажмите `Открыть Accessibility` и включите `Pifagor Switcher`.
5. Полностью перезапустите приложение.

Для локальной разработки приложение подписано ad-hoc со стабильным requirement, поэтому TCC-разрешения должны сохраняться между пересборками. `spctl` все равно может показывать `rejected`; для публичной установки нужен Developer ID certificate и notarization. Без этого macOS может блокировать запуск из Finder/zip.
