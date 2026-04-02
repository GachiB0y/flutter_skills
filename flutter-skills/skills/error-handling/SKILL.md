---
name: error-handling
description: Use when setting up error handling, integrating Sentry (sample rate, breadcrumbs, screenshots), creating ErrorUtil with pattern matching, configuring LogBuffer, or handling errors in BLoC. MUST use for any error handling, logging, or crash reporting setup in Flutter.
---

# Error Handling / Обработка ошибок

## Принцип: ошибки не долетают до виджетов

Не допускай, чтобы ошибки логики долетали до виджетов. Всё перехватывай в BLoC.

Цепочка обработки:
1. **Репозиторий** -- может бросить ошибку (это нормально)
2. **BLoC** -- перехватывает ВСЕ ошибки, переводит в FailedState
3. **BlocObserver** -- логирует, отправляет в Sentry
4. **Виджет** -- видит только состояние (Idle/Processing/Failed), не ошибку

## Не используй Either/Result в Dart

Either/Result паттерн **вреден** в Dart-экосистеме:

- **Потеря стек-трейса** -- при замене throw на return теряется оригинальный stack trace
- **Двойная работа** -- внешние библиотеки (Dio, Firebase, Drift) бросают exceptions, всё равно нужен try/catch для конвертации в Either
- **Несовместимость с экосистемой** -- BlocObserver, runZonedGuarded, FlutterError.onError ожидают thrown errors
- **Усложнение без пользы** -- Dart не Rust/Kotlin, у него нет exhaustive matching на Result

Используй стандартный exception-based подход с try/catch.

## Дизайн кастомных исключений

Создавай domain-specific исключения с полезными данными:

```dart
final class OtpUserBlockedException implements Exception {
  final Duration? blockDuration;
  final String? message;

  const OtpUserBlockedException({
    this.blockDuration,
    this.message,
  });
}

final class PostPublishException implements Exception {
  final Object? cause;

  const PostPublishException(this.cause);
}
```

Правила:
- Используй `implements Exception`, не `extends`
- Добавляй поля с контекстом ошибки (duration, code, message)
- Делай `final class` для sealed иерархий

## Сохранение стек-трейса: Error.throwWithStackTrace

При оборачивании ошибки в кастомный тип **всегда** сохраняй оригинальный стек-трейс:

```dart
try {
  await publishPost();
} on PostPublishException {
  rethrow; // Уже нужный тип -- просто пробрасываем
} catch (e, stack) {
  // Оборачиваем, сохраняя оригинальный stack trace
  Error.throwWithStackTrace(PostPublishException(e), stack);
}
```

**Никогда** не делай `throw PostPublishException(e)` без стек-трейса -- потеряешь информацию о месте возникновения ошибки.

### Pattern matching на данных ответа (map patterns)

Для извлечения структурированных данных из ошибок API используй map patterns:

```dart
try {
  await sendOtp(phoneNumber);
} catch (e, stackTrace) {
  if (e.error
      case {
        'code': 'OTP_USER_BLOCKED',
        'block_duration': final int blockDuration,
        'message': final String message,
      }) {
    Error.throwWithStackTrace(
      OtpUserBlockedException(
        blockDuration: Duration(seconds: blockDuration),
        message: message,
      ),
      stackTrace,
    );
  }
  rethrow;
}
```

## Селективный rethrow в BLoC

Известные ошибки обрабатываем **без** rethrow (они не должны попадать в Sentry). Неизвестные -- **rethrow** для propagation в BlocObserver/Sentry:

```dart
Future<void> _sendOtp(
  OtpSendEvent event,
  Emitter<OtpState> emitter,
) async {
  try {
    emitter(const OtpProgressState());
    await _otpRepository.sendOtp(event.phoneNumber);
    emitter(const OtpSuccessState());
  } on OtpUserBlockedException catch (e) {
    // Известная ошибка -- обрабатываем, НЕ пробрасываем
    logger.warning('User is blocked for ${e.blockDuration}');
    emitter(OtpFailureState(e));
  } catch (e) {
    // Неизвестная ошибка -- пробрасываем в BlocObserver → Sentry
    emitter(OtpFailureState(e));
    rethrow;
  }
}
```

Принцип: **rethrow неизвестных ошибок** -- чтобы BlocObserver и Sentry узнали о них. Известные ошибки (бизнес-логика) не пробрасываем.

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

Ошибки **нельзя** локализовать в BLoC-е, потому что нет контекста. Локализация происходит в виджете через onError callback:

