---
name: state-management
description: Use when implementing BLoC pattern, creating events/states with sealed classes, setting up state machine (Idle/Processing/Success/Error), handle() pattern, BlocObserver, or testing BLoC. MUST use for ANY BLoC creation, state management setup, or BLoC testing in Flutter.
---

# State Management / Управление состоянием (BLoC)

## BLoC как конечный автомат (State Machine)

BLoC — конечный автомат. Принимает события (Events), меняет состояние (State), уведомляет подписчиков. Используй кастомную реализацию с миксинами `SetStateMixin` (для `setState()`) и `BlocController` (для `handle()`).

## Sealed Class States / Состояния через sealed class

### Четыре состояния -- и не больше

Используй только четыре состояния: Idle / Processing / Success / Error. Этого достаточно для 99% кейсов.

```dart
sealed class UserProfileState {
  const UserProfileState({this.data});

  /// Данные доступны в любом состоянии -- не теряются при переходах
  final UserProfile? data;
}

class UserProfileState$Idle extends UserProfileState {
  const UserProfileState$Idle({super.data});
}

class UserProfileState$Processing extends UserProfileState {
  const UserProfileState$Processing({super.data});
}

class UserProfileState$Success extends UserProfileState {
  const UserProfileState$Success({super.data});
}

class UserProfileState$Error extends UserProfileState {
  const UserProfileState$Error({
    super.data,
    required this.error,
    required this.errorType,
  });

  final Object error;
  final UserProfileErrorType errorType;
}
```

### Именование состояний

Формат: `{Feature}State${Status}`

```dart
// Правильно:
UserProfileState$Idle
UserProfileState$Processing
UserProfileState$Success
UserProfileState$Error

// Неправильно:
UserProfileIdleState
IdleUserProfileState
UserProfileInitialState
```

### Anti-pattern: множество состояний

Не создавай InitialState, SuccessState, LoadingState. Не создавай миллионы различных стейтов в зависимости от метода. Не делай SuccessfullyCreated или CreatingState.

- **Idle** (простаивает) -- готов к обработке
- **Processing** (обрабатывает) -- выполняет операцию
- **Success** (успех) -- операция завершена успешно
- **Error** (ошибка) -- произошла ошибка

`data` остаётся в каждом состоянии (не теряется при переходах).

### Initial state

Initial -- это **не отдельный state**, а просто Idle с начальными данными:

```dart
// Initial -- это просто Idle
UserProfileState get initialState =>
    const UserProfileState$Idle(data: null);
```

### ErrorType для идентификации операции

```dart
enum UserProfileErrorType {
  fetch,
  update,
  delete,
}

class UserProfileState$Error extends UserProfileState {
  const UserProfileState$Error({
    super.data,
    required this.error,
    required this.errorType,
  });

  final Object error;

  /// Позволяет определить, какая операция вызвала ошибку
  final UserProfileErrorType errorType;
}
```

Это позволяет UI показать правильное сообщение об ошибке:

```dart
BlocBuilder<UserProfileBloc, UserProfileState>(
  builder: (context, state) {
    if (state is UserProfileState$Error) {
      return switch (state.errorType) {
        UserProfileErrorType.fetch => const Text('Не удалось загрузить профиль'),
        UserProfileErrorType.update => const Text('Не удалось обновить профиль'),
        UserProfileErrorType.delete => const Text('Не удалось удалить профиль'),
      };
    }
    // ...
  },
)
```

## Sealed Class Events / События через sealed class

### Структура событий

Создавай события как sealed class с named constructors и приватными реализациями:

```dart
sealed class UserProfileEvent {
  const UserProfileEvent();

  /// Загрузить профиль
  const factory UserProfileEvent.fetch({
    required String userId,
  }) = _UserProfileEvent$Fetch;

  /// Обновить профиль
  const factory UserProfileEvent.update({
    required String name,
    required String email,
    VoidCallback? onSuccess,
    void Function(Object error)? onError,
  }) = _UserProfileEvent$Update;

  /// Удалить профиль
  const factory UserProfileEvent.delete({
    VoidCallback? onSuccess,
    void Function(Object error)? onError,
  }) = _UserProfileEvent$Delete;
}

class _UserProfileEvent$Fetch extends UserProfileEvent {
  const _UserProfileEvent$Fetch({required this.userId});
  final String userId;
}

class _UserProfileEvent$Update extends UserProfileEvent {
  const _UserProfileEvent$Update({
    required this.name,
    required this.email,
    this.onSuccess,
    this.onError,
  });
  final String name;
  final String email;
  final VoidCallback? onSuccess;
  final void Function(Object error)? onError;
}

class _UserProfileEvent$Delete extends UserProfileEvent {
  const _UserProfileEvent$Delete({
    this.onSuccess,
    this.onError,
  });
  final VoidCallback? onSuccess;
  final void Function(Object error)? onError;
}
```

