# BLoC Pattern для Health Flutter

> Применяется к файлам в **/bloc/**/\*.dart

## Архитектура BLoC в проекте

В проекте за State Manager отвечат паттерн BLoC, который представляет из себя state machine

В проекте используется кастомная реализация BLoC с миксинами:

- `SetStateMixin` - упрощает emit состояний через `setState()`
- `BlocController` - предоставляет метод `handle()` для обработки ошибок

## Структура BLoC

### 1. Events (Sealed Class)

```dart
/// {@template user_profile_event}
/// События для управления профилем пользователя.
/// {@endtemplate}
sealed class UserProfileEvent {
  const UserProfileEvent();

  /// Загрузить профиль
  const factory UserProfileEvent.fetch({
    void Function(UserProfileEntity user)? onComplete,
  }) = _FetchProfileEvent;

  /// Обновить профиль
  const factory UserProfileEvent.update({
    required String name,
    required String country,
    VoidCallback? onSuccess,
  }) = _UpdateProfileEvent;

  /// Удалить профиль
  const factory UserProfileEvent.delete({
    required VoidCallback onSuccess,
  }) = _DeleteProfileEvent;
}

// Имплементации событий
final class _FetchProfileEvent extends UserProfileEvent {
  const _FetchProfileEvent({this.onComplete});

  final void Function(UserProfileEntity user)? onComplete;
}

final class _UpdateProfileEvent extends UserProfileEvent {
  const _UpdateProfileEvent({
    required this.name,
    required this.country,
    this.onSuccess,
  });

  final String name;
  final String country;
  final VoidCallback? onSuccess;
}

final class _DeleteProfileEvent extends UserProfileEvent {
  const _DeleteProfileEvent({required this.onSuccess});

  final VoidCallback onSuccess;
}
```

### 2. States (Sealed Class)

```dart
/// {@template user_profile_state}
/// Состояния профиля пользователя.
/// {@endtemplate}
sealed class UserProfileState {
  const UserProfileState({required this.data});

  /// Данные состояния
  final UserProfileEntity? data;

  /// Idle - состояние покоя
  const factory UserProfileState.idle({
    required UserProfileEntity? data,
  }) = UserProfileState$Idle;

  /// Processing - обработка запроса
  const factory UserProfileState.processing({
    required UserProfileEntity? data,
  }) = UserProfileState$Processing;

  /// Success - успешное выполнение
  const factory UserProfileState.success({
    required UserProfileEntity? data,
  }) = UserProfileState$Success;

  /// Error - ошибка
  const factory UserProfileState.error({
    required UserProfileEntity? data,
    required Object error,
    required UserProfileStateEnum errorType,
  }) = UserProfileState$Error;

  /// Получить ошибку если состояние error
  Object? get error => switch (this) {
    final UserProfileState$Error e => e.error,
    _ => null,
  };
}

// Имплементации состояний
final class UserProfileState$Idle extends UserProfileState {
  const UserProfileState$Idle({required super.data});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfileState$Idle && other.data == data;
  }

  @override
  int get hashCode => Object.hashAll([data]);

  @override
  String toString() => 'UserProfileState\$Idle(data: $data)';
}

final class UserProfileState$Processing extends UserProfileState {
  const UserProfileState$Processing({required super.data});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfileState$Processing && other.data == data;
  }

  @override
  int get hashCode => Object.hashAll([data]);

  @override
  String toString() => 'UserProfileState\$Processing(data: $data)';
}

final class UserProfileState$Success extends UserProfileState {
  const UserProfileState$Success({required super.data});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfileState$Success && other.data == data;
  }

  @override
  int get hashCode => Object.hashAll([data]);

  @override
  String toString() => 'UserProfileState\$Success(data: $data)';
}

final class UserProfileState$Error extends UserProfileState {
  const UserProfileState$Error({
    required super.data,
    required this.error,
    required this.errorType,
  });

  @override
  final Object error;
  final UserProfileStateEnum errorType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfileState$Error &&
        other.data == data &&
        other.error == error &&
        other.errorType == errorType;
  }

  @override
  int get hashCode => Object.hashAll([data, error, errorType]);

  @override
  String toString() => 'UserProfileState\$Error(data: $data, error: $error)';
}

/// Типы ошибок профиля
enum UserProfileStateEnum {
  fetchProfile,
  updateProfile,
  deleteProfile,
}
```

### 3. BLoC с миксинами

