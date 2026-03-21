---
name: cicd-devtools
description: Use when setting up CI/CD (GitHub Actions, sparse checkout, caching, Firebase Preview Channel), configuring dev tools (analysis_options, Makefile, VS Code tasks/launch), managing environments (dart-define-from-file), or versioning with Unix timestamp. MUST use for any CI/CD, build configuration, environment setup, or IDE configuration in Flutter.
---

# CI/CD & Development Tools

## analysis_options.yaml

Настрой анализатор Dart в `analysis_options.yaml`:

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
    missing_return: error
    dead_code: warning

linter:
  rules:
    prefer_const_constructors: true
    avoid_print: true
```

### Strict mode

Используй строгий режим — указывай явно женерики и все типы:
- Явно указывай типы везде
- Компилятор проверяет больше ошибок
- Код более читаемый

### Ширина строки (форматер)

Указывай ширину строки для форматера в analysis_options:

```yaml
formatter:
  page_width: 120  # или 80, или 100
```

## Environments / Окружения

### dart-define-from-file

Создай папку `environments/` с конфигурациями окружений:

```
environments/
  development.env    # В git — для разработки
  testing.env        # В git — для тестов
  staging.env        # В git — для staging
  production.env     # В .gitignore — продакшн секреты
  fake.env           # В git — фейковые данные без бэкенда
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

## Makefile

Используй Makefile для стандартизации команд — Make есть у всех:

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

run-prod:
	flutter run --dart-define-from-file=environments/production.env

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

### launch.json — конфигурации запуска

Создай отдельные конфигурации для каждого окружения:

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

### tasks.json — задачи

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

Используй разные профили для разных языков:
- **Flutter** — Dart/Flutter расширения, настройки
- **Go** — Go расширения
- **Python** — Python расширения

Чтобы расширения не мешали, если пишешь в основном на Flutter.

### Расширения VS Code

Устанавливай:
- Dart/Flutter официальные расширения
- Расширения для конкретных потребностей проекта
- Используй Profiles, чтобы разные языки не мешали

## GitHub Actions

### Reusable Actions

Создавай собственные reusable actions для стандартных задач (сборка, тесты, деплой).

### Sparse Checkout

В монорепозитории клонируй только нужную папку (frontend), а не всё репо:

```yaml
# .github/workflows/build.yml
steps:
  - uses: actions/checkout@v4
    with:
      sparse-checkout: |
        frontend
      sparse-checkout-cone-mode: false
```

Это экономит время и трафик, особенно в больших монорепозиториях.

### Caching / Кэширование

Кэшируй зависимости Flutter/Dart для ускорения сборки:

```yaml
steps:
  - uses: actions/cache@v4
    with:
      path: |
        ~/.pub-cache
        .dart_tool
      key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
      restore-keys: |
        ${{ runner.os }}-pub-
```

### Build Workflows

Настрой отдельные воркфлоу для:
- **Web** — сборка и деплой на Firebase Hosting
- **Android** — сборка APK/AAB
- **iOS** — сборка через Xcode

## Firebase Preview Channel

Используй временные URL для тестирования веб-версии:

```yaml
# Деплой в preview channel:
- uses: FirebaseExtended/action-hosting-deploy@v0
  with:
    repoToken: ${{ secrets.GITHUB_TOKEN }}
    firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
    channelId: pr-${{ github.event.pull_request.number }}
    expires: 7d  # Живёт 7 дней
```

Preview Channel — временный URL, который живёт несколько дней. Удобно для:
- QA-тестирования конкретной ветки
- Бэкендеры могут тестировать с актуальным фронтом
- Демонстрация клиенту

## Docker для бэкендеров

Предоставь Dockerfile для сборки веб-версии, чтобы бэкендеры могли запустить фронт локально:

```dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
```

## Versioning / Версионирование

### Build Number как Unix Timestamp

Используй Unix timestamp в секундах вместо инкрементального номера:

```yaml
# В CI:
flutter build apk --build-number=$(date +%s)
```

Преимущества:
- Всегда уникальный номер
- Всегда возрастающий (требование App Store / Play Store)
- Не нужно хранить и инкрементировать счётчик
- По номеру видно время сборки
- Не конфликтует при параллельных сборках

### Версия приложения

```yaml
# pubspec.yaml
version: 1.2.3+1234567890  # semantic version + unix timestamp
```

Семантическая версия (`1.2.3`) — для пользователей.
Build number (unix timestamp) — для сторов и внутреннего отслеживания.

## Отладка

### Web-server для отладки

Запускай через web-server вместо нового пустого Chrome:

```bash
flutter run -d web-server
# Открывай в текущем браузере с расширениями, кэшем, авторизацией
```

### Local Storage override для base URL (Web)

Для бэкендеров: если в localStorage указан `base_url`, приложение использует его вместо захардкоженного:

```dart
// При инициализации (только на staging):
if (kIsWeb && environment != 'production') {
  final overrideUrl = window.localStorage['base_url'];
  if (overrideUrl != null) {
    baseUrl = overrideUrl;
  }
}
```

Бэкендер может:
1. Открыть staging
2. В DevTools -> Application -> Local Storage указать свой URL
3. Перезагрузить — фронт направлен на его локальный бэкенд

### Debug Banner / Overlay

Отображай отладочную информацию через Overlay в MaterialApp.builder (только в development):

```dart
// В MaterialApp.builder:
if (kDebugMode || environment == 'staging') {
  // Overlay с информацией:
  // - Текущее окружение (staging/dev)
  // - API endpoint
  // - Версия приложения
}
```

### Логирование переходов стейтов

Через BlocObserver логируй все переходы стейтов:

```
AuthBloc: AuthState$Idle(initial) -> AuthState$Processing(logging in with Google)
AuthBloc: AuthState$Processing -> AuthState$Idle(authenticated)
ChatListBloc: ChatListState$Idle(initial) -> ChatListState$Processing(refreshing chats)
ChatListBloc: ChatListState$Processing -> ChatListState$Idle(5 chats received)
```

## Key Takeaways

1. **analysis_options.yaml** — strict mode, явные типы, правила анализатора
2. **dart-define-from-file** — разные окружения (dev, staging, fake, production)
3. **Makefile** — стандартизация команд (работает у всех)
4. **launch.json** — отдельные конфигурации для каждого окружения и UI Kit
5. **VS Code Profiles** — разные расширения для разных языков
6. **Sparse checkout** для монорепозиториев — клонируй только нужное
7. **Unix timestamp** как build number — всегда уникальный и возрастающий
8. **Firebase Preview Channel** — временные URL для тестирования
9. **web-server** device ID — отладка в текущем браузере
10. **fake** окружение — разработка без бэкенда
11. Production env в `.gitignore`, остальные в git
12. Local Storage override для base URL (staging)
13. Docker для бэкендеров — запуск фронта локально
