---
name: Authentication
description: Аутентификация, auth middleware, sealed UserEntity, auth scope как guard, отдельный навигатор для auth
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# Authentication / Аутентификация

## Auth Middleware в HTTP-клиенте

Auth middleware принимает два callback'а, а не контроллер напрямую:

```dart
class AuthMiddleware {
  final Future<String?> Function() getToken;
  final Future<void> Function() logout;

  AuthMiddleware({required this.getToken, required this.logout});

  Future<Response> handle(Request request) async {
    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final response = await next(request);

    if (response.statusCode == 401) {
      await logout();
      // Не повторяем запрос -- если 401, то повторный тоже вернёт 401
    }

    return response;
  }
}
```

Создание с привязкой к контроллеру:

```dart
final client = ApiClient(
  middlewares: [
    AuthMiddleware(
      getToken: () async => authController.state.token,
      logout: () async => authController.logout(),
    ),
    // ...
  ],
);
```

## Sealed UserEntity

Пользователь моделируется как sealed class с двумя вариантами:

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
  final String? photoUrl;
  // Опционально: добавить роли (admin, user)
  // Но лучше не совмещать роли с аутентификацией

  const AuthenticatedUser({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });
}
```

### Использование pattern matching

```dart
final user = AuthenticationScope.userOf(context);
switch (user) {
  case UnauthenticatedUser():
    // Не залогинен
    break;
  case AuthenticatedUser(:final name):
    // Залогинен, показываем имя
    Text('Hello, $name');
    break;
}
```

### Nullable vs Sealed

Можно использовать `User?` (null = не залогинен), но sealed class лучше:
- Компилятор проверяет exhaustiveness
- Можно добавлять типы (Admin, Guest)
- Более явный код

## Auth Scope как Guard

AuthenticationScope -- ключевой скоуп, который работает как **guard**: блокирует доступ к приложению, пока пользователь не аутентифицирован.

```dart
class AuthenticationScope extends StatefulWidget {
  final Widget child;
  const AuthenticationScope({required this.child});

  // --- Shortcut methods ---

  static void logout(BuildContext context, {
    VoidCallback? onSuccess,
    void Function(Object)? onError,
  }) {
    _stateOf(context).controller.logout(
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  static void loginWithGoogle(BuildContext context, {
    VoidCallback? onSuccess,
    void Function(Object)? onError,
  }) {
    _stateOf(context).controller.loginWithGoogle(
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  static void loginWithApple(BuildContext context, { ... }) { ... }
  static void loginWithPhone(BuildContext context, { ... }) { ... }

  static UserEntity userOf(BuildContext context, {bool listen = true}) {
    if (listen) {
      return context
          .dependOnInheritedWidgetOfExactType<_InheritedAuth>()!
          .user;
    }
    return context
        .findAncestorWidgetOfExactType<_InheritedAuth>()!
        .user;
  }

  static AuthenticatedUser? authenticatedUserOf(BuildContext context) {
    final user = userOf(context, listen: false);
    return user is AuthenticatedUser ? user : null;
  }

  @override
  State<AuthenticationScope> createState() => _AuthenticationScopeState();
}
```

### State скоупа

```dart
class _AuthenticationScopeState extends State<AuthenticationScope> {
  late final AuthController controller;

  @override
  void initState() {
    super.initState();
    controller = Dependencies.of(context).authController;
    controller.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    setState(() {});
    // Аналитика: трекинг изменения пользователя
    // Sentry: обновление текущего пользователя
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedAuth(
      user: controller.state.user,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    final user = controller.state.user;
    if (user is AuthenticatedUser) {
      return widget.child;       // Пропускаем в приложение
    }
    return const AuthNavigator(); // Показываем экран логина
  }

  @override
  void dispose() {
    controller.removeListener(_onStateChanged);
    super.dispose();
  }
}
```

### Guard-паттерн в билдере

```dart
// В MaterialApp.builder:
MaterialApp(
  builder: (context, child) {
    return AuthenticationScope(       // GUARD
      child: SettingsScope(
        child: ChatListScope(
          child: child!,             // Навигатор приложения
        ),
      ),
    );
  },
);
```

Порядок скоупов:
1. AuthenticationScope -- **выше** навигатора
2. Пока не залогинен -- показывается AuthNavigator
3. После логина -- показывается основное приложение с навигатором

## Отдельный навигатор для аутентификации

Для экранов аутентификации используется **отдельный навигатор** (или просто переключение виджетов):

```dart
class AuthNavigator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Может быть:
    // 1. Отдельный Navigator со своими pages
    // 2. Простой switch виджетов
    return Navigator(
      pages: [
        LoginPage(),
        // При необходимости: PhoneVerificationPage, etc.
      ],
      onDidRemovePage: (page) { ... },
    );
  }
}
```

## Контроллеры -- не в Dependencies для auth-зависимых данных

Контроллеры, зависящие от текущего пользователя, **создаются в скоупах**, не в Dependencies:

```dart
// ПРОБЛЕМА если создать в Dependencies:
// Вася логинится -> его чаты загружаются в контроллер
// Вася разлогинивается -> Петя логинится
// У Пети отображаются чаты Васи!

// РЕШЕНИЕ: создавать в скоупе ПОСЛЕ аутентификации
class ChatListScope extends StatefulWidget {
  @override
  State<ChatListScope> createState() => _ChatListScopeState();
}

class _ChatListScopeState extends State<ChatListScope> {
  late final ChatListController controller;

  @override
  void initState() {
    super.initState();
    // Создаём контроллер в скоупе
    // Он будет пересоздан при смене пользователя
    controller = ChatListController(
      repository: Dependencies.of(context).chatRepository,
    );
  }
}
```

## Фейковая авторизация для разработки

При фейковом окружении -- автоматический логин:

```dart
if (environment == 'fake') {
  // Автоматический логин через фейковый Google-аккаунт
  // Чтобы не начинать каждый раз с экрана логина
  await authController.loginWithFakeGoogle();
}
```

## Провайдеры аутентификации

Поддерживаются:
- **Google** (Sign in with Google)
- **Apple** (Sign in with Apple)
- **Телефон** (SMS, включая WhatsApp)
- **Email**
- Социальные провайдеры (Facebook, etc.)

Всё через Firebase Auth.

## Key Takeaways / Ключевые выводы

1. **Auth middleware** принимает callback'и (getToken/logout), не контроллер
2. **Sealed UserEntity** -- UnauthenticatedUser / AuthenticatedUser
3. **AuthScope как guard** -- выше навигатора, блокирует доступ
4. **Отдельный навигатор** для экранов аутентификации
5. Контроллеры, зависящие от пользователя, создаются **в скоупах после auth**
6. При 401 от бэкенда -- logout, без повторного запроса
7. Shortcut-методы в скоупе: `AuthenticationScope.logout(context)`
