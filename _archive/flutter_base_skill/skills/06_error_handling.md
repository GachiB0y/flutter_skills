---
name: Error Handling
description: Обработка ошибок, ErrorUtil, pattern matching, Sentry (sample rate, breadcrumbs, screenshots, event processors), логирование, log buffer
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# Error Handling / Обработка ошибок

## Принцип: ошибки не долетают до виджетов

> "Ни одна ошибка логики никогда не прилетит в виджет. Прямо буквально никакая ошибка. Всё перехватывается строго контроллером."

Цепочка обработки:
1. **Репозиторий** -- может бросить ошибку (это нормально)
2. **Контроллер** -- перехватывает ВСЕ ошибки, переводит в FailedState
3. **ControllerObserver** -- логирует, отправляет в Sentry
4. **Виджет** -- видит только состояние (Idle/Processing/Failed), не ошибку

## ErrorUtil и Pattern Matching

Ошибки преобразуются в пользовательские сообщения через pattern matching:

```dart
class ErrorUtil {
  static String messageFromError(Object error) {
    return switch (error) {
      ApiClientException(statusCode: 401) => 'Unauthorized',
      ApiClientException(statusCode: 403) => 'Access denied',
      ApiClientException(statusCode: 404) => 'Not found',
      ApiClientException(statusCode: 429) => 'Too many requests',
      ApiClientException(code: 'abort' || 'cancel') => '', // Игнорируем
      TimeoutException() => 'Request timed out',
      SocketException() => 'No internet connection',
      FormatException() => 'Invalid response format',
      _ => 'Unknown error',
    };
  }
}
```

### Snackbar per Environment / SnackBar в зависимости от окружения

В development/staging можно показывать более подробные ошибки. В production -- только пользовательские сообщения.

### Ошибки локализации

Ошибки **нельзя** локализовать в контроллере, потому что нет контекста. Локализация происходит в виджете через onError callback:

```dart
controller.create(
  onError: (error) {
    if (!context.mounted) return;
    final message = ErrorUtil.localizedMessage(context, error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  },
);
```

## Sentry

### Sample Rate -- обязательно

> "Вам не имеет абсолютно смысла логировать каждую ошибку."

Расчёт: 1000 пользователей x 10 ошибок x 2 сеанса x 30 дней = 600,000 ошибок/месяц. Никто не будет просматривать каждую.

```dart
SentryFlutter.init(
  (options) {
    options.dsn = sentryUrl;
    options.tracesSampleRate = 0.1; // 10% ошибок
  },
);
```

Или вручную:

```dart
if (Random().nextInt(10) == 0) {
  Sentry.captureException(error, stackTrace: stackTrace);
}
```

Частые ошибки всё равно зафиксируются по теории вероятности. Редкие одноразовые ошибки -- неважны.

### Breadcrumbs -- хлебные крошки

Дополнительные данные к ошибке -- что происходило перед ней:

```dart
// Добавляем в breadcrumbs:
// - Последние 25 логов из LogBuffer
// - Текущий экран
// - Действия пользователя
Sentry.addBreadcrumb(Breadcrumb(
  message: 'User navigated to Settings',
  category: 'navigation',
));
```

### Screenshots -- скриншоты экрана

Sentry поддерживает прикрепление скриншотов к ошибкам из коробки. Можно и самому реализовать.

### Event Processors

Позволяют дополнять каждое событие перед отправкой:

```dart
options.addEventProcessor((event, hint) {
  return event.copyWith(
    user: SentryUser(
      id: currentUser?.id,
      username: currentUser?.name,
    ),
    extra: {
      'last_logs': LogBuffer.instance.last(25),
      'current_screen': navigationController.currentPage,
      'device_info': platformInfo.toString(),
    },
  );
});
```

### Exception Extractors

Извлекают вложенные ошибки из обёрток:

```dart
// Если ваша ошибка содержит другие ошибки:
options.addExceptionCauseExtractor(MyExceptionExtractor());
```

### Когда инициализировать Sentry

Sentry инициализируется **после** runApp, только для production/staging:

```dart
if (environment != 'development' && environment != 'testing') {
  await SentryFlutter.init((options) {
    options.dsn = sentryUrl;
    options.tracesSampleRate = 0.1;
  });
}
```

## Logging / Логирование

### Log Buffer -- круговой буфер

```dart
class LogBuffer {
  static final instance = LogBuffer._();
  LogBuffer._();

  final _buffer = Queue<LogEntry>(); // Круговой буфер на 10,000 элементов
  static const _maxSize = 10000;

  void add(LogEntry entry) {
    if (_buffer.length >= _maxSize) _buffer.removeFirst();
    _buffer.add(entry);
  }

  List<LogEntry> last(int count) =>
      _buffer.toList().reversed.take(count).toList();
}
```

Используется для:
1. **Sentry breadcrumbs** -- последние 25-50 логов прикрепляются к ошибке
2. **Developer screen** -- экран для разработчиков с фильтрацией логов
3. **Отладка** -- понимание последовательности действий

### Developer Screen для логов

```dart
// Отладочный экран (только development):
class DevLogsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final logs = LogBuffer.instance.last(10000);
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) => LogTile(logs[index]),
    );
    // + TextField для фильтрации (например, "authentication")
  }
}
```

### Подписка на логи

Логгер поддерживает подписки -- каждый лог можно направить в Sentry:

```dart
Logger.instance.listen((log) {
  Sentry.addBreadcrumb(Breadcrumb(
    message: log.message,
    level: log.level,
    timestamp: log.timestamp,
  ));
});
```

## Controller message -- для отладки

Каждый стейт содержит `message` для человекочитаемых логов:

```
ChatListController: Idle(message: initial)
ChatListController: Processing(message: refreshing chats)
ChatListController: Idle(message: chats received)
ChatController: Processing(message: creating chat)
ChatController: Idle(message: chat created)
```

> "Каждая строка, она имеет какой-то смысл. Прямо по логам понятно, что происходит."

Message не влияет на UI -- это чисто для:
- Логов
- Sentry
- Понимания последовательности в дебаггере

## runZoneGuarded для перехвата всех ошибок

```dart
// В main:
runZonedGuarded(
  () => runApp(MyApp()),
  (error, stackTrace) {
    log('Unhandled: $error');
    Sentry.captureException(error, stackTrace: stackTrace);
  },
);

// В каждом handler контроллера:
runZonedGuarded(
  () async {
    // Бизнес-логика
  },
  (error, stackTrace) {
    setState(FailedState(error: error, data: state.data));
    ControllerObserver.instance.onError(this, error, stackTrace);
  },
);
```

### Отличие от try-catch

try-catch **не ловит** асинхронные ошибки без await:

```dart
try {
  unawaited(someFuture()); // Ошибка улетит мимо!
} catch (e) { /* не поймает */ }
```

`runZoneGuarded` ловит ВСЕ ошибки в зоне, включая unawaited futures.

## Key Takeaways / Ключевые выводы

1. Ошибки **никогда** не пробрасываются в виджеты (нет rethrow)
2. Sentry sample rate -- обязательно, не логируйте 100% ошибок
3. Breadcrumbs + последние логи из буфера -- для понимания контекста
4. ErrorUtil с pattern matching -- преобразование ошибок в сообщения
5. Локализация ошибок -- только в виджете (через onError callback)
6. LogBuffer (10,000 элементов) -- для отладки и Sentry
7. runZoneGuarded -- в main и в каждом handler контроллера
8. Message в стейте -- для логов и отладки, не для UI
