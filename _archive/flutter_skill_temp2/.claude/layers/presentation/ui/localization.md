# Локализация в проекте

## 🎯 Цель документа

Система локализации на основе Flutter i18n с ARB файлами и автогенерацией классов.

---

## 📐 Архитектура

```
core/translations/
├── l10n.yaml                    # Конфигурация
├── pubspec.yaml                 # flutter: generate: true
└── lib/
    ├── l10n/
    │   ├── app_ru.arb          # 🇷🇺 Шаблон (template)
    │   └── app_en.arb          # 🇬🇧 Английский
    └── app_localizations*.dart  # ⚙️ Автогенерируемые классы
```

**Конфигурация (l10n.yaml):**

```yaml
arb-dir: lib/l10n
template-arb-file: app_ru.arb # Русский как основной
output-dir: lib
output-localization-file: app_localizations.dart
synthetic-package: false
```

---

## 📝 ARB формат (Application Resource Bundle)

### Базовая структура

```json
{
  "key_name": "Значение перевода",
  "@key_name": {
    "description": "Опциональное описание"
  }
}
```

### Примеры

**Простой текст:**

```json
{
  "welcome": "Добро пожаловать",
  "email": "Email",
  "password": "Пароль"
}
```

**Многострочный текст:**

```json
{
  "description": "Первая строка\nВторая строка\nТретья строка"
}
```

**С описанием:**

```json
{
  "login": "Войти",
  "@login": {
    "description": "Button text for login action"
  }
}
```

---

## ⚙️ Генерация классов

### Автоматическая генерация

**Правило:** Используй `make get` для генерации переводов

**Команда:**

```bash
make get
```

**Что происходит:**

1. `flutter pub get` загружает зависимости
2. `flutter gen-l10n` автоматически генерирует классы локализации
3. Создаются файлы `app_localizations*.dart`

---

### Сгенерированный API

```dart
// ⚙️ Автогенерируемый класс
abstract class AppLocalizations {
  // Delegates для MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate = ...;

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  // Поддерживаемые локали
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ru'),
  ];

  // Геттеры для переводов
  String get welcome;
  String get email;
  String get password;
  // ... остальные ключи
}
```

---

## 🔌 Интеграция в приложение

### 1. MaterialApp настройка

```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: settings.locale,  // Динамическая смена локали
  // ...
)
```

### 2. Extension для доступа

```dart
// core/ui_library/lib/src/extensions/context_extension.dart
extension BuildContextExt on BuildContext {
  AppLocalizations get localizations => AppLocalizations.of(this)!;
}
```

### 3. Использование в UI

```dart
// Короткий синтаксис через extension
Text(context.localizations.welcome)

TextFieldDefaultWidget(
  hintText: context.localizations.email,
)

ElevatedButton(
  onPressed: onLogin,
  child: Text(context.localizations.login),
)
```

---

## ✅ Workflow: Добавление нового перевода

### Шаги

1. **Добавь ключ в шаблон** (`app_ru.arb`):

```json
{
  "new_feature_title": "Заголовок новой фичи",
  "@new_feature_title": {
    "description": "Title for new feature screen"
  }
}
```

2. **Добавь перевод** (`app_en.arb`):

```json
{
  "new_feature_title": "New Feature Title"
}
```

3. **Генерируй классы**:

```bash
make get
```

4. **Используй в коде**:

```dart
Text(context.localizations.new_feature_title)
```

---

## 📋 Naming Convention

| Префикс           | Применение         | Пример                           |
| ----------------- | ------------------ | -------------------------------- |
| `error_auth_*`    | Ошибки авторизации | `error_auth_invalid_credentials` |
| `error_network_*` | Сетевые ошибки     | `error_network_connection`       |
| `http_error_*`    | HTTP ошибки        | `http_error_404_message`         |
| `button_*`        | Кнопки             | `button_save`, `button_cancel`   |
| `screen_*`        | Экраны             | `screen_profile_title`           |
| `validation_*`    | Валидация          | `validation_email_required`      |

**Правило:** Используй `snake_case` для ключей

---

## 🎨 Специальные символы

| Символ | Использование         | Пример                 |
| ------ | --------------------- | ---------------------- |
| `\n`   | Перенос строки        | `"Line 1\nLine 2"`     |
| `•`    | Bullet point          | `"• Item 1\n• Item 2"` |
| `"`    | Кавычки внутри строки | `"\"Quoted text\""`    |

**Пример:**

```json
{
  "features_list": "Возможности:\n• Первое\n• Второе\n• Третье"
}
```

---

## 🔧 Расширенные возможности

### Параметризация (будущее расширение)

```json
{
  "welcome_user": "Добро пожаловать, {name}!",
  "@welcome_user": {
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  }
}
```

**Использование:**

```dart
context.localizations.welcome_user(name: 'Иван')
```

---

### Pluralization (будущее расширение)

```json
{
  "days_count": "{count, plural, =1{день} few{дня} other{дней}}",
  "@days_count": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

---

## ✅ Best Practices

| Практика        | ✅ Хорошо                       | ❌ Плохо                            |
| --------------- | ------------------------------- | ----------------------------------- |
| **Ключи**       | `snake_case`                    | `camelCase`, `PascalCase`           |
| **Группировка** | `feature_screen_title`          | `title1`, `title2`                  |
| **Описания**    | Добавлять для сложных ключей    | Пропускать описания                 |
| **Генерация**   | После изменения ARB: `make get` | Ручное редактирование классов       |
| **Доступ**      | `context.localizations.key`     | `AppLocalizations.of(context)!.key` |

---

## 🐛 Troubleshooting

### Проблема: Не видно новых переводов

**Решение:**

```bash
# 1. Убедись, что ARB файлы сохранены
# 2. Запусти генерацию
make get

# 3. Перезапусти hot restart (не hot reload)
```

---

### Проблема: Ошибка "key not found"

**Причина:** Ключ есть в `app_ru.arb`, но отсутствует в `app_en.arb`

**Решение:**

```json
// Добавь во все ARB файлы
{
  "missing_key": "Translation RU", // app_ru.arb
  "missing_key": "Translation EN" // app_en.arb
}
```

---

### Проблема: IDE не показывает autocomplete

**Решение:**

```bash
# 1. Генерируй классы
make get

# 2. Перезапусти IDE
# VS Code: Developer: Reload Window
# Android Studio: File → Invalidate Caches → Restart
```

---

## 📋 Чеклист добавления перевода

```
1. Добавь ключ в app_ru.arb (шаблон)
2. Добавь перевод в app_en.arb
3. Добавь описание @key (опционально)
4. Запусти: make get
5. Используй: context.localizations.key
6. Тестируй на обеих локалях
```

---

## 📦 Структура зависимостей

**core/translations/pubspec.yaml:**

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2

flutter:
  generate: true # ✅ Включает автогенерацию
```

**Makefile (существующая команда):**

```makefile
get:
	@echo "Getting Flutter dependencies..."
	fvm flutter pub get
```

---

## 🔗 См. также

- [Flutter i18n documentation](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [ARB format specification](https://github.com/google/app-resource-bundle)
- [UI Components](./components.md) - использование переводов в компонентах
