---
name: State Management (Controllers)
description: Управление состоянием через ChangeNotifier, sealed class states, concurrency/mutex, onSuccess/onError callbacks, ControllerObserver, runZoneGuarded
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# State Management / Управление состоянием (Controllers)

## Control Package / Пакет control

Используется собственная библиотека `control` -- продвинутые ChangeNotifier'ы. По сути -- ChangeNotifier на стероидах. Но для начинающих показан подход на чистом ChangeNotifier.

## Sealed Class States / Состояния через sealed class

### Три состояния -- и не больше

```dart
sealed class MyState {
  const MyState();

  // Данные доступны в любом состоянии
  abstract final MyModel? data;
  abstract final String message;
}

class IdleState extends MyState {
  @override
  final MyModel? data;
  @override
  final String message;
  const IdleState({this.data, this.message = ''});
}

class ProcessingState extends MyState {
  @override
  final MyModel? data;
  @override
  final String message;
  const ProcessingState({this.data, this.message = ''});
}

class FailedState extends MyState {
  @override
  final MyModel? data;
  @override
  final String message;
  final Object error;
  const FailedState({this.data, this.message = '', required this.error});
}
```

### Anti-pattern: множество состояний

> "Ни в коем случае не создавайте InitialState, SuccessState, LoadingState. Не создавайте миллионы различных стейтов в зависимости от метода. Не делайте SuccessfullyCreated или CreatingState."

Тройка `Idle / Processing / Failed` покрывает **99% всех кейсов** на любом приложении.

- **Idle** (простаивает) -- готов к обработке
- **Processing** (обрабатывает) -- выполняет операцию
- **Failed** (ошибка) -- произошла ошибка

`data` остаётся в каждом состоянии (не теряется при переходах).

### Initial state

Initial -- это **не отдельный state**, а просто Idle с начальными данными:

```dart
// Initial -- это просто Idle
final initialState = IdleState(data: null, message: 'initial');
```

## Controller на ChangeNotifier / Базовый контроллер

```dart
class MyController with ChangeNotifier {
  MyController({required MyRepository repository})
      : _repository = repository;

  final MyRepository _repository;

  // Состояние
  MyState _state = const IdleState(message: 'initial');
  MyState get state => _state;

  // setState с @protected
  @protected
  void setState(MyState newState) {
    if (identical(_state, newState)) return;
    _state = newState;
    notifyListeners();

    // Оповещаем observer
    ControllerObserver.instance.onStateChanged(this, _state);
  }

  @override
  void dispose() {
    // Очистка ресурсов
    super.dispose();
  }
}
```

### Почему ChangeNotifier, а не StreamController

> "ChangeNotifier -- отличная штука. Гораздо лучше StreamController'ов в плане производительности. Во Flutter буквально всё устроено на ChangeNotifier'ах -- анимации, перестроение layout'а. Он проще, синхронный."

### @protected для setState

```dart
@protected
void setState(MyState newState) { ... }
```

`@protected` означает: метод доступен наследникам, но **не снаружи**. Анализатор будет ругаться, если вызвать извне:

```dart
// Снаружи контроллера:
controller.setState(newState); // Анализатор: "это для внутренней реализации"
// Вызвать можно, ошибки не будет, но анализатор предупредит
```

Это отличается от `_private`, который недоступен из другого файла (проблема при наследовании).

### identical vs == для сравнения стейтов

```dart
// Предпочтительно: сравнение по ссылке
if (identical(_state, newState)) return;

// Не рекомендуется: по равенству (==)
// Потому что для sealed class можно легко
// нарушить контракт equals
```

## Типичный метод контроллера

```dart
Future<void> create({
  VoidCallback? onSuccess,
  void Function(Object error)? onError,
}) async {
  setState(ProcessingState(
    data: state.data,  // Сохраняем текущие данные
    message: 'creating',
  ));

  try {
    final result = await _repository.create();

    setState(ProcessingState(
      data: result,  // Обновляем данные
      message: 'created',
    ));

    onSuccess?.call();
  } on Object catch (error) {
    setState(FailedState(
      data: state.data,  // Сохраняем предыдущие данные
      message: 'create failed',
      error: error,
    ));

    onError?.call(error);
    // НЕ делаем rethrow! Ошибка не должна лететь в виджеты
  } finally {
    setState(IdleState(
      data: state.data,
      message: 'idle',
    ));
  }
}
```

### Anti-pattern: rethrow в контроллере

> "Если сделаешь rethrow, ошибка полетит в виджеты. У тебя будут красные экраны. Ни в коем случае!"

## Concurrency / Mutex в контроллерах

### Проблема: двойное нажатие

Если пользователь дважды быстро нажмёт кнопку:
1. Оба вызова бросятся выполнять одновременно
2. Непредсказуемо, кто завершится первым
3. Стейты будут перемешиваться
4. При работе со списками -- дубликаты или потеря данных

### Решение 1: Простая проверка (для начинающих)

```dart
Future<void> create() async {
  if (state is ProcessingState) return;  // Уже обрабатываем
  // ...
}
```

**Важно:** добавьте timeout, иначе контроллер может зависнуть навсегда в Processing.

### Решение 2: Mutex (для продвинутых)

```dart
final _mutex = Mutex();

Future<void> create() async {
  await _mutex.protect(() async {
    setState(ProcessingState(...));
    try {
      // ...
    } finally {
      setState(IdleState(...));
    }
  });
}
```

Mutex гарантирует последовательное выполнение:
- Вызвали create 3 раза -- выполнится 1-й, потом 2-й, потом 3-й
- Стейты не будут перемешиваться