### Callbacks в событиях

Передавай callbacks (`onSuccess`, `onError`) **через события** -- это способ связать результат асинхронной операции с конкретным действием пользователя:

```dart
// В виджете:
ElevatedButton(
  onPressed: () => context.read<UserProfileBloc>().add(
    UserProfileEvent.update(
      name: _nameController.text,
      email: _emailController.text,
      onSuccess: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Профиль обновлён!')),
          );
        }
      },
      onError: (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка обновления')),
          );
        }
      },
    ),
  ),
  child: const Text('Сохранить'),
)
```

**Используй callbacks экономно** -- только для навигации и side effects (snackbar, dialog). Для отображения данных используй `BlocBuilder`.

**Важно:** В onSuccess/onError контекст может быть dismounted (асинхронность). Всегда проверяй `context.mounted`.

## BLoC Implementation / Реализация BLoC

### SetStateMixin и BlocController

Используй два миксина:
- `SetStateMixin` -- предоставляет метод `setState()` для изменения состояния
- `BlocController` -- предоставляет метод `handle()` с processing/error/done callbacks

### Реализация SetStateMixin

```dart
/// Миксин для BLoC, предоставляющий метод setState
/// аналогичный setState в StatefulWidget
mixin SetStateMixin<S> on BlocBase<S> {
  /// Устанавливает новое состояние напрямую (без emit)
  void setState(S state) {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state);
  }
}
```

### Реализация BlocController

```dart
/// Миксин с паттерном handle() для стандартизированной обработки
/// событий с processing/error/done
mixin BlocController<E, S> on Bloc<E, S> {
  /// Стандартный обработчик с processing -> action -> done/error
  Future<void> handle(
    Emitter<S> emit, {
    required S Function() processing,
    required S Function(Object error) error,
    required S Function() done,
    required Future<void> Function() action,
  }) async {
    emit(processing());
    try {
      await action();
    } on Object catch (e, stackTrace) {
      emit(error(e));
      onError(e, stackTrace);
    } finally {
      emit(done());
    }
  }
}
```

### Один on<Event> handler с switch expression

Не используй несколько `on` handlers. Один `on<Event>` с switch expression:

```dart
class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState>
    with SetStateMixin, BlocController {
  UserProfileBloc({
    required UserProfileRepository repository,
  })  : _repository = repository,
        super(const UserProfileState$Idle()) {
    on<UserProfileEvent>(_onEvent);
  }

  final UserProfileRepository _repository;

  Future<void> _onEvent(
    UserProfileEvent event,
    Emitter<UserProfileState> emit,
  ) =>
      switch (event) {
        _UserProfileEvent$Fetch e => _fetch(e, emit),
        _UserProfileEvent$Update e => _update(e, emit),
        _UserProfileEvent$Delete e => _delete(e, emit),
      };
```

### Anti-pattern: несколько `on` handlers

> "Ни в коем случае нельзя писать on EventA, on EventB, on EventC. Каждый `on` в BLoC создаёт свой внутренний обработчик с отдельной очередью. Они будут конкурировать за один стейт."

```dart
// ПЛОХО -- несколько on handlers, конкурируют за стейт
on<FetchEvent>(_onFetch);
on<UpdateEvent>(_onUpdate);
on<DeleteEvent>(_onDelete);

// ХОРОШО -- один handler с switch
on<UserProfileEvent>(_onEvent);
```

Один `on<Event>` гарантирует последовательную обработку всех событий -- аналог единого mutex для контроллера.

### Метод handle()

Используй паттерн `handle()` из миксина `BlocController` -- обёртку с processing/error/done:

