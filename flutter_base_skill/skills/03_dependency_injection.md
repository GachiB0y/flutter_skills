---
name: Dependency Injection
description: Внедрение зависимостей через Dependencies class с late final, InheritedWidget, Scopes pattern, guard pattern, static shortcut methods
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# Dependency Injection / Внедрение зависимостей (DI)

## Dependencies Class / Класс зависимостей

Центральный подход: простой класс с `late final` полями вместо DI-контейнеров.

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

  // Только критичные контроллеры
  late final AuthController authController;
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

### Использование

```dart
// В любом месте приложения:
final repo = Dependencies.of(context).chatRepository;
// Автодополнение показывает ВСЕ доступные зависимости
// Не нужны дженерики, касты, импорты пакетов
```

### Критика GetIt / Riverpod / Provider

> "Никаких GetIt'ов. Никаких провайдеров, мультипровайдеров. Делаете класс, у него куча late'ов -- вот он ваш мультипровайдер. Не надо дженерики прописывать. Не надо новую зависимость добавлять -- мультик какой-то провайдер... Всё, ничего не надо."

Проблемы сторонних DI:
- Дженерики нужно указывать при каждом обращении
- Нет автодополнения списка зависимостей
- Лишние импорты пакетов
- Загрязнение дерева виджетов (особенно MultiProvider)

## Репозитории vs Контроллеры в Dependencies

### Репозитории -- создавать в main (Dependencies)

Репозитории **не имеют состояния**. У них есть HTTP-клиент, база данных, кэш и реализации методов. Поэтому безопасно создавать в main.

### Контроллеры -- создавать в скоупах (НЕ в Dependencies)

Контроллеры **имеют состояние**. Если создать контроллер в Dependencies:

```
// ПРОБЛЕМА:
// Логинится Вася -> разлогинивается -> логинится Петя
// У Пети список чатов Васи!
```

> "Большинство контроллеров создаются уже по месту применения, потому что у тебя контроллеры и их стейт зависит от аутентификации."

Исключение: контроллеры, которые живут на протяжении всего жизненного цикла приложения (auth, navigation).

## Scopes Pattern / Паттерн скоупов

Скоупы -- это StatefulWidget + InheritedWidget, формирующие "ёлочку" зависимостей в `MaterialApp.builder`.

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
1. **CheckApplication** -- проверка версии раз в час
2. **Settings** -- настройки пользователя
3. **Authentication** -- guard: пока не залогинен, показывается экран логина
4. **ChatList** -- зависит от аутентификации

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
    _of(context).controller.logout(
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  static UserEntity userOf(BuildContext context, {bool listen = true}) {
    if (listen) {
      return context.dependOnInheritedWidgetOfExactType<_InheritedAuth>()!.user;
    }
    return context.findAncestorWidgetOfExactType<_InheritedAuth>()!.user;
  }

  static AuthController controllerOf(BuildContext context) =>
      _of(context).controller;

  @override
  State<AuthenticationScope> createState() => _AuthenticationScopeState();
}

class _AuthenticationScopeState extends State<AuthenticationScope> {
  late final AuthController controller;

  @override
  void initState() {
    super.initState();
    controller = Dependencies.of(context).authController;
    controller.addListener(_onStateChanged);
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedAuth(
      user: controller.state.user,
      child: controller.state.user is AuthenticatedUser
          ? widget.child           // Показываем приложение
          : AuthNavigator(),       // Показываем экран логина
    );
  }
}
```

## Guard Pattern / Паттерн "гарда"

Скоуп может работать как guard -- блокировать доступ к дочерним виджетам до выполнения условия.

### Аутентификация как Guard

```dart
@override
Widget build(BuildContext context) {
  final user = controller.state.user;
  if (user is AuthenticatedUser) {
    return widget.child;      // Пропускаем дальше
  }
  return AuthNavigator();     // Блокируем -- показываем логин
}
```

### CheckApplication как Guard с Overlay

```dart
@override
Widget build(BuildContext context) {
  // Всегда показываем child
  // Но если есть обновление -- показываем overlay поверх
  if (versionController.hasUpdate) {
    final overlay = Overlay.of(context);
    overlay.insert(OverlayEntry(
      builder: (_) => UpdateDialog(
        mandatory: versionController.isMandatoryUpdate,
      ),
    ));
  }
  return widget.child;
}
```

Overlay работает **поверх навигатора** (потому что скоупы размещены в `MaterialApp.builder`).

## Static Shortcut Methods / Статические методы-шоткаты

Вместо получения контроллера, его стейта и вызова метода -- простой вызов через скоуп:

```dart
// БЕЗ шоткатов (много импортов и кода):
final controller = Provider.of<AuthController>(context);
controller.add(LogoutEvent());

// С шоткатами (один импорт, одна строка):
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

> "Вам зачастую просто нужно получить текущего юзера. Не надо получать контроллер, потом получать у него стейт, и из стейта получать юзера."

## UserEntity -- Sealed Class

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

## Key Takeaways / Ключевые выводы

1. `Dependencies` с `late final` -- простой и эффективный DI без пакетов
2. Репозитории (без состояния) -- в Dependencies. Контроллеры (с состоянием) -- в скоупах
3. Скоупы = StatefulWidget + InheritedWidget, формируют "ёлочку" зависимостей
4. Guard pattern -- блокирует доступ до выполнения условия (auth, version check)
5. Static shortcut methods -- упрощают вызов из виджетов
6. Скоупы в `MaterialApp.builder` имеют материальный контекст, но выше навигатора
7. Overlay из builder отображается **поверх любого экрана** навигатора
