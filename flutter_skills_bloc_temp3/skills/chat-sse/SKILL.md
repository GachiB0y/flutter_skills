---
name: chat-sse
description: Use when implementing chat with SSE (Server-Sent Events), heartbeat timer, reconnection logic, or streaming responses. MUST use for any real-time chat, SSE subscription, or server streaming implementation in Flutter.
---

# Chat Implementation (SSE) / Реализация чата через SSE

## SSE (Server-Sent Events) — не WebSocket

SSE — HTTP-запрос, который бэкенд не закрывает, а стримит обновления в теле ответа. Каждая строка — событие:

```
GET /chat/{id}/subscribe HTTP/1.1

// Ответ (тело стримится построчно):
data: {"type": "user_message", "id": "1", "text": "Hello"}
data: {"type": "assistant_message", "id": "2", "text": "Hi!"}
data: {"type": "status", "status": "thinking"}
data: {"type": "ping"}
```

## Chat Entity Events / Типы событий

Определяй типы событий через sealed class:

```dart
sealed class ChatSseEvent {
  const ChatSseEvent();
}

class UserMessageEvent extends ChatSseEvent {
  final String id;
  final String text;
  final DateTime timestamp;
  const UserMessageEvent({...});
}

class AssistantMessageEvent extends ChatSseEvent {
  final String id;
  final String text;
  final DateTime timestamp;
  const AssistantMessageEvent({...});
}

class StatusEvent extends ChatSseEvent {
  final String status; // "thinking", "typing", "done"
  const StatusEvent({required this.status});
}

class PingEvent extends ChatSseEvent {
  const PingEvent();
}
```

## Подписка в BLoC-е

Создавай SSE-подписку в конструкторе BLoC-а:

```dart
class ChatBloc extends Bloc<ChatEvent, ChatState> with SetStateMixin, BlocController {
  final ChatRepository _repository;
  StreamSubscription<ChatSseEvent>? _subscription;
  DateTime _lastUpdate = DateTime.now();
  Timer? _heartbeatTimer;

  ChatBloc({required ChatRepository repository})
      : _repository = repository,
        super(ChatState.idle()) {
    on<ChatEvent>(_onEvent);
    _subscribe();
    _startHeartbeat();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.subscribe(chatId).listen(
      (event) {
        _lastUpdate = DateTime.now(); // Обновляй timestamp

        switch (event) {
          case UserMessageEvent(:final text, :final id):
            _addMessage(Message.user(id: id, text: text));
          case AssistantMessageEvent(:final text, :final id):
            _addMessage(Message.assistant(id: id, text: text));
          case StatusEvent(:final status):
            _updateStatus(status);
          case PingEvent():
            // Просто обновляй _lastUpdate
            break;
        }
      },
      onError: (error) {
        // Ошибка подписки — переподключайся
        _reconnect();
      },
    );
  }
}
```

### Важно: сообщения приходят через SSE, не через POST-ответ

Поток:
1. Пользователь отправляет POST (текст сообщения)
2. Поле ввода блокируется
3. Бэкенд обрабатывает, стримит ответ через SSE
4. SSE-подписка получает `UserMessageEvent` — сообщение пользователя
5. SSE-подписка получает `AssistantMessageEvent` — ответ ассистента
6. Поле ввода разблокируется

## Heartbeat Timer / Проверка соединения

Используй простой heartbeat timer для проверки соединения:

```dart
void _startHeartbeat() {
  _heartbeatTimer = Timer.periodic(
    Duration(seconds: 10),
    (_) => _checkConnection(),
  );
}

void _checkConnection() {
  final now = DateTime.now();
  final diff = now.difference(_lastUpdate);

  if (diff.inSeconds > 30) {
    // 30 секунд без пинга и сообщений = соединение потеряно
    _reconnect();
  }
}
```

### Reconnection / Переподключение

```dart
void _reconnect() {
  // 1. Покажи пользователю "нет интернета"
  setState(ChatState.processing(
    data: state.data,
    message: 'reconnecting',
  ));

  // 2. Отпишись от старого стрима
  _subscription?.cancel();
  // При отмене подписки HTTP-запрос тоже закрывается

  // 3. Подпишись заново
  _subscribe();
}
```

## Close / Очистка ресурсов

В `close()` отменяй таймер и отписывайся от SSE:

```dart
@override
Future<void> close() {
  _heartbeatTimer?.cancel();       // Останавливай таймер
  _subscription?.cancel();          // Отписывайся от SSE
  return super.close();
}
```

## Состояние подписки — в BLoC-е, не в репозитории

```dart
// lastUpdate — это мутабельная переменная = состояние
// Состояние должно быть в BLoC-е, не в репозитории
DateTime _lastUpdate = DateTime.now();
StreamSubscription? _subscription;
Timer? _heartbeatTimer;
```

Храни состояние подписки (lastUpdate, subscription, timer) в BLoC-е. У репозиториев состояния быть не должно.

### Почему не в репозитории

- Может быть несколько BLoC-ов одновременно (несколько чатов открыто)
- Они будут драться за общий `lastUpdate`
- При close BLoC-а нужно отписаться только от своей подписки

### У репозиториев нет dispose

У репозиториев не должно быть dispose. Если есть — значит есть состояние. Подписки в репозиториях быть не должно.

Исключение: эфемерный кэш (хэш-таблица) — это допустимо:

```dart
class ChatRepository {
  // Допустимо — кэш в памяти (как база данных в памяти)
  final Map<String, ChatEntity> _cache = {};
}
```

## Репозиторий с Stream (вариант реализации)

```dart
class ChatRepositoryImpl implements ChatRepository {
  @override
  Stream<ChatSseEvent> subscribe(String chatId) async* {
    final controller = StreamController<ChatSseEvent>();

    controller.onCancel = () {
      // При отписке: закрой HTTP-соединение
    };

    // Запускай HTTP-запрос
    final response = await client.get('/chat/$chatId/subscribe');

    // Стримь строки из тела ответа
    await for (final line in response.stream) {
      if (controller.isClosed) break;
      final event = parseEvent(line);
      controller.add(event);
    }

    yield* controller.stream;
  }
}
```

## Key Takeaways

1. **SSE** (не WebSocket) — HTTP-запрос, бэкенд стримит обновления в теле
2. **Heartbeat timer** — простой таймер (30 секунд без пинга = переподключение)
3. Состояние подписки (lastUpdate, subscription, timer) — в BLoC-е, не в репозитории
4. Сообщения пользователя приходят через SSE, а не как ответ на POST
5. Close: отменяй таймер + отменяй подписку (в `close()` override)
6. У репозиториев нет dispose и нет состояния (кроме эфемерного кэша)
7. Несколько BLoC-ов чата могут существовать одновременно — каждый со своей подпиской
8. BLoC использует SetStateMixin для `setState()` и BlocController mixin для `handle()`
9. SSE-подписку инициируй в конструкторе BLoC-а