```dart
Future<void> _fetch(
  _UserProfileEvent$Fetch event,
  Emitter<UserProfileState> emit,
) =>
    handle(
      emit,
      processing: () => UserProfileState$Processing(data: state.data),
      error: (error) => UserProfileState$Error(
        data: state.data,
        error: error,
        errorType: UserProfileErrorType.fetch,
      ),
      done: () => UserProfileState$Idle(data: state.data),
      action: () async {
        final profile = await _repository.fetchProfile(event.userId);
        setState(UserProfileState$Success(data: profile));
      },
    );

Future<void> _update(
  _UserProfileEvent$Update event,
  Emitter<UserProfileState> emit,
) =>
    handle(
      emit,
      processing: () => UserProfileState$Processing(data: state.data),
      error: (error) {
        event.onError?.call(error);
        return UserProfileState$Error(
          data: state.data,
          error: error,
          errorType: UserProfileErrorType.update,
        );
      },
      done: () => UserProfileState$Idle(data: state.data),
      action: () async {
        final updated = await _repository.updateProfile(
          name: event.name,
          email: event.email,
        );
        setState(UserProfileState$Success(data: updated));
        event.onSuccess?.call();
      },
    );

Future<void> _delete(
  _UserProfileEvent$Delete event,
  Emitter<UserProfileState> emit,
) =>
    handle(
      emit,
      processing: () => UserProfileState$Processing(data: state.data),
      error: (error) {
        event.onError?.call(error);
        return UserProfileState$Error(
          data: state.data,
          error: error,
          errorType: UserProfileErrorType.delete,
        );
      },
      done: () => const UserProfileState$Idle(),
      action: () async {
        await _repository.deleteProfile();
        setState(const UserProfileState$Success());
        event.onSuccess?.call();
      },
    );
}
```

### Последовательность переходов состояний

Метод `handle()` гарантирует следующую последовательность:

```
Idle -> Processing -> (action выполняется) -> Success -> Idle
Idle -> Processing -> (ошибка) -> Error -> Idle
```

Данные (`data`) сохраняются во всех переходах, чтобы UI не мерцал.

## BlocProvider для DI / Dependency Injection

```dart
BlocProvider<UserProfileBloc>(
  create: (context) => UserProfileBloc(
    repository: context.read<UserProfileRepository>(),
  ),
  child: const UserProfileScreen(),
)
```

Для нескольких BLoC:

```dart
MultiBlocProvider(
  providers: [
    BlocProvider<UserProfileBloc>(
      create: (context) => UserProfileBloc(
        repository: context.read<UserProfileRepository>(),
      ),
    ),
    BlocProvider<SettingsBloc>(
      create: (context) => SettingsBloc(
        repository: context.read<SettingsRepository>(),
      ),
    ),
  ],
  child: const MainScreen(),
)
```

## BlocBuilder, BlocListener, BlocConsumer / Работа с UI

### BlocBuilder -- перестроение UI

```dart
BlocBuilder<UserProfileBloc, UserProfileState>(
  builder: (context, state) => switch (state) {
    UserProfileState$Idle(:final data) when data != null =>
      ProfileView(profile: data),
    UserProfileState$Processing() =>
      const CircularProgressIndicator(),
    UserProfileState$Success(:final data) when data != null =>
      ProfileView(profile: data),
    UserProfileState$Error(:final error, :final data) =>
      Column(
        children: [
          if (data != null) ProfileView(profile: data),
          Text('Ошибка: $error'),
        ],
      ),
    _ => const Text('Загрузите профиль'),
  },
)
```

### BlocListener -- side effects

```dart
BlocListener<UserProfileBloc, UserProfileState>(
  listener: (context, state) {
    if (state is UserProfileState$Error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${state.error}')),
      );
    }
  },
  child: const ProfileView(),
)
```

### BlocConsumer -- builder + listener

```dart
BlocConsumer<UserProfileBloc, UserProfileState>(
  listener: (context, state) {
    if (state is UserProfileState$Success) {
      // Side effect -- показать snackbar
    }
  },
  builder: (context, state) {
    // Перестроить UI
    return ProfileView(state: state);
  },
)
```

## BlocObserver / Централизованное логирование

Используй BlocObserver для централизованного логирования всех изменений состояний и ошибок:

```dart
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    debugPrint('BLoC created: ${bloc.runtimeType}');
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    debugPrint('${bloc.runtimeType}: ${change.currentState.runtimeType} -> ${change.nextState.runtimeType}');
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    debugPrint('${bloc.runtimeType} event: ${event.runtimeType}');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    // Sentry, аналитика
    debugPrint('${bloc.runtimeType} error: $error');
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    debugPrint('BLoC closed: ${bloc.runtimeType}');
  }
}
```

Регистрируй при старте приложения:

```dart
void main() {
  Bloc.observer = const AppBlocObserver();
  runApp(const App());
}
```

### Пример логов