```dart
/// {@template user_profile_bloc}
/// BLoC для управления профилем пользователя.
/// {@endtemplate}
final class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState>
    with SetStateMixin, BlocController {
  /// {@macro user_profile_bloc}
  UserProfileBloc({
    required UserProfileRepository userProfileRepository,
    required AuthRepository authRepository,
    UserProfileState? initialState,
  })  : _userProfileRepository = userProfileRepository,
        _authRepository = authRepository,
        super(
          initialState ??
              const UserProfileState.processing(
                data: null,
              ),
        ) {
    // Регистрация обработчиков событий
    on<UserProfileEvent>(
      (event, emit) => switch (event) {
        final _FetchProfileEvent e => _fetchProfile(event: e, emit: emit),
        final _UpdateProfileEvent e => _updateProfile(event: e, emit: emit),
        final _DeleteProfileEvent e => _deleteProfile(event: e, emit: emit),
      },
    );
  }

  final UserProfileRepository _userProfileRepository;
  final AuthRepository _authRepository;

  /// Загрузка профиля
  Future<void> _fetchProfile({
    required _FetchProfileEvent event,
    required Emitter<UserProfileState> emit,
  }) async =>
      handle(
        processing: () async {
          setState(UserProfileState.processing(data: state.data));

          final userProfile = await _userProfileRepository.fetchUserProfile();

          event.onComplete?.call(userProfile);
          setState(UserProfileState.success(data: userProfile));
        },
        error: (error, stackTrace) async {
          setState(
            UserProfileState.error(
              data: null,
              error: error,
              errorType: UserProfileStateEnum.fetchProfile,
            ),
          );
        },
        done: () async {},
      );

  /// Обновление профиля
  Future<void> _updateProfile({
    required _UpdateProfileEvent event,
    required Emitter<UserProfileState> emit,
  }) async =>
      handle(
        processing: () async {
          await _userProfileRepository.updateProfile(
            name: event.name,
            country: event.country,
          );

          setState(UserProfileState.success(data: state.data));
          event.onSuccess?.call();
        },
        error: (error, stackTrace) async {
          setState(
            UserProfileState.error(
              data: state.data,
              error: error,
              errorType: UserProfileStateEnum.updateProfile,
            ),
          );
          onError(error, stackTrace);
        },
        done: () async {
          setState(UserProfileState.idle(data: state.data));
        },
      );

  /// Удаление профиля
  Future<void> _deleteProfile({
    required _DeleteProfileEvent event,
    required Emitter<UserProfileState> emit,
  }) async =>
      handle(
        processing: () async {
          setState(UserProfileState.processing(data: state.data));

          await _userProfileRepository.deleteUserProfile();
          await _authRepository.clearSessionUser();

          setState(UserProfileState.success(data: state.data));
          event.onSuccess();
        },
        error: (error, stackTrace) async {
          setState(
            UserProfileState.error(
              data: state.data,
              error: error,
              errorType: UserProfileStateEnum.deleteProfile,
            ),
          );
          onError(error, stackTrace);
        },
        done: () async {
          setState(UserProfileState.idle(data: state.data));
        },
      );
}
```

## Правила именования

### Events

- Формат: `{Feature}Event`
- Внутренние классы: `_{Action}{Feature}Event`
- Примеры: `UserProfileEvent.fetch()`, `_FetchProfileEvent`

### States

- Формат: `{Feature}State`
- Подтипы: `{Feature}State${Status}`
- Примеры: `UserProfileState$Idle`, `UserProfileState$Processing`

### BLoC

- Формат: `{Feature}Bloc`
- Примеры: `UserProfileBloc`, `WorkoutBloc`

## Использование в UI

### BlocBuilder

```dart
BlocBuilder<UserProfileBloc, UserProfileState>(
  builder: (context, state) {
    return switch (state) {
      UserProfileState$Idle() => const EmptyState(),
      UserProfileState$Processing() => const CircularProgressIndicator(),
      UserProfileState$Success(:final data) => UserProfileWidget(user: data),
      UserProfileState$Error(:final error) => ErrorWidget(message: error.toString()),
    };
  },
)
```

### BlocListener

```dart
BlocListener<UserProfileBloc, UserProfileState>(
  listener: (context, state) {
    if (state is UserProfileState$Error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error.toString())),
      );
    }

    if (state is UserProfileState$Success) {
      // Navigate or show success message
    }
  },
  child: const UserProfileScreen(),
)
```

### BlocConsumer

```dart
BlocConsumer<UserProfileBloc, UserProfileState>(
  listener: (context, state) {
    // Side effects (navigation, snackbars)
    if (state is UserProfileState$Error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error.toString())),
      );
    }
  },
  builder: (context, state) {
    // UI rendering
    return switch (state) {
      UserProfileState$Idle() => const SizedBox.shrink(),
      UserProfileState$Processing() => const CircularProgressIndicator(),
      UserProfileState$Success(:final data) => UserWidget(user: data),
      UserProfileState$Error() => const ErrorPlaceholder(),
    };
  },
)
```

## Dependency Injection

```dart
BlocProvider(
  create: (context) => UserProfileBloc(
    userProfileRepository: context.read<UserProfileRepository>(),
    authRepository: context.read<AuthRepository>(),
  )..add(const UserProfileEvent.fetch()),
  child: const UserProfileScreen(),
)
```

## Callbacks для навигации

События могут содержать callback'и для навигации и side effects, но применять в крайнем случае!:

```dart
// В UI
ElevatedButton(
  onPressed: () {
    context.read<UserProfileBloc>().add(
      UserProfileEvent.update(
        name: nameController.text,
        country: countryController.text,
        onSuccess: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Профиль обновлен')),
          );
        },
      ),
    );
  },
  child: const Text('Сохранить'),
)
```

## ✅ Best Practices

1. ✅ Используй `sealed class` для Events и States
2. ✅ Всегда указывай тип ошибки через enum
3. ✅ Используй callbacks для навигации и side effects
4. ✅ Документируй события и состояния
5. ✅ Сохраняй предыдущие данные при обработке
6. ✅ Используй миксин `SetStateMixin` для `setState()`
7. ✅ Используй миксин `BlocController` для `handle()`

## 🚫 Что НЕ делать

1. ❌ Не используй BuildContext в BLoC напрямую
2. ❌ Не храни UI контроллеры в BLoC
3. ❌ Не создавай взаимодействия между BLoC внутри BLoC
4. ❌ Не забывай про dispose ресурсов
5. ❌ Не создавай слишком много событий
6. ❌ Не игнорируй ошибки

## 🧪 Тестирование

Подробное руководство по тестированию BLoC смотри в [testing/bloc-testing.md](../testing/bloc-testing.md)
