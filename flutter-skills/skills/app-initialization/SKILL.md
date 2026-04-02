---
name: app-initialization
description: Use when setting up Flutter app entry point (main.dart), configuring app initialization with progress, deferFirstFrame, environments (dart-define-from-file), or RunZoneGuarded. MUST use for any app startup, splash screen, or environment configuration questions.
---

# App Initialization / Инициализация приложения

## Main Entry Point / Точка входа

Реализуй инициализацию поэтапно, с прогрессом. Основная идея: инициализация происходит через хэш-таблицу шагов, которые выполняются последовательно.

```dart
void main() {
  // 1. Инициализация Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Получение начального deep link (до навигатора)
  final initialRoute = PlatformDispatcher.instance.defaultRouteName;

  // 3. Задержка первого кадра
  WidgetsBinding.instance.deferFirstFrame();

  // 4. Инициализация зависимостей (поэтапная)
  // ...

  // 5. runApp с инъекцией зависимостей
  runApp(
    InheritedDependencies(
      dependencies: dependencies,
      child: Application(),
    ),
  );
}
```

## deferFirstFrame -- Задержка первого кадра

Задерживай первый кадр через `deferFirstFrame()`, пока приложение не будет полностью инициализировано. Это предотвращает мигания и отображение пустого экрана.

```dart
// В начале main:
WidgetsBinding.instance.deferFirstFrame();

// После полной инициализации и первого билда:
WidgetsBinding.instance.allowFirstFrame();
```

Порядок:
1. `deferFirstFrame()` -- задерживай
2. `runApp(...)` -- запускай, но ничего не отображается
3. `postFrameCallback` -- когда первый кадр готов
4. `allowFirstFrame()` -- разрешай отобразить
5. Удаляй loading widget (прогресс-бар из HTML для веба)

> "Приложение отображается на экране без всяких морганий, без ничего."

## Dependencies — см. 03_dependency_injection.md

Создавай класс Dependencies с `late final` полями в main. Подробная документация — в `03_dependency_injection.md`.

## Поэтапная инициализация

Реализуй инициализацию как хэш-таблицу шагов с прогрессом:

```dart
// Каждый шаг инициализации:
final steps = <String, Future<void> Function(Dependencies)>{
  'SharedPreferences': (deps) async {
    deps.sharedPreferences = await SharedPreferences.getInstance();
  },
  'Database': (deps) async {
    deps.database = await Database.initialize();
  },
  'HTTP Client': (deps) async {
    deps.apiClient = createApiClient(deps);
  },
  'Repositories': (deps) async {
    deps.chatRepository = ChatRepositoryImpl(deps.apiClient, deps.database);
    // ...
  },
  // ...
};

// Обход шагов с логированием прогресса:
for (final entry in steps.entries) {
  log('Initializing: ${entry.key}');
  await entry.value(dependencies);
  updateProgress(entry.key);
}
```

Если где-то произошла ошибка -- отображай экран ошибки инициализации.

## Веб-специфика

### CanvasKit vs HTML Renderer

Для веба указывай renderer. Основное приложение собирай под все платформы.

### Service Worker, Native Splash

Loading widget (прогресс-бар) реализуй в HTML и удаляй после инициализации Flutter:

```dart
// После инициализации:
// Удаляй loading widget из HTML
// Он продолжает жить поверх Canvas, поэтому нужно явно удалить
```

### Web Server для отладки

```bash
# Запуск веб-сервера вместо нового Chrome:
flutter run -d web-server
```

Это удобнее, потому что:
- Можно дебажить в текущем браузере с расширениями
- Кэш не сбрасывается
- Пользователь не разлогинивается

## Environments / Окружения

### dart-define-from-file

В корне фронтенда создавай папку с конфигурациями окружений:

```
environments/
  development.env    # В git
  testing.env        # В git
  staging.env        # В git
  production.env     # В .gitignore
```

Содержимое:
```env
ENVIRONMENT=development
SENTRY_URL=https://...
BASE_URL=https://api.dev.example.com
ANALYTICS_KEY=...
POSTHOG_KEY=...
```

### Фейковое окружение

Если передан `ENVIRONMENT=fake`, используй фейковые реализации репозиториев:

```dart
if (environment == 'fake') {
  deps.chatRepository = FakeChatRepository();
  // Автоматический логин через фейковый Google-аккаунт
} else {
  deps.chatRepository = ChatRepositoryImpl(deps.apiClient, deps.database);
}
```

Полезно когда:
- Бэкенд-ручка ещё не готова
- Нужно отлаживать отображение (markdown, диалоги)
- Интеграционные тесты

## RunZoneGuarded в инициализации

Оборачивай всё приложение в `runZonedGuarded` для перехвата необработанных ошибок:

```dart
runZonedGuarded(
  () {
    runApp(MyApp());
  },
  (error, stackTrace) {
    // Логирование, Sentry
    log('Unhandled error: $error');
  },
);
```

## Key Takeaways / Ключевые выводы

1. Реализуй инициализацию поэтапно, с прогрессом и обработкой ошибок
2. `deferFirstFrame()` предотвращает мигания при запуске
3. Dependencies — см. `03_dependency_injection.md`
4. Фейковые реализации -- must have для разработки
5. `dart-define-from-file` для разных окружений
6. Deep link получай **до** навигатора в main()
7. Loading widget из HTML нужно явно удалять после инициализации