```dart
// Реализация Mutex -- буквально несколько строк
// Можно взять пакет или написать свой
class Mutex {
  Future<void>? _last;

  Future<T> protect<T>(Future<T> Function() fn) async {
    final prev = _last;
    final completer = Completer<void>();
    _last = completer.future;
    if (prev != null) await prev;
    try {
      return await fn();
    } finally {
      completer.complete();
    }
  }
}
```

### Один Mutex на контроллер

> "На контроллер должен быть один общий mutex. Если create и update используют один и тот же стейт, они не должны конкурировать. Два мютикса в контроллере -- это ошибка."

### Anti-pattern: несколько `on` в BLoC

> "Ни в коем случае нельзя писать on EventA, on EventB, on EventC. У каждого свой mutex, и они будут конкурировать за один стейт."

## onSuccess / onError Callback Pattern

```dart
// В контроллере:
Future<void> create({
  VoidCallback? onSuccess,
  void Function(Object error)? onError,
}) async {
  // ...
  try {
    // ...
    onSuccess?.call();
  } on Object catch (error) {
    // ...
    onError?.call(error);
  }
}

// В виджете:
ElevatedButton(
  onPressed: () => controller.create(
    onSuccess: () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Создано!')),
        );
      }
    },
    onError: (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка')),
        );
      }
    },
  ),
);
```

> "Вот как только я изобрёл этот хак, у меня очень много проблем сразу отпало. Жить стал гораздо веселее."

**Важно:** В onSuccess/onError контекст может быть dismounted (асинхронность). Всегда проверяйте `context.mounted`.

### Зачем нужны callbacks вместо подписки на стейт

- Не нужно определять, какой именно вызов привёл к ошибке
- Не нужно подписываться на BlocListener / StreamSubscription
- Привязка непосредственно к действию пользователя
- Избавляет от кучи багов с отписками

## runZoneGuarded в контроллерах

Каждый handler (метод) контроллера обёрнут в `runZoneGuarded`:

```dart
Future<void> _handle(Future<void> Function() fn) async {
  await runZonedGuarded(
    fn,
    (error, stackTrace) {
      // Перехватывает ВСЕ ошибки, включая те,
      // которые try-catch не ловит
      setState(FailedState(error: error, data: state.data));
      ControllerObserver.instance.onError(this, error, stackTrace);
    },
  );
}
```

### Почему runZoneGuarded, а не try-catch

```dart
// try-catch НЕ ловит:
try {
  someAsyncMethod(); // Без await!
  // Ошибка внутри полетит в main zone
} catch (e) {
  // Не поймается!
}

// runZoneGuarded ЛОВИТ все ошибки зоны:
runZonedGuarded(() {
  someAsyncMethod(); // Даже без await ошибка поймается
}, (error, stack) {
  // Поймается!
});
```

> "Любая ошибка у меня ни в коем случае не долетает до виджетов. Она перехватывается всегда контроллером."

## ControllerObserver / GlobalObserver

Синглтон, который получает уведомления обо всех изменениях стейтов и ошибках:

```dart
class ControllerObserver {
  static final instance = ControllerObserver._();
  ControllerObserver._();

  void onStateChanged(Object controller, Object state) {
    // Логирование всех переходов стейтов
    print('$controller: $state');
  }

  void onError(Object controller, Object error, StackTrace stackTrace) {
    // Централизованная обработка ошибок
    // Sentry, аналитика
  }

  void onCreate(Object controller) { ... }
}
```

Пишется один раз, работает для всех контроллеров:
- Логирование переходов стейтов (для отладки)
- Отправка ошибок в Sentry
- Аналитика

### Пример логов

```
ChatListController: Idle(message: initial)
ChatListController: Processing(message: refreshing chats)
ChatListController: Idle(message: chats received, count: 5)
ChatController: Processing(message: creating chat)
ChatController: Idle(message: chat created)
```

## No Flutter Imports in Controllers

> "Никаких импортов Flutter вообще, забудьте, вообще без исключений."

Единственные допустимые исключения:
- `flutter/foundation.dart` -- аннотации (`@protected`, `@immutable`), изоляты
- `dart:ui` -- **только** часть, отвечающая за MethodChannel (не виджеты, не рендер)

Запрещено:
- `BuildContext`
- Любые виджеты
- `Navigator`
- `Color`
- Любой UI-код

## Базовый класс контроллера

Вынесите общую логику в абстрактный базовый класс:

```dart
abstract class BaseController<S> with ChangeNotifier {
  S _state;
  S get state => _state;

  BaseController(this._state);

  @protected
  void setState(S newState) {
    if (identical(_state, newState)) return;
    _state = newState;
    notifyListeners();
    ControllerObserver.instance.onStateChanged(this, _state);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
```

Все конкретные контроллеры наследуют его и содержат только бизнес-методы.

## Key Takeaways / Ключевые выводы

1. Три состояния: **Idle / Processing / Failed** -- покрывают 99% кейсов
2. **Не создавайте** InitialState, SuccessState, LoadingState
3. ChangeNotifier лучше StreamController для Flutter
4. `@protected` для setState -- только контроллер меняет свой стейт
5. **Никогда не rethrow** -- ошибки не должны лететь в виджеты
6. **Mutex** для конкурентности -- один на контроллер
7. **onSuccess/onError callbacks** -- привязка действия к результату
8. **runZoneGuarded** -- ловит ошибки, которые try-catch пропускает
9. **ControllerObserver** -- централизованное логирование и обработка ошибок
10. **Никаких Flutter-импортов** в контроллерах (кроме foundation)
