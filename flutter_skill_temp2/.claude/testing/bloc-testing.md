# Тестирование BLoC в Health Flutter

> Применяется к файлам в **/test/bloc/**/\*\_test.dart

## Подход к тестированию BLoC

Можно считать что это и есть Unit-test, считая что юнит тесты покрывают бизнес логику, в нашем темплейте это BLoC

В проекте BLoC тестируется **без использования библиотеки `flutter_bloc`** (без `blocTest`).

Используется подход:

- **Mockito** для мокирования репозиториев
- **`expectLater`** + **`emitsInOrder`** для проверки последовательности состояний
- **`isA<Type>()`** + **`.having()`** для проверки полей состояний
- **`StreamGroup`** для тестирования взаимодействия нескольких блоков

## Структура тестов

### 1. Подготовка моков

Создай файл `test/helpers/test_helper.dart`:

```dart
import 'package:auth/auth.dart';
import 'package:history_entries/src/domain/repositories/history_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:user_profile/user_profile.dart';

@GenerateNiceMocks([
  MockSpec<UserProfileRepository>(),
  MockSpec<AuthRepository<Object>>(),
  MockSpec<HistoryRepository>(),
])
void main() {}
```

Запусти генерацию моков:

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

### 2. Базовая структура теста

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:template_flutter_claude/src/feature/user_profile/user_profile.dart';

import 'package:template_flutter_claude/test/helpers/test_helper.mocks.dart';

void main() {
  late MockUserProfileRepository mockUserProfileRepository;
  late MockAuthRepository mockAuthRepository;
  late UserProfileBloc userProfileBloc;

  setUp(() {
    mockUserProfileRepository = MockUserProfileRepository();
    mockAuthRepository = MockAuthRepository();

    userProfileBloc = UserProfileBloc(
      userProfileRepository: mockUserProfileRepository,
      authRepository: mockAuthRepository,
    );
  });

  tearDown(() {
    userProfileBloc.close();
  });

  // Тесты здесь
}
```

## Примеры тестов

### Успешная загрузка данных

```dart
group('Fetch profile tests', () {
  const userProfileEntity = UserProfileEntity(
    id: 1,
    name: 'TestName',
    email: 'test@mail.ru',
  );

  test('Success fetch profile', () async {
    // Arrange: настраиваем мок
    when(mockUserProfileRepository.fetchUserProfile())
        .thenAnswer((_) async => userProfileEntity);

    // Act: отправляем событие
    userProfileBloc.add(const UserProfileEvent.fetch());

    // Assert: проверяем последовательность состояний
    await expectLater(
      userProfileBloc.stream,
      emitsInOrder([
        isA<UserProfileState$Processing>(),
        isA<UserProfileState$Success>().having(
          (s) => s.data,
          'Successfully fetch data',
          userProfileEntity,
        ),
      ]),
    );
  });
});
```

### Обработка ошибок

```dart
test('Error fetch profile', () async {
  // Arrange: мокируем ошибку
  when(mockUserProfileRepository.fetchUserProfile())
      .thenThrow(Exception('User profile exception'));

  // Act
  userProfileBloc.add(const UserProfileEvent.fetch());

  // Assert
  await expectLater(
    userProfileBloc.stream,
    emitsInOrder([
      isA<UserProfileState$Processing>(),
      isA<UserProfileState$Error>().having(
        (s) => s.error.toString(),
        'Error fetch data',
        contains('User profile exception'),
      ),
    ]),
  );
});
```

### Обновление с последующей загрузкой

```dart
group('Update profile tests', () {
  const updatedName = 'Updated testName';
  const updatedCountry = 'Niger';

  const updatedProfileEntity = UserProfileEntity(
    id: 1,
    name: 'Updated testName',
    email: 'test@mail.ru',
    country: 'Niger',
  );

  test('Success update profile', () async {
    // Arrange
    when(
      mockUserProfileRepository.updateProfile(
        name: updatedName,
        country: updatedCountry,
      ),
    ).thenAnswer((_) async {});

    when(mockUserProfileRepository.fetchUserProfile())
        .thenAnswer((_) async => updatedProfileEntity);

    // Act: обновляем и затем делаем fetch в onSuccess
    userProfileBloc.add(
      UserProfileEvent.updateProfile(
        name: updatedName,
        country: updatedCountry,
        onSuccess: () {
          userProfileBloc.add(const UserProfileEvent.fetch());
        },
      ),
    );

    // Assert: проверяем переход success -> idle -> processing -> success
    await expectLater(
      userProfileBloc.stream,
      emitsInOrder([
        isA<UserProfileState$Success>(),
        isA<UserProfileState$Idle>(),
        // После вызова fetch в onSuccess
        isA<UserProfileState$Processing>(),
        isA<UserProfileState$Success>().having(
          (s) => s.data,
          'Successfully update data',
          updatedProfileEntity,
        ),
      ]),
    );
  });

  test('Error update profile', () async {
    // Arrange
    when(
      mockUserProfileRepository.updateProfile(
        name: updatedName,
        country: updatedCountry,
      ),
    ).thenThrow(Exception('User update profile exception'));

    // Act
    userProfileBloc.add(
      UserProfileEvent.updateProfile(
        name: updatedName,
        country: updatedCountry,
        onSuccess: () {},
      ),
    );

    // Assert
    await expectLater(
      userProfileBloc.stream,
      emitsInOrder([
        isA<UserProfileState$Error>().having(
          (s) => s.error.toString(),
          'Error update data',
          contains('User update profile exception'),
        ),
      ]),
    );
  });
});
```

## Тестирование нескольких блоков

Когда нужно проверить взаимодействие нескольких блоков (например, очистка данных после удаления профиля), используй **`StreamGroup`** из пакета `async`:

```dart
import 'package:async/async.dart';
import 'package:flutter/services.dart';

