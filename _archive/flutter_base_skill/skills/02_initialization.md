---
name: App Initialization
description: Инициализация Flutter-приложения, main.dart, conditional/deferred imports, Zone, RunZoneGuarded, deferFirstFrame, Dependencies class, веб-специфика
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# App Initialization / Инициализация приложения

## Main Entry Point / Точка входа

Структура инициализации -- поэтапная, с прогрессом. Основная идея: инициализация происходит через хэш-таблицу шагов, которые выполняются последовательно.

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

Ключевая техника: задержать первый кадр, пока приложение не будет полностью инициализировано. Это предотвращает мигания и отображение пустого экрана.

```dart
// В начале main:
WidgetsBinding.instance.deferFirstFrame();

// После полной инициализации и первого билда:
WidgetsBinding.instance.allowFirstFrame();
```

Порядок:
1. `deferFirstFrame()` -- задерживаем
2. `runApp(...)` -- запускаем, но ничего не отображается
3. `postFrameCallback` -- когда первый кадр готов
4. `allowFirstFrame()` -- разрешаем отобразить
5. Удаляем loading widget (прогресс-бар из HTML для веба)

> "Приложение отображается на экране без всяких морганий, без ничего."

## Dependencies Class / Класс зависимостей

Все зависимости создаются в одном классе с `late final` полями:

```dart
class Dependencies {
  // Репозитории
  late final SharedPreferences sharedPreferences;
  late final Database database;
  late final ApiClient apiClient;

  // HTTP Factory -- для создания отдельных клиентов
  late final ApiClient Function() httpFactory;

  // Репозитории
  late final ChatRepository chatRepository;
  late final AuthRepository authRepository;
  late final VersionRepository versionRepository;
  late final SettingsRepository settingsRepository;

  // Метаинформация
  late final AppMetadata metadata;

  // Контроллеры (только основные, большинство в скоупах)
  late final NavigationController navigationController;
  late final AuthController authController;
}
```

### Преимущества late final

- Поэтапная инициализация: изначально неинициализированный объект, потом проходишь все шаги
- В тестах инициализируешь **только то, что нужно** -- к остальному не обращаешься, ошибки не будет
- Никаких дженериков, никаких кастов

```dart
// Использование в любом месте:
final repo = Dependencies.of(context).chatRepository;
// Автодополнение сразу показывает все доступные зависимости
```

### Anti-pattern: GetIt, Riverpod, Provider для DI

> "Никаких GetIt'ов, никаких Riverpod'ов. Делаете класс, у него куча late'ов -- вот он ваш мульти-провайдер. Не надо никакие пакеты, дженерики. Всё сразу готово -- вот ваш объект, бери, используй."

## Поэтапная инициализация

Инициализация реализована как хэш-таблица шагов с прогрессом:

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

Если где-то произошла ошибка -- отображается экран ошибки инициализации.

## Веб-специфика

### CanvasKit vs HTML Renderer

Для веба можно указывать renderer. Основное приложение собирается под все платформы.

### Service Worker, Native Splash

Loading widget (прогресс-бар) реализован в HTML и удаляется после инициализации Flutter:

```dart
// После инициализации:
// Удаляем loading widget из HTML
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

В корне фронтенда -- папка с конфигурациями окружений:

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

Если передан `ENVIRONMENT=fake`, используются фейковые реализации репозиториев:

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

Всё приложение оборачивается в `runZonedGuarded` для перехвата необработанных ошибок:

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

## Injection через InheritedWidget

```dart
runApp(
  InheritedDependencies(  // InheritedWidget
    dependencies: dependencies,
    child: Application(),
  ),
);

// Использование:
Dependencies.of(context).chatRepository
```

При необходимости можно переопределить зависимости для отдельных частей дерева (тесты, отдельные экраны).

## Key Takeaways / Ключевые выводы

1. Инициализация -- поэтапная, с прогрессом и обработкой ошибок
2. `deferFirstFrame()` предотвращает мигания при запуске
3. Dependencies -- класс с `late final` полями, не GetIt/Provider
4. Фейковые реализации -- must have для разработки
5. `dart-define-from-file` для разных окружений
6. Deep link получать **до** навигатора в main()
7. Loading widget из HTML нужно явно удалять после инициализации
