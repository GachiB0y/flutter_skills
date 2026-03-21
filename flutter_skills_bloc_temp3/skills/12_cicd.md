---
name: CI/CD
description: GitHub Actions, reusable actions, sparse checkout, caching, build workflows, versioning с Unix timestamp
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# CI/CD

## GitHub Actions

### Reusable Actions / Переиспользуемые actions

Создание собственных reusable actions для стандартных задач (сборка, тесты, деплой).

### Sparse Checkout

В монорепозитории -- клонирование только нужной папки (frontend), а не всего репо:

```yaml
# .github/workflows/build.yml
steps:
  - uses: actions/checkout@v4
    with:
      sparse-checkout: |
        frontend
      sparse-checkout-cone-mode: false
```

Экономит время и трафик, особенно в больших монорепозиториях.

### Caching / Кэширование

Кэширование зависимостей Flutter/Dart для ускорения сборки:

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

### Build Workflows / Воркфлоу сборки

Отдельные воркфлоу для:
- **Web** -- сборка и деплой на Firebase Hosting
- **Android** -- сборка APK/AAB
- **iOS** -- сборка через Xcode

### Firebase Preview Channel

Временные URL для тестирования веб-версии:

```yaml
# Деплой в preview channel:
- uses: FirebaseExtended/action-hosting-deploy@v0
  with:
    repoToken: ${{ secrets.GITHUB_TOKEN }}
    firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
    channelId: pr-${{ github.event.pull_request.number }}
    expires: 7d  # Живёт 7 дней
```

> "Preview Channel -- временный URL, который несколько дней будет жить. Просто потестить, потыкать, и потом оно умрёт."

Удобно для:
- QA-тестирования конкретной ветки
- Бэкендеры могут тестировать с актуальным фронтом
- Демонстрация клиенту

### Docker для бэкендеров

Dockerfile для сборки веб-версии, чтобы бэкендеры могли запустить фронт локально:

```dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
```

Бэкендер может в любой момент собрать и запустить веб-версию у себя для тестирования API.

## Versioning / Версионирование

### Build Number как Unix Timestamp

```yaml
# Вместо инкрементального номера (1, 2, 3, ...):
# Используем Unix timestamp в секундах

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

Семантическая версия (`1.2.3`) -- для пользователей.
Build number (unix timestamp) -- для сторов и внутреннего отслеживания.

## Makefile / Команды сборки

Makefile используется для стандартизации команд:

```makefile
.PHONY: run-dev run-prod build-web build-android

run-dev:
	flutter run --dart-define-from-file=environments/development.env

run-prod:
	flutter run --dart-define-from-file=environments/production.env

run-fake:
	flutter run --dart-define-from-file=environments/fake.env

build-web:
	flutter build web --dart-define-from-file=environments/production.env

build-android:
	flutter build apk --dart-define-from-file=environments/production.env \
		--build-number=$(shell date +%s)

gen-l10n:
	flutter gen-l10n

analyze:
	flutter analyze

test:
	flutter test
```

> "Makefile -- потому что у всех есть Make. Если человек предпочитает Android Studio, у него Make тоже есть."

## VS Code Configuration

### Tasks (tasks.json)

```json
{
  "tasks": [
    {
      "label": "Run Dev",
      "type": "shell",
      "command": "flutter run --dart-define-from-file=environments/development.env"
    },
    {
      "label": "Run Fake",
      "type": "shell",
      "command": "flutter run --dart-define-from-file=environments/fake.env"
    }
  ]
}
```

### Launch Configurations (launch.json)

Отдельные конфигурации запуска для разных окружений:

```json
{
  "configurations": [
    {
      "name": "Development",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define-from-file=environments/development.env"]
    },
    {
      "name": "Fake (no backend)",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define-from-file=environments/fake.env"]
    },
    {
      "name": "UI Kit Example",
      "request": "launch",
      "type": "dart",
      "cwd": "packages/ui/example"
    }
  ]
}
```

### Profiles

VS Code позволяет использовать разные профили с разными расширениями для разных языков (Flutter, Go, Python).

## Отладка через Local Storage (Web)

Хитрость для бэкендеров: если в localStorage указан `base_url`, приложение использует его вместо захардкоженного:

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
3. Перезагрузить -- фронт направлен на его локальный бэкенд

## Key Takeaways / Ключевые выводы

1. **Sparse checkout** для монорепозиториев -- клонировать только нужное
2. **Unix timestamp** как build number -- всегда уникальный и возрастающий
3. **Firebase Preview Channel** -- временные URL для тестирования
4. **Makefile** для стандартизации команд
5. **dart-define-from-file** для разных окружений
6. Отдельные launch configurations для каждого окружения
7. Local Storage override для base URL (staging)
8. Docker для бэкендеров -- запуск фронта локально
