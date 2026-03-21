---
name: HTTP Client & Networking
description: HTTP-клиент на базе стандартного http пакета, middleware vs interceptors, SSE-поддержка, список middleware
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# HTTP Client & Networking / HTTP-клиент и работа с сетью

## Why not Dio / Почему не Dio

Проект начинался с Dio, но был полностью переписан на стандартный `http` пакет с собственной обёрткой.

Собственный HTTP-клиент поддерживает:
- Middleware (interceptors)
- SSE (Server-Sent Events) -- стриминг ответов от бэкенда
- Клонирование клиентов
- HTTP Factory для создания отдельных клиентов

## Middleware vs Interceptors

Используется паттерн middleware (цепочка обработчиков) поверх стандартного `http` пакета. Клиент создаётся через factory, а не напрямую:

```dart
// В Dependencies:
late final ApiClient apiClient;
late final ApiClient Function() httpFactory;

// Создание основного клиента:
deps.apiClient = createApiClient(deps);

// HTTP Factory -- для создания отдельных клиентов
// (долгие запросы, скачивание файлов)
deps.httpFactory = () => createApiClient(deps);
```

### Head-of-line Blocking

Хорошая практика -- использовать один HTTP-клиент для большинства запросов, но не для всего. Отдельные клиенты нужны для:
- **Долгие запросы** (генерация summary -- может занимать 2 минуты)
- **Скачивание/загрузка файлов**
- **SSE-подписки**

> "Советую почитать про Head-of-line blocking. Если нужно делать долгие запросы -- лучше использовать отдельные клиенты."

## Middleware List / Список middleware

### 1. Deduplication (эфемерный кэш)

Дедупликация одинаковых запросов. Если один запрос уже в полёте -- остальные подписываются на его результат:

```dart
// Пример: при старте info о пользователе запрашивается
// из нескольких мест одновременно.
// Dedup middleware отправляет только один запрос,
// остальные получают тот же результат.
```

### 2. Cache

Кэширование ответов (в SQLite или memory). Позволяет снизить количество обращений к бэкенду.

### 3. Meta Middleware

Подставляет метаинформацию о приложении в заголовки каждого запроса:

```
X-Platform: android
X-App-Version: 1.2.3
X-Build-Mode: release
X-Client: doctorina/1.2.3
```

Полезно для:
- Отладки на бэкенде (откуда пришёл запрос)
- Аналитики
- Sentry (понимание контекста ошибки)

### 4. Retry Middleware

Повторные запросы при определённых ошибках:

```dart
// Повторять:
// - Timeout exceptions (бэк думал слишком долго)
// - 500+ (серверные ошибки, может быть перезагрузка)

// НЕ повторять:
// - 401 (повторный запрос тоже вернёт 401)
// - 403 (нет доступа)
// - 429 (rate limiting -- повторный запрос сделает хуже)
// - 400-408, 422 (клиентские ошибки)
```

> "Я делаю ретрай на определённые ошибки. На 401, 403, 429 -- не делаю. Если бэкенд ругается, что много запросов, повторный запрос сделает только хуже."

### 5. Logger Middleware

Логирование всех запросов и ответов. Полезно для отладки.

### 6. Sentry Middleware

Логирование запросов в Sentry в плане производительности (performance monitoring). Альтернатива: Firebase Performance Monitor (работает под все платформы без дополнительных флагов).

### 7. Timeout Middleware

Общий timeout для всех запросов:

```dart
// Стандартный timeout (12-15 секунд для типичного приложения)
// Отдельные клиенты для долгих операций
```

### 8. Auth Middleware

Аутентификация запросов. Принимает два callback'а:

```dart
class AuthMiddleware {
  final Future<String?> Function() getToken;
  final Future<void> Function() logout;

  // Перед запросом: получает токен, добавляет в заголовки
  // При 401: вызывает logout
}
```

Ключевой момент: middleware принимает **callback'и** (`getToken`, `logout`), а не BLoC напрямую. Это позволяет:
- Middleware не зависит от слоя аутентификации
- Легко тестировать
- Легко переиспользовать

```dart
// Создание клиента с auth middleware:
final client = ApiClient(
  middlewares: [
    AuthMiddleware(
      getToken: () => authBloc.state.data?.token,
      logout: () => authBloc.add(const AuthEvent.logout()),
    ),
    // ...другие middleware
  ],
);
```

## SSE (Server-Sent Events)

HTTP-клиент поддерживает SSE -- бэкенд держит соединение и стримит обновления в теле ответа:

```dart
// Каждая строка в теле ответа -- событие
Stream<ChatEntity> subscribe(String chatId) async* {
  final response = await client.get('/chat/$chatId/subscribe');
  // Бэкенд не закрывает соединение
  // В теле стримит обновления построчно
  await for (final line in response.stream) {
    final event = parseEvent(line);
    yield event;
  }
}
```

Подробнее о реализации SSE-чата -- см. `13_chat_sse.md`.

## Разделитель в именах классов

Интересный паттерн именования с `$` как визуальный разделитель:

```dart
// ClientException -- exception от клиента
// Client$NetworkException -- сетевая ошибка клиента
// Client$AuthenticationException -- ошибка аутентификации

abstract class ClientException implements Exception {}
class Client$NetworkException extends ClientException {}
class Client$AuthenticationException extends ClientException {}
```

Двойной клик на `$` копирует только часть до или после разделителя -- удобно для навигации.

## Key Takeaways / Ключевые выводы

1. Стандартный `http` пакет + собственная обёртка с middleware вместо Dio
2. Один основной клиент + отдельные для долгих операций (Head-of-line blocking)
3. Auth middleware принимает callback'и, не BLoC
4. Retry только для серверных/timeout ошибок, не для 4xx
5. Meta middleware -- метаинформация в каждом запросе
6. Dedup middleware -- эфемерный кэш для одновременных одинаковых запросов
7. HTTP Factory в Dependencies для создания отдельных клиентов