```
UserProfileBloc event: _UserProfileEvent$Fetch
UserProfileBloc: UserProfileState$Idle -> UserProfileState$Processing
UserProfileBloc: UserProfileState$Processing -> UserProfileState$Success
UserProfileBloc: UserProfileState$Success -> UserProfileState$Idle
```

## No Flutter Imports in BLoC

Не импортируй Flutter в BLoC. Никаких импортов Flutter вообще, без исключений.

Единственные допустимые исключения:
- `flutter/foundation.dart` -- аннотации (`@protected`, `@immutable`), `VoidCallback`

Запрещено:
- `BuildContext`
- Любые виджеты
- `Navigator`
- `Color`
- Любой UI-код
- UI-контроллеры (`TextEditingController`, `ScrollController` и т.д.)

## No BLoC-to-BLoC Interactions

Не связывай BLoC'и друг с другом. BLoC не должен знать о других BLoC. Организуй взаимодействие **снаружи**, на уровне UI или специального координатора:

```dart
// ПЛОХО -- BLoC знает о другом BLoC
class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  UserProfileBloc({required this.settingsBloc}); // НЕТ!
  final SettingsBloc settingsBloc;
}

// ХОРОШО -- взаимодействие на уровне UI
BlocListener<UserProfileBloc, UserProfileState>(
  listener: (context, state) {
    if (state is UserProfileState$Success) {
      context.read<SettingsBloc>().add(
        const SettingsEvent.refresh(),
      );
    }
  },
  child: const SizedBox.shrink(),
)
```

---

## Тестирование BLoC

> Тестирование — важная часть работы с BLoC. Ниже приведены паттерны и примеры.

### Принцип: без blocTest

Тестируй BLoC **без** `blocTest` из пакета `flutter_bloc_test`. Используй стандартный подход: `expectLater` + `emitsInOrder`.

### Настройка тестов

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([UserProfileRepository])
void main() {
  late MockUserProfileRepository mockRepository;
  late UserProfileBloc bloc;

  setUp(() {
    mockRepository = MockUserProfileRepository();
    bloc = UserProfileBloc(repository: mockRepository);
  });

  tearDown(() {
    bloc.close(); // ОБЯЗАТЕЛЬНО закрывай BLoC в tearDown!
  });
```

### Arrange-Act-Assert паттерн

```dart
  test('fetch emits Processing -> Success -> Idle', () {
    // Arrange
    final profile = UserProfile(id: '1', name: 'Test', email: 'test@test.com');
    when(mockRepository.fetchProfile('1'))
        .thenAnswer((_) async => profile);

    // Assert (подписывайся ДО действия)
    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<UserProfileState$Processing>(),
        isA<UserProfileState$Success>()
            .having((s) => s.data, 'data', profile),
        isA<UserProfileState$Idle>()
            .having((s) => s.data, 'data', profile),
      ]),
    );

    // Act
    bloc.add(const UserProfileEvent.fetch(userId: '1'));
  });
```

### Тестирование ошибок

```dart
  test('fetch error emits Processing -> Error -> Idle', () {
    // Arrange
    when(mockRepository.fetchProfile('1'))
        .thenThrow(Exception('Network error'));

    // Assert
    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<UserProfileState$Processing>(),
        isA<UserProfileState$Error>()
            .having((s) => s.errorType, 'errorType', UserProfileErrorType.fetch)
            .having((s) => s.error, 'error', isA<Exception>()),
        isA<UserProfileState$Idle>(),
      ]),
    );

    // Act
    bloc.add(const UserProfileEvent.fetch(userId: '1'));
  });
```

### Проверка полей с .having()

```dart
  test('update preserves data on error', () {
    final existingProfile = UserProfile(id: '1', name: 'Old', email: 'old@test.com');

    // Устанавливай начальное состояние через fetch
    when(mockRepository.fetchProfile('1'))
        .thenAnswer((_) async => existingProfile);
    when(mockRepository.updateProfile(name: 'New', email: 'new@test.com'))
        .thenThrow(Exception('Server error'));

    expectLater(
      bloc.stream,
      emitsInOrder([
        // fetch sequence
        isA<UserProfileState$Processing>(),
        isA<UserProfileState$Success>()
            .having((s) => s.data?.name, 'name', 'Old'),
        isA<UserProfileState$Idle>(),
        // update sequence -- данные сохраняются при ошибке
        isA<UserProfileState$Processing>()
            .having((s) => s.data?.name, 'name', 'Old'),
        isA<UserProfileState$Error>()
            .having((s) => s.data?.name, 'name', 'Old')
            .having((s) => s.errorType, 'errorType', UserProfileErrorType.update),
        isA<UserProfileState$Idle>()
            .having((s) => s.data?.name, 'name', 'Old'),
      ]),
    );

    bloc.add(const UserProfileEvent.fetch(userId: '1'));
    bloc.add(const UserProfileEvent.update(name: 'New', email: 'new@test.com'));
  });