test('Success delete profile with clearing related data', () async {
  // Arrange: создаем дополнительные блоки
  final historyEntryData = HistoryEntry(
    id: 1,
    date: DateTime.now(),
    createdAt: DateTime.now(),
    imageSets: [
      ImageSet(
        id: 2,
        historyEntryId: 1,
        createdAt: DateTime.now(),
        images: [Uint8List(10)],
      ),
    ],
    workoutsCount: 2,
  );

  final workOutStreak = WorkoutStreak(
    id: 1,
    currentStreak: 1,
    maxStreak: 2,
    totalWorkoutDays: 3,
    isActive: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final historyEntryBloc = HistoryEntryBloc(
    historyRepository: mockHistoryRepository,
    initialState: HistoryEntryState$Idle(data: historyEntryData),
  );

  final historyEntriesBloc = HistoryEntriesBloc(
    historyRepository: mockHistoryRepository,
    initialState: HistoryEntriesState$Idle(
      data: [historyEntryData],
      hasReachedMax: false,
      currentPage: 0,
    ),
  );

  final workoutStreakBloc = WorkoutStreakBloc(
    historyRepository: mockHistoryRepository,
    initialState: WorkoutStreakState$Idle(data: workOutStreak),
  );

  when(mockUserProfileRepository.deleteUserProfile())
      .thenAnswer((_) async {});

  // Act: создаем группу стримов
  final streamGroup = StreamGroup<dynamic>();

  // Подписываемся на потоки всех блоков
  await streamGroup.add(userProfileBloc.stream);
  await streamGroup.add(historyEntriesBloc.stream);
  await streamGroup.add(historyEntryBloc.stream);
  await streamGroup.add(workoutStreakBloc.stream);

  // Отправляем событие с последовательной очисткой данных
  userProfileBloc.add(
    UserProfileEvent.deleteProfile(
      onSuccess: () {
        historyEntriesBloc.add(const HistoryEntriesEvent.clearHistoryData());
        historyEntryBloc.add(const HistoryEntryEvent.clearHistoryEntryData());
        workoutStreakBloc.add(const WorkoutStreakEvent.clearStreak());
      },
    ),
  );

  // Assert: проверяем события во всех блоках
  await expectLater(
    streamGroup.stream,
    emitsInOrder([
      // События UserProfileBloc
      isA<UserProfileState$Processing>(),
      isA<UserProfileState$Success>(),
      isA<UserProfileState$Idle>(),

      // Чистим HistoryEntriesEvent.clearHistoryData
      isA<HistoryEntriesState$Idle>().having(
        (s) => s.data.length,
        'Delete all history from entries bloc',
        0,
      ),

      // Чистим HistoryEntryEvent.clearHistoryEntryData()
      isA<HistoryEntryState$Success>().having(
        (s) => s.data,
        'Delete all history from entry bloc',
        null,
      ),

      // Чистим стрик WorkoutStreakEvent.clearStreak()
      isA<WorkoutStreakState$Success>().having(
        (s) => s.data,
        'Delete all streak data from workout bloc',
        null,
      ),
    ]),
  );

  // Cleanup
  await streamGroup.close();
  await historyEntryBloc.close();
  await historyEntriesBloc.close();
  await workoutStreakBloc.close();
});
```

## Тестирование с callback'ами

Для событий с `onSuccess` или `onComplete`:

```dart
test('Success sign out', () async {
  // Arrange
  when(mockUserProfileRepository.revokeToken())
      .thenAnswer((_) async {});

  final streamGroup = StreamGroup<dynamic>();
  await streamGroup.add(userProfileBloc.stream);
  await streamGroup.add(historyEntriesBloc.stream);

  // Act
  userProfileBloc.add(
    UserProfileEvent.signOut(
      onSuccess: () {
        // Вызываем очистку данных в callback
        historyEntriesBloc.add(const HistoryEntriesEvent.clearHistoryData());
      },
    ),
  );

  // Assert
  await expectLater(
    streamGroup.stream,
    emitsInOrder([
      isA<UserProfileState$Processing>(),
      isA<UserProfileState$Success>(),
      isA<UserProfileState$Idle>(),
      isA<HistoryEntriesState$Idle>().having(
        (s) => s.data.length,
        'Delete all history',
        0,
      ),
    ]),
  );

  await streamGroup.close();
});
```

## Правила тестирования

### ✅ Используй

1. **`emitsInOrder`** - для проверки последовательности состояний

   ```dart
   await expectLater(
     bloc.stream,
     emitsInOrder([state1, state2, state3]),
   );
   ```

2. **`isA<Type>()`** - для проверки типа состояния

   ```dart
   isA<UserProfileState$Success>()
   ```

3. **`.having()`** - для проверки конкретных полей

   ```dart
   isA<UserProfileState$Success>().having(
     (s) => s.data,
     'Description',
     expectedValue,
   )
   ```

4. **`contains()`** - для проверки текста ошибки

   ```dart
   isA<UserProfileState$Error>().having(
     (s) => s.error.toString(),
     'Error message',
     contains('expected text'),
   )
   ```

5. **`when().thenAnswer()`** - для мокирования асинхронных вызовов

   ```dart
   when(mockRepository.method()).thenAnswer((_) async => result);
   ```

6. **`when().thenThrow()`** - для мокирования ошибок

   ```dart
   when(mockRepository.method()).thenThrow(Exception('Error'));
   ```

7. **`StreamGroup`** - для тестирования нескольких блоков
   ```dart
   final streamGroup = StreamGroup<dynamic>();
   await streamGroup.add(bloc1.stream);
   await streamGroup.add(bloc2.stream);
   // ...
   await streamGroup.close();
   ```

### ❌ НЕ используй

1. ❌ **`blocTest`** - не используется в проекте (из `flutter_bloc`)

   ```dart
   // ❌ НЕ ТАК
   blocTest<UserProfileBloc, UserProfileState>(
     'test',
     build: () => bloc,
     act: (bloc) => bloc.add(event),
     expect: () => [state1, state2],
   );
   ```

2. ❌ **`when(() => mock.method())`** - используй классический синтаксис mockito

   ```dart
   // ❌ НЕ ТАК
   when(() => mockRepository.method()).thenAnswer((_) async => result);

   // ✅ ТАК
   when(mockRepository.method()).thenAnswer((_) async => result);
   ```

3. ❌ **Прямое сравнение состояний** - используй `isA<>().having()`

   ```dart
   // ❌ НЕ ТАК
   expect(state, UserProfileState.success(data: user));

   // ✅ ТАК
   isA<UserProfileState$Success>().having((s) => s.data, 'data', user)
   ```

4. ❌ **`verify()`** - не нужен для BLoC тестов (используется для проверки вызовов методов)

### Шаблон теста

```dart
test('Description', () async {
  // Arrange: настраиваем моки и начальное состояние
  when(mockRepository.method()).thenAnswer((_) async => result);

  // Act: отправляем событие
  bloc.add(const Event());

  // Assert: проверяем последовательность состояний
  await expectLater(
    bloc.stream,
    emitsInOrder([
      isA<State$Type1>(),
      isA<State$Type2>().having(
        (s) => s.field,
        'Description',
        expectedValue,
      ),
    ]),
  );
});
```

## Структура тестового файла

```dart
import 'package:async/async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:template_flutter_claude/src/feature/user_profile/user_profile.dart';

import 'package:template_flutter_claude/test/helpers/test_helper.mocks.dart';

void main() {
  late MockUserProfileRepository mockUserProfileRepository;
  late MockAuthRepository mockAuthRepository;
  late UserProfileBloc userProfileBloc;

  setUp(() {
    mockUserProfileRepository = MockUserProfileRepository();
    mockAuthRepository = MockAuthRepository();

    userProfileBloc = UserProfileBloc(
      userProfileRepository: mockUserProfileRepository,
      authRepository: mockAuthRepository,
    );
  });

  tearDown(() {
    userProfileBloc.close();
  });

  group('Fetch profile tests', () {
    // Тесты на загрузку
  });

  group('Update profile tests', () {
    // Тесты на обновление
  });

  group('Delete profile tests', () {
    // Тесты на удаление
  });

  group('Sign out from profile tests', () {
    // Тесты на выход
  });
}
```

## Чеклист тестирования BLoC

- [ ] Создан `test_helper.dart` с моками
- [ ] Запущена генерация моков через `build_runner`
- [ ] Добавлен `setUp()` с инициализацией блока
- [ ] Добавлен `tearDown()` с `bloc.close()`
- [ ] Тесты сгруппированы через `group()`
- [ ] Используется паттерн Arrange-Act-Assert
- [ ] Проверяется последовательность состояний через `emitsInOrder`
- [ ] Используется `isA<>().having()` для проверки полей
- [ ] Обработаны как успешные, так и ошибочные сценарии
- [ ] Для множественных блоков используется `StreamGroup`
- [ ] Все блоки закрываются в `tearDown()`

## Best Practices

1. ✅ **Один тест - один сценарий**: не тестируй несколько разных событий в одном тесте
2. ✅ **Arrange-Act-Assert**: структурируй тесты по этому паттерну
3. ✅ **Описательные названия**: название теста должно описывать проверяемый сценарий
4. ✅ **Группировка**: используй `group()` для логического разделения тестов
5. ✅ **Cleanup**: всегда закрывай блоки в `tearDown()`
6. ✅ **Изоляция**: каждый тест должен быть независим от других
7. ✅ **Покрытие**: тестируй как успешные, так и ошибочные сценарии

## Запуск тестов

```bash
# Все тесты
fvm flutter test

# Конкретный файл
fvm flutter test test/bloc/user_profile_bloc_test.dart

# С покрытием
fvm flutter test --coverage

# Через Makefile
make test
```
