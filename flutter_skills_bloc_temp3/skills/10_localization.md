---
name: Localization
description: Локализация per-feature ARB файлами, Sheet Localization пакет, Google Sheets как источник
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# Localization / Локализация

## Anti-pattern: один огромный ARB файл

> "Очень многие люди делают один огромный ARB файл, хреначат просто всё что есть. Получается мешанина. Вы начинаете придумывать штуки типа screen_payment_confirm_label_button."

Проблемы единого ARB:
- Огромный файл с сотнями строк
- Теряетесь, где какая локализация
- Длинные имена переменных с префиксами экранов
- Неудобно работать нескольким людям

## Per-Feature ARB Files / Отдельные ARB файлы по фичам

> "Это первый проект, где я пробую именно таким образом. Каких-то минусов не заметил."

Подход: несколько локализаций, каждая для своей фичи:

```
l10n/
  auth/
    auth_en.arb
    auth_ru.arb
  settings/
    settings_en.arb
    settings_ru.arb
  chat/
    chat_en.arb
    chat_ru.arb
  common/
    common_en.arb
    common_ru.arb
```

Из ARB генерируется Dart-код для каждой фичи отдельно. В MaterialApp подключаются **все** делегаты:

```dart
MaterialApp(
  localizationsDelegates: [
    AuthLocalizations.delegate,
    SettingsLocalizations.delegate,
    ChatLocalizations.delegate,
    CommonLocalizations.delegate,
    // Стандартные делегаты Flutter
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: [
    Locale('en'),
    Locale('ru'),
    // ...
  ],
);
```

### Использование на экране

```dart
// На экране настроек -- работаете только с SettingsLocalizations:
Text(SettingsLocalizations.of(context).languageLabel)

// На экране чата -- только с ChatLocalizations:
Text(ChatLocalizations.of(context).sendMessage)
```

> "Если я сижу на экране настроек, мне интересны только settings. Всё."

## Sheet Localization -- Google Sheets как источник

Пакет: `sheet_localization` (лежит в организации Doctorina AI на GitHub).

### Workflow

```
Google Sheets -> sheet_localization -> .arb файлы -> gen-l10n -> Dart код
```

1. **Создаёте Google Sheet** с несколькими вкладками (по фичам)
2. **Запускаете sheet_localization** -- извлекает данные, генерирует ARB
3. **Flutter gen-l10n** -- из ARB генерирует Dart-код

### Структура Google Sheet

Каждая вкладка (tab) -- отдельная фича:

| Key | en | ru | uk |
|-----|----|----|-----|
| send_message | Send | Отправить | Надiслати |
| cancel | Cancel | Отмена | Скасувати |

### Преимущества Google Sheets

1. **Google Translate бесплатно** -- можно использовать формулы для автоперевода
2. **Gemini AI** -- для более качественных переводов
3. **Условное форматирование** -- подсветка незаполненных ячеек
4. **Примечания** -- для контекста переводов
5. **Не-программисты могут переводить** -- им не нужен Git, PRs, ARB-файлы

> "Зачастую люди, которые локализуют -- не программисты. Они не будут клонить ветку, делать pull request'ы, менять JSON-файлы. Это жутко муторно и неудобно абсолютно всем."

### Установка и использование

```yaml
# Глобально установленный пакет (не в pubspec.yaml проекта)
# dart pub global activate sheet_localization
```

```bash
# Генерация ARB из Google Sheets:
sheet_localization generate \
  --spreadsheet-id=YOUR_SPREADSHEET_ID \
  --output=lib/l10n/
```

## Key Takeaways / Ключевые выводы

1. **Per-feature ARB** файлы вместо одного огромного
2. **Google Sheets** как источник для переводов (удобно для команды)
3. **sheet_localization** пакет -- генерация ARB из Google Sheets
4. Переводчики работают в Google Sheets, не в коде
5. Google Translate / Gemini AI бесплатно прямо в таблицах
6. Каждый экран использует только свою локализацию
