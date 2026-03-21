---
name: Development Tools & Config
description: analysis_options, Makefile, VS Code tasks/launch/profiles, dart-define-from-file, environments
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# Development Tools & Config / Инструменты разработки

## analysis_options.yaml

Настройка анализатора Dart -- обязательная часть проекта:

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true       # Явное указание женериков
    strict-raw-types: true    # Строгий режим типов
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    # Какие правила считать ошибками/предупреждениями
    missing_return: error
    dead_code: warning

linter:
  rules:
    # Подключение/отключение правил
    prefer_const_constructors: true
    avoid_print: true
    # Отключение правил:
    # prefer_relative_imports: false
```

### Strict mode

> "Я предпочитаю писать в строгом режиме -- указывать явно женерики, указывать все типы."

Strict mode позволяет:
- Явно указывать типы везде
- Компилятор проверяет больше ошибок
- Код более читаемый

### Ширина строки (форматер)

В analysis_options можно указать ширину строки для форматера:

```yaml
formatter:
  page_width: 120  # или 80, или 100
```

## Makefile

> "Makefile -- потому что у всех есть Make."

```makefile
.PHONY: run run-dev run-fake run-web build-web build-android \
        analyze test gen-l10n clean

# Запуск
run-dev:
	flutter run --dart-define-from-file=environments/development.env

run-fake:
	flutter run --dart-define-from-file=environments/fake.env

run-staging:
	flutter run --dart-define-from-file=environments/staging.env

run-web:
	flutter run -d web-server --dart-define-from-file=environments/development.env

# Сборка
build-web:
	flutter build web --dart-define-from-file=environments/production.env

build-android:
	flutter build apk --dart-define-from-file=environments/production.env \
		--build-number=$$(date +%s)

build-ios:
	flutter build ios --dart-define-from-file=environments/production.env \
		--build-number=$$(date +%s)

# Инструменты
analyze:
	flutter analyze

test:
	flutter test

gen-l10n:
	flutter gen-l10n

clean:
	flutter clean && flutter pub get

# Конвертация ассетов в WebP
convert-assets:
	magick mogrify -format webp assets/**/*.png
```

## VS Code Configuration

### launch.json -- конфигурации запуска

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Development",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--dart-define-from-file=environments/development.env"
      ]
    },
    {
      "name": "Fake (no backend)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--dart-define-from-file=environments/fake.env"
      ]
    },
    {
      "name": "Staging",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--dart-define-from-file=environments/staging.env"
      ]
    },
    {
      "name": "UI Kit Example",
      "request": "launch",
      "type": "dart",
      "program": "packages/ui/example/lib/main.dart",
      "cwd": "packages/ui/example"
    },
    {
      "name": "Web (web-server)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--dart-define-from-file=environments/development.env",
        "-d", "web-server"
      ]
    }
  ]
}
```

### tasks.json -- задачи

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Flutter Analyze",
      "type": "shell",
      "command": "flutter analyze",
      "problemMatcher": "$dart-analyze"
    },
    {
      "label": "Flutter Test",
      "type": "shell",
      "command": "flutter test"
    },
    {
      "label": "Gen Localization",
      "type": "shell",
      "command": "flutter gen-l10n"
    },
    {
      "label": "Build Web (Production)",
      "type": "shell",
      "command": "flutter build web --dart-define-from-file=environments/production.env"
    }
  ]
}
```

### VS Code Profiles

> "Можно использовать разные профили. В зависимости от того, на каком языке пишете, можете использовать разные расширения, разные настройки."

Создайте отдельные профили:
- **Flutter** -- Dart/Flutter расширения, настройки
- **Go** -- Go расширения
- **Python** -- Python расширения

Чтобы расширения не маячили, если вы пишете в основном на Flutter.

## dart-define-from-file / Environments

### Структура окружений

```
environments/
  development.env    # В git -- для разработки
  testing.env        # В git -- для тестов
  staging.env        # В git -- для staging
  production.env     # В .gitignore -- продакшн секреты
  fake.env           # В git -- фейковые данные без бэкенда
```

### Содержимое env-файла

```env
ENVIRONMENT=development
BASE_URL=https://api.dev.doctorina.com
SENTRY_DSN=https://...@sentry.io/...
POSTHOG_KEY=phc_...
ANALYTICS_ENABLED=true
FEATURE_PAYMENTS=false
```

### Использование в коде

```dart
const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
const baseUrl = String.fromEnvironment('BASE_URL');
const sentryDsn = String.fromEnvironment('SENTRY_DSN');

// Проверка окружения:
if (environment == 'fake') {
  // Фейковые репозитории
}
if (environment == 'production') {
  // Инициализация Sentry
}
```

### Web-server для отладки

```bash
# Вместо нового пустого Chrome:
flutter run -d web-server

# Открываете в текущем браузере с расширениями,
# кэшем, авторизацией
```

> "Это гораздо удобнее -- можете дебажить не в чистом Chrome, который каждый раз запускается, а в текущем браузере с расширениями."

## Отладочная информация

### Debug Banner / Overlay

Отладочная информация отображается через Overlay в MaterialApp.builder (только в development):

```dart
// В MaterialApp.builder:
if (kDebugMode || environment == 'staging') {
  // Overlay с информацией:
  // - Текущее окружение (staging/dev)
  // - API endpoint
  // - Версия приложения
  // - Другая полезная информация
}
```

### Логирование переходов стейтов

Через BlocObserver все переходы стейтов логируются:

```
AuthBloc: AuthState$Idle(initial) -> AuthState$Processing(logging in with Google)
AuthBloc: AuthState$Processing -> AuthState$Idle(authenticated)
ChatListBloc: ChatListState$Idle(initial) -> ChatListState$Processing(refreshing chats)
ChatListBloc: ChatListState$Processing -> ChatListState$Idle(5 chats received)
```

## Расширения VS Code

Конкретный список расширений -- дело вкуса. Основные рекомендации:
- Dart/Flutter официальные расширения
- Расширения для конкретных потребностей проекта
- Используйте Profiles, чтобы разные языки не мешали

## Key Takeaways / Ключевые выводы

1. **analysis_options.yaml** -- strict mode, явные типы, правила анализатора
2. **Makefile** -- стандартизация команд (работает у всех)
3. **dart-define-from-file** -- разные окружения (dev, staging, fake, production)
4. **launch.json** -- отдельные конфигурации для каждого окружения и UI Kit
5. **VS Code Profiles** -- разные расширения для разных языков
6. **web-server** device ID -- отладка в текущем браузере
7. **fake** окружение -- разработка без бэкенда
8. Production env в `.gitignore`, остальные в git
