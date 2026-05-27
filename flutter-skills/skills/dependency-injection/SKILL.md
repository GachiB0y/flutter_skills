---
name: dependency-injection
description: Use when implementing dependency injection, creating Dependencies class, InheritedWidget, Scopes pattern, guard pattern, or organizing BLoC providers. MUST use for any DI setup, scope creation, or dependency organization in Flutter. Covers why NOT to use GetIt/Riverpod/Provider for DI.
---

# Dependency Injection / Внедрение зависимостей (DI)

## Почему НЕ Provider / MultiProvider / GetIt / Riverpod

### MultiProvider в корне — антипаттерн

Раскладывать все зависимости по `MultiProvider` / `MultiBlocProvider` в корне — плохо:

```dart
// ❌ ТАК НЕ ДЕЛАЙ — нечитаемое дерево, нет автодополнения
MultiProvider(
  providers: [
    Provider<IAuthRepository>(create: (_) => AuthRepository(apiClient)),
    Provider<IChatRepository>(create: (_) => ChatRepository(apiClient, db)),
    Provider<ISettingsRepository>(create: (_) => SettingsRepository(prefs)),
    BlocProvider(create: (_) => AuthBloc(authRepo)),
    BlocProvider(create: (_) => NavigationBloc()),
    // ... ещё 20 штук
  ],
  child: App(),
)
```

Проблемы:
- Widget Inspector превращается в нечитаемую кашу
- При каждом обращении нужен импорт пакета + импорт типа + дженерик
- Нет автодополнения списка доступных зависимостей
- Легко ошибиться: интерфейс vs имплементация при указании типа

### Плохой трейд: экономия при создании vs страдания при использовании

Provider/BlocProvider — одна строка при объявлении. InheritedWidget — несколько строк (но генерится сниппетом один раз). Зато при **использовании** (а это сотни мест в проекте):

```dart
// ❌ Provider — КАЖДЫЙ раз в КАЖДОМ файле:
import 'package:provider/provider.dart';
import '../../feature/chat/data/i_chat_repository.dart';
import '../../feature/auth/controllers/auth_controller.dart';

final repo = context.read<IChatRepository>();   // помни тип, не перепутай интерфейс
final ctrl = context.read<AuthController>();     // помни тип, импортируй

// ✅ Dependencies — ВЕЗДЕ одинаково, без импортов пакетов:
final repo = context.dependencies.chatRepository;   // автодополнение
final ctrl = context.dependencies.authController;    // автодополнение
```

Ты покупаешь "полениться один раз написать пару строк при создании" за "страдать каждый раз при обращении к зависимости". Объявление пишется один раз, обращение — сотни раз. Оптимизируй то, что делаешь чаще.

## Dependencies Class / Класс зависимостей

Создавай простой класс `Dependencies` с `late final` полями вместо DI-контейнеров.

```dart
class Dependencies {
  // Репозитории (создаются в main, не имеют состояния)
  late final ChatRepository chatRepository;
  late final AuthRepository authRepository;
  late final SettingsRepository settingsRepository;
  late final VersionRepository versionRepository;

  // Инфраструктура
  late final SharedPreferences sharedPreferences;
  late final Database database;
  late final ApiClient apiClient;
  late final ApiClient Function() httpFactory;

  // Метаданные
  late final AppMetadata metadata;

  // Только критичные BLoC'и и контроллеры, живущие весь lifecycle приложения
  late final AuthBloc authBloc;
  late final NavigationController navigationController;
}
```

### InheritedWidget для инъекции

```dart
class InheritedDependencies extends InheritedWidget {
  final Dependencies dependencies;

  const InheritedDependencies({
    required this.dependencies,
    required super.child,
  });

  static Dependencies of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<InheritedDependencies>()!
        .dependencies;
  }

  @override
  bool updateShouldNotify(InheritedDependencies oldWidget) =>
      !identical(dependencies, oldWidget.dependencies);
}
```

### Extension на BuildContext

Используй extension для краткого доступа — зависимости нужны часто и везде:

```dart
extension DependenciesExtension on BuildContext {
  Dependencies get dependencies => InheritedDependencies.of(this);
}
```

### Использование

```dart
// Везде в приложении — одна строка, автодополнение, ноль лишних импортов:
final repo = context.dependencies.chatRepository;
final ctrl = context.dependencies.authController;
final api = context.dependencies.apiClient;

// IDE показывает ВСЕ доступные зависимости через автодополнение
// Не нужны дженерики, касты, импорты пакетов
```

## Репозитории vs BLoC в Dependencies

### Репозитории — создавай в main (Dependencies)

Репозитории **не имеют состояния**. У них есть HTTP-клиент, база данных, кэш и реализации методов. Поэтому безопасно создавать в main.

### BLoC'и — создавай в скоупах (НЕ в Dependencies)

BLoC'и **имеют состояние**. Если создать BLoC в Dependencies:

```
// ПРОБЛЕМА:
// Логинится Вася -> разлогинивается -> логинится Петя
// У Пети список чатов Васи!
```

Большинство BLoC'ов создаются по месту применения, потому что их стейт зависит от аутентификации.

Исключение: BLoC'и, которые живут на протяжении всего жизненного цикла приложения (auth, navigation).

## Scopes Pattern / Паттерн скоупов

Используй паттерн скоупов — это StatefulWidget + InheritedWidget, формирующие "ёлочку" зависимостей в `MaterialApp.builder`.

