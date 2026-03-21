---
name: Chat Implementation (SSE)
description: SSE-подписка, heartbeat timer, переподключение, chat entity events, стриминг ответов
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# Chat Implementation (SSE) / Реализация чата через SSE

## SSE (Server-Sent Events) -- не WebSocket

> "Это не WebSocket. Это SSE -- более тупая вещь."

SSE -- HTTP-запрос, который бэкенд **не закрывает**, а стримит обновления в теле ответа. Каждая строка -- событие.

```
GET /chat/{id}/subscribe HTTP/1.1

// Ответ (тело стримится построчно):
data: {"type": "user_message", "id": "1", "text": "Hello"}
data: {"type": "assistant_message", "id": "2", "text": "Hi!"}
data: {"type": "status", "status": "thinking"}
data: {"type": "ping"}
```

## Chat Entity Events / Типы событий

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

SSE-подписка создаётся в **конструкторе BLoC-а**:

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
        _lastUpdate = DateTime.now(); // Обновляем timestamp

        switch (event) {
          case UserMessageEvent(:final text, :final id):
            _addMessage(Message.user(id: id, text: text));
          case AssistantMessageEvent(:final text, :final id):
            _addMessage(Message.assistant(id: id, text: text));
          case StatusEvent(:final status):
            _updateStatus(status);
          case PingEvent():
            // Просто обновляем _lastUpdate
            break;
        }
      },
      onError: (error) {
        // Ошибка подписки -- пробуем переподключиться
        _reconnect();
      },
    );
  }
}
```

### Важный момент: сообщения приходят через SSE, не через POST-ответ

> "Когда я отправляю сообщение бэкенду, бэкенд мне даже не отвечает сообщение, которое я отправил. У меня нет ID отправленного сообщения. Я именно сообщение ловлю из SSE эвентом."

Поток:
1. Пользователь отправляет POST (текст сообщения)
2. Поле ввода блокируется
3. Бэкенд обрабатывает, стримит ответ через SSE
4. SSE-подписка получает `UserMessageEvent` -- сообщение пользователя
5. SSE-подписка получает `AssistantMessageEvent` -- ответ ассистента
6. Поле ввода разблокируется

## Heartbeat Timer / Проверка соединения

> "Максимально тупой подход. Просто таймер, который проверяет, когда последний раз бэкенд присылал пинг."

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
  // 1. Показываем пользователю "нет интернета"
  setState(ChatState.processing(
    data: state.data,
    message: 'reconnecting',
  ));

  // 2. Отписываемся от старого стрима
  _subscription?.cancel();
  // При отмене подписки HTTP-запрос тоже закрывается

  // 3. Подписываемся заново
  _subscribe();
}
```

## Close / Очистка ресурсов

```dart
@override
Future<void> close() {
  _heartbeatTimer?.cancel();       // Останавливаем таймер
  _subscription?.cancel();          // Отписываемся от SSE
  return super.close();
}
```

> "В close я отписываюсь от таймера проверки жизнеспособности и от подписки на репозиторий."

## Состояние подписки -- в BLoC-е, не в репозитории

```dart
// lastUpdate -- это мутабельная переменная = состояние
// Состояние должно быть в BLoC-е, не в репозитории
DateTime _lastUpdate = DateTime.now();
StreamSubscription? _subscription;
Timer? _heartbeatTimer;
```

> "Подписка, мутабельная переменная -- это состояние. Состояние должно быть в BLoC-е. У репозиториев состояния быть не должно."

### Почему не в репозитории

- Может быть несколько BLoC-ов одновременно (несколько чатов открыто)
- Они будут драться за общий `lastUpdate`
- При close BLoC-а нужно отписаться **только от своей** подписки

### У репозиториев нет dispose

> "У репозиториев не должно быть dispose. Если есть -- значит есть состояние. В репозиториях подписки быть не должно в продакшене."

Исключение: эфемерный кэш (хэш-таблица) -- это допустимо:

```dart
class ChatRepository {
  // Допустимо -- кэш в памяти (как база данных в памяти)
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
      // При отписке: закрыть HTTP-соединение
    };

    // Запускаем HTTP-запрос
    final response = await client.get('/chat/$chatId/subscribe');

    // Стримим строки из тела ответа
    await for (final line in response.stream) {
      if (controller.isClosed) break;
      final event = parseEvent(line);
      controller.add(event);
    }

    yield* controller.stream;
  }
}
```

## Key Takeaways / Ключевые выводы

1. **SSE** (не WebSocket) -- HTTP-запрос, бэкенд стримит обновления в теле
2. **Heartbeat timer** -- простой таймер (30 секунд без пинга = переподключение)
3. Состояние подписки (lastUpdate, subscription, timer) -- **в BLoC-е**, не в репозитории
4. Сообщения пользователя приходят через SSE, а не как ответ на POST
5. Close: отменить таймер + отменить подписку (в `close()` override)
6. У репозиториев **нет** dispose и **нет** состояния (кроме эфемерного кэша)
7. Несколько BLoC-ов чата могут существовать одновременно -- каждый со своей подпиской
8. BLoC использует **SetStateMixin** для `setState()` и **BlocController** mixin для `handle()`
9. SSE-подписка инициируется в **конструкторе BLoC-а**, `notifyListeners()` заменён на `setState()`