```

### Тестирование взаимодействия нескольких BLoC с StreamGroup

```dart
import 'package:async/async.dart';

  test('deleting profile refreshes settings', () {
    final settingsBloc = SettingsBloc(repository: mockSettingsRepository);
    addTearDown(() => settingsBloc.close());

    when(mockRepository.deleteProfile()).thenAnswer((_) async {});
    when(mockSettingsRepository.refresh()).thenAnswer((_) async => defaultSettings);

    // Объединяй стримы для проверки порядка
    final merged = StreamGroup.merge([
      bloc.stream.map((s) => ('profile', s)),
      settingsBloc.stream.map((s) => ('settings', s)),
    ]);

    expectLater(
      merged,
      emitsInOrder([
        predicate<(String, Object)>((r) =>
            r.$1 == 'profile' && r.$2 is UserProfileState$Processing),
        predicate<(String, Object)>((r) =>
            r.$1 == 'profile' && r.$2 is UserProfileState$Success),
        predicate<(String, Object)>((r) =>
            r.$1 == 'profile' && r.$2 is UserProfileState$Idle),
        // Settings обновляются после удаления профиля
        predicate<(String, Object)>((r) =>
            r.$1 == 'settings' && r.$2 is SettingsState$Processing),
        predicate<(String, Object)>((r) =>
            r.$1 == 'settings' && r.$2 is SettingsState$Success),
        predicate<(String, Object)>((r) =>
            r.$1 == 'settings' && r.$2 is SettingsState$Idle),
      ]),
    );

    bloc.add(UserProfileEvent.delete(
      onSuccess: () => settingsBloc.add(const SettingsEvent.refresh()),
    ));
  });
```

### Тестирование callbacks

```dart
  test('onSuccess callback is called on successful update', () async {
    var successCalled = false;

    when(mockRepository.updateProfile(name: 'New', email: 'new@test.com'))
        .thenAnswer((_) async => UserProfile(id: '1', name: 'New', email: 'new@test.com'));

    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<UserProfileState$Processing>(),
        isA<UserProfileState$Success>(),
        isA<UserProfileState$Idle>(),
      ]),
    );

    bloc.add(UserProfileEvent.update(
      name: 'New',
      email: 'new@test.com',
      onSuccess: () => successCalled = true,
    ));

    await bloc.stream.firstWhere((s) => s is UserProfileState$Idle);
    expect(successCalled, isTrue);
  });

  test('onError callback is called on failed update', () async {
    Object? receivedError;

    when(mockRepository.updateProfile(name: 'New', email: 'new@test.com'))
        .thenThrow(Exception('Server error'));

    bloc.add(UserProfileEvent.update(
      name: 'New',
      email: 'new@test.com',
      onError: (error) => receivedError = error,
    ));

    await bloc.stream.firstWhere((s) => s is UserProfileState$Idle);
    expect(receivedError, isA<Exception>());
  });
}
```

## Key Takeaways / Ключевые выводы

1. Используй четыре состояния: **Idle / Processing / Success / Error** -- покрывают 99% кейсов
2. **Не создавай** InitialState, LoadingState, SuccessfullyCreatedState
3. Именование: `{Feature}State${Status}` (например, `UserProfileState$Idle`)
4. **Один `on<Event>`** с switch expression -- НЕ несколько `on` handlers
5. `handle()` -- единый паттерн обработки с processing/error/done
6. **Callbacks в событиях** -- для навигации и side effects (используй экономно)
7. `ErrorType` enum -- идентификация, какая операция вызвала ошибку
8. **Данные сохраняются** во всех переходах состояний (`data` в base class)
9. **BlocObserver** -- централизованное логирование и обработка ошибок
10. **Никаких Flutter-импортов** в BLoC (кроме foundation)
11. **Никаких BLoC-to-BLoC** взаимодействий внутри BLoC
12. Тестируй через `expectLater` + `emitsInOrder`, **без blocTest**
13. Используй `isA<Type>().having()` для проверки полей в тестах
14. `StreamGroup` для тестирования взаимодействия нескольких BLoC
15. **Всегда закрывай** BLoC в `tearDown`