```dart
context.read<MyBloc>().add(MyEvent.create(
  onError: (error) {
    if (!context.mounted) return;
    final message = ErrorUtil.localizedMessage(context, error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  },
));
```

## Sentry

### Sample Rate -- обязательно

Не логируй каждую ошибку. Обязательно используй sample rate в Sentry.

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

### Stream-based error reporting

Автоматическая отправка ошибок в Sentry через поток логов:

```dart
class ErrorReporter {
  StreamSubscription<LogMessage>? _subscription;

  Stream<LogMessage> get _reportLogs =>
      _logger.logs.where((log) => log.level == LogLevel.error);

  Future<void> enableReporting() async {
    _subscription ??= _reportLogs.listen((log) async {
      await Sentry.captureException(
        log.error ?? log.message,
        stackTrace: log.stackTrace,
      );
    });
  }

  void disableReporting() {
    _subscription?.cancel();
    _subscription = null;
  }
}
```

Это дополняет LogBuffer: буфер хранит историю, а stream reporter автоматически отправляет ошибки в реальном времени.

## BLoC state logging -- для отладки

Каждый стейт содержит `message` для человекочитаемых логов:

```
ChatListBloc: ChatListState$Idle(message: initial)
ChatListBloc: ChatListState$Processing(message: refreshing chats)
ChatListBloc: ChatListState$Idle(message: chats received)
ChatBloc: ChatState$Processing(message: creating chat)
ChatBloc: ChatState$Idle(message: chat created)
```

Message не влияет на UI -- это чисто для:
- Логов
- Sentry
- Понимания последовательности в дебаггере

## handle() для перехвата всех ошибок

Реализация `handle()` через `BlocController` mixin описана в `05_state_management.md`. Каждый event handler BLoC-а оборачивается в `handle()`, который автоматически перехватывает ошибки и переводит состояние в Error.

Для глобального перехвата необработанных ошибок используй три уровня:

### 1. runZonedGuarded -- ловит ошибки Dart-кода

```dart
runZonedGuarded(
  () => runApp(MyApp()),
  (error, stackTrace) {
    log('Unhandled: $error');
    Sentry.captureException(error, stackTrace: stackTrace);
  },
);
```

### 2. FlutterError.onError -- ловит ошибки фреймворка Flutter

```dart
FlutterError.onError = (details) {
  logger.logFlutterError(details);
  Sentry.captureException(
    details.exception,
    stackTrace: details.stack,
  );
};
```

### 3. PlatformDispatcher.onError -- ловит ошибки платформы

```dart
WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
  logger.logPlatformDispatcherError(error, stack);
  Sentry.captureException(error, stackTrace: stack);
  return true;
};
```

Все три уровня нужны для полного покрытия -- каждый ловит свою категорию ошибок.

### Отличие от try-catch

try-catch **не ловит** асинхронные ошибки без await:

```dart
try {
  unawaited(someFuture()); // Ошибка улетит мимо!
} catch (e) { /* не поймает */ }
```

`handle()` из BlocController mixin оборачивает всю логику в безопасный блок. Для глобального перехвата — `runZonedGuarded` в main.

## Key Takeaways / Ключевые выводы

1. Ошибки **не долетают до виджетов** -- BLoC перехватывает и переводит в FailedState
2. **Селективный rethrow** -- известные ошибки обрабатываем без rethrow, неизвестные пробрасываем в BlocObserver/Sentry
3. **Не используй Either/Result** -- Dart-экосистема основана на exceptions, Either теряет стек-трейсы
4. **Error.throwWithStackTrace** -- при оборачивании ошибки всегда сохраняй оригинальный stack trace
5. **Кастомные исключения** с данными (duration, code, message) -- `final class ... implements Exception`
6. Sentry sample rate -- обязательно, не логируйте 100% ошибок
7. Breadcrumbs + последние логи из буфера -- для понимания контекста
8. ErrorUtil с pattern matching -- преобразование ошибок в сообщения (по типам и по map patterns)
9. Локализация ошибок -- только в виджете (через onError callback в BLoC event)
10. LogBuffer (10,000 элементов) + Stream-based error reporting -- для отладки и Sentry
11. **Три уровня перехвата**: `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError`
12. `handle()` из BlocController mixin -- в каждом event handler BLoC-а
13. Message в стейте -- для логов и отладки, не для UI
14. **BlocObserver** -- стандартный flutter_bloc observer для логирования и отправки в Sentry