### Структура скоупов

```dart
MaterialApp(
  builder: (context, child) {
    return CheckApplicationScope(   // Проверка версии
      child: SettingsScope(         // Настройки
        child: AuthenticationScope( // Аутентификация (guard!)
          child: ChatListScope(     // Список чатов
            child: child!,          // Навигатор
          ),
        ),
      ),
    );
  },
);
```

Каждый скоуп зависит от контекста предыдущих. Порядок важен:
1. **CheckApplication** — проверка версии раз в час
2. **Settings** — настройки пользователя
3. **Authentication** — guard: пока не залогинен, показывается экран логина
4. **ChatList** — зависит от аутентификации

### Реализация скоупа

```dart
class AuthenticationScope extends StatefulWidget {
  final Widget child;
  const AuthenticationScope({required this.child});

  // Статические shortcut-методы
  static void logout(BuildContext context, {
    VoidCallback? onSuccess,
    void Function(Object error)? onError,
  }) {
    _of(context).authBloc.add(LogoutEvent(
      onSuccess: onSuccess,
      onError: onError,
    ));
  }

  static UserEntity userOf(BuildContext context, {bool listen = true}) {
    if (listen) {
      return context.dependOnInheritedWidgetOfExactType<_InheritedAuth>()!.user;
    }
    return context.findAncestorWidgetOfExactType<_InheritedAuth>()!.user;
  }

  static AuthBloc blocOf(BuildContext context) =>
      _of(context).authBloc;

  @override
  State<AuthenticationScope> createState() => _AuthenticationScopeState();
}

class _AuthenticationScopeState extends State<AuthenticationScope> {
  late final AuthBloc authBloc;
  StreamSubscription<AuthState>? _subscription;

  @override
  void initState() {
    super.initState();
    authBloc = context.dependencies.authBloc;
    _subscription = authBloc.stream.listen(_onStateChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedAuth(
      user: authBloc.state.user,
      child: authBloc.state.user is AuthenticatedUser
          ? widget.child           // Показываем приложение
          : AuthNavigator(),       // Показываем экран логина
    );
  }
}
```

## Guard Pattern / Паттерн "гарда"

Скоуп может работать как guard — блокировать доступ к дочерним виджетам до выполнения условия.

### Аутентификация как Guard

```dart
@override
Widget build(BuildContext context) {
  final user = authBloc.state.user;
  if (user is AuthenticatedUser) {
    return widget.child;      // Пропускай дальше
  }
  return AuthNavigator();     // Блокируй — показывай логин
}
```

### CheckApplication как Guard с Overlay

```dart
@override
Widget build(BuildContext context) {
  // Всегда показывай child
  // Но если есть обновление — показывай overlay поверх
  if (versionBloc.state.hasUpdate) {
    final overlay = Overlay.of(context);
    overlay.insert(OverlayEntry(
      builder: (_) => UpdateDialog(
        mandatory: versionBloc.state.isMandatoryUpdate,
      ),
    ));
  }
  return widget.child;
}
```

Overlay работает **поверх навигатора** (потому что скоупы размещены в `MaterialApp.builder`).

## Static Shortcut Methods / Статические методы-шоткаты

Вместо получения BLoC, его стейта и вызова метода — используй простой вызов через скоуп:

```dart
// ❌ Без шоткатов (много импортов и кода):
final authBloc = context.read<AuthBloc>();
authBloc.add(LogoutEvent());

// ✅ С шоткатами (один импорт, одна строка):
AuthenticationScope.logout(context,
  onSuccess: () => showSnackBar('Logged out'),
  onError: (e) => showSnackBar('Error: $e'),
);

// Получение текущего пользователя:
final user = AuthenticationScope.userOf(context);
// С подпиской (по умолчанию):
final user = AuthenticationScope.userOf(context, listen: true);
// Без подписки (единоразово):
final user = AuthenticationScope.userOf(context, listen: false);
```

## UserEntity — Sealed Class

```dart
sealed class UserEntity {
  const UserEntity();
}

class UnauthenticatedUser extends UserEntity {
  const UnauthenticatedUser();
}

class AuthenticatedUser extends UserEntity {
  final String id;
  final String name;
  final String email;
  // ...
  const AuthenticatedUser({required this.id, required this.name, required this.email});
}
```

> **Примечание:** `BlocProvider` и `MultiBlocProvider` — из пакета `flutter_bloc`. Они используются для предоставления BLoC'ов в поддеревьях виджетов (в скоупах, на экранах). Это НЕ противоречит отказу от GetIt/Riverpod — `flutter_bloc` используется как стейт-менеджмент, а не как DI-контейнер.

## Key Takeaways / Ключевые выводы

1. `Dependencies` с `late final` + extension `context.dependencies` — простой DI с автодополнением, без пакетов
2. Оптимизируй **использование** (сотни мест), а не **создание** (один раз) — Provider делает наоборот
3. Репозитории (без состояния) — в Dependencies. BLoC'и (с состоянием) — в скоупах
4. Скоупы = StatefulWidget + InheritedWidget, формируют "ёлочку" зависимостей
5. Guard pattern — блокирует доступ до выполнения условия (auth, version check)
6. Static shortcut methods — упрощают вызов из виджетов
7. Скоупы в `MaterialApp.builder` имеют материальный контекст, но выше навигатора
8. Overlay из builder отображается **поверх любого экрана** навигатора
