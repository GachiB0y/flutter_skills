# Создание Feature модулей

## 🎯 Цель документа

Научить создавать **Feature модули** в едином Flutter репозитории:

- Модули с бизнес-логикой конкретного feature
- Обеспечить единую структуру Feature модулей
- Научить правильно организовывать слои (BLoC, Domain, Data, UI)
- Все Feature модули находятся в `lib/src/feature/`

---

## Что такое Feature модуль?

**Feature модуль** - это папка в `lib/src/feature/`, которая:

- **Содержит** бизнес-логику конкретного feature
- **Зависит** от Core модулей (database, rest_client, ui_library)
- **Может зависеть** от других Feature модулей
- **НЕ может** быть зависимостью для Core модулей

### Примеры Feature модулей

- `auth` - авторизация (login, register, logout)
- `home` - главный экран приложения
- `user_profile` - профиль пользователя (view, edit)
- `settings` - настройки приложения
- `workout` - тренировка
- `history` - история

## Структура Feature модуля

```
lib/src/feature/
└── my_feature/
    ├── presentation/
    │   ├── bloc/                    # BLoC логика
    │   │   └── my_feature_bloc.dart
    │   └── widget/                  # UI виджеты
    │       ├── my_feature_screen.dart
    │       └── components/
    ├── domain/                      # Бизнес логика
    │   ├── models/                  # Domain модели (Entities)
    │   │   └── my_entity.dart
    │   └── repositories/            # Интерфейсы репозиториев
    │       └── my_repository.dart
    ├── data/                        # Источники данных
    │   ├── repositories/            # Реализации репозиториев
    │   │   └── my_repository_impl.dart
    │   ├── datasources/             # Remote/Local data sources
    │   │   ├── my_remote_ds.dart
    │   │   └── my_local_ds.dart
    │   └── models/                  # DTOs
    │       └── my_dto.dart
    └── dependencies/                # DI
        └── my_feature_dependencies.dart

# Тесты в отдельной папке
test/src/feature/my_feature/
├── bloc/
│   └── my_feature_bloc_test.dart
├── repositories/
│   └── my_repository_test.dart
└── datasources/
    └── my_remote_ds_test.dart
```

### Импорты в Feature модуле

**Используем полные package импорты:**

```dart
// ✅ ПРАВИЛЬНО - полные package импорты
import 'package:template_flutter_claude/src/core/logger/app_logger.dart';
import 'package:template_flutter_claude/src/core/rest_client/rest_client.dart';
import 'package:template_flutter_claude/src/feature/auth/domain/repositories/auth_repository.dart';
import 'package:template_flutter_claude/src/feature/auth/data/datasources/auth_remote_ds.dart';

// ❌ НЕПРАВИЛЬНО - относительные импорты (не используем!)
import '../../../core/logger/app_logger.dart';
import '../../domain/repositories/auth_repository.dart';
```

# Testing

mocktail: ^1.0.4
bloc_test: ^9.1.7

````

## � Правила работы с модулями

### Правило 1: Структура папок Feature модуля

**Правило:**
Используй структуру: `bloc/`, `domain/`, `data/`, `widget/`, `dependencies/`

**Обоснование:**

- **BLoC слой** (`bloc/`) - вся логика управления состоянием
- **Доменный слой** (`domain/`) - бизнес-модели (Entities) и интерфейсы репозиториев
- **Слой данных** (`data/`) - реализация репозиториев, DTO, data sources (remote/local)
---

## Правила работы с Feature модулями

### Правило 1: Clean Architecture

**Правило:**
Соблюдай разделение на слои:

- **Presentation** (`presentation/`) - BLoC и UI
- **Domain** (`domain/`) - модели и интерфейсы репозиториев
- **Data** (`data/`) - реализации репозиториев и источники данных
- **DI** (`dependencies/`) - регистрация зависимостей

**Обоснование:**
- Четкое разделение ответственности
- Легко тестировать каждый слой отдельно
- Возможность замены реализаций

### Правило 2: Полные package импорты

**Правило:**
Всегда используй полные package импорты

**Обоснование:**
- Явность структуры зависимостей
- Лучшая поддержка IDE
- Автоматический рефакторинг

**Пример:**

```dart
// ✅ ПРАВИЛЬНО
import 'package:template_flutter_claude/src/core/logger/app_logger.dart';
import 'package:template_flutter_claude/src/feature/auth/domain/repositories/auth_repository.dart';

// ❌ НЕПРАВИЛЬНО
import '../../../core/logger/app_logger.dart';
```

---

## 🚀 Быстрый старт

### Создание нового Feature модуля

**Используем Make команду:**

```bash
make create-feature NAME=profile
```

Эта команда автоматически создаст:
- ✅ Полную Clean Architecture структуру
- ✅ BLoC шаблоны (bloc, events, states)
- ✅ Шаблон экрана
- ✅ Структуру тестов
- ✅ README с инструкциями

**Или вручную:**

**Шаг 1**: Создать структуру папок

```bash
mkdir -p lib/src/feature/my_feature/{presentation/{bloc,widget},domain/{models,repositories},data/{models,repositories,datasources},dependencies}
mkdir -p test/src/feature/my_feature/{bloc,repositories,datasources}
````

**Шаг 2**: Создать Domain слой

```dart
// lib/src/feature/my_feature/domain/models/my_entity.dart
class MyEntity {
  const MyEntity({required this.id, required this.name});

  final String id;
  final String name;
}

// lib/src/feature/my_feature/domain/repositories/my_repository.dart
abstract interface class MyRepository {
  Future<MyEntity> fetchById(String id);
  Future<List<MyEntity>> fetchAll();
}
```

**Шаг 3**: Создать Data слой

```dart
// lib/src/feature/my_feature/data/models/my_dto.dart
import 'package:json_annotation/json_annotation.dart';
import 'package:template_flutter_claude/src/feature/my_feature/domain/models/my_entity.dart';

part 'my_dto.g.dart';

@JsonSerializable()
class MyDto {
  const MyDto({required this.id, required this.name});

  final String id;
  final String name;

  factory MyDto.fromJson(Map<String, dynamic> json) => _$MyDtoFromJson(json);
  Map<String, dynamic> toJson() => _$MyDtoToJson(this);

  MyEntity toEntity() => MyEntity(id: id, name: name);
}

// lib/src/feature/my_feature/data/datasources/my_remote_ds.dart
import 'package:template_flutter_claude/src/core/rest_client/rest_client.dart';
import 'package:template_flutter_claude/src/feature/my_feature/data/models/my_dto.dart';

final class MyRemoteDataSource {
  MyRemoteDataSource({required this.restClient});

  final RestClient restClient;

  Future<MyDto> fetchById(String id) async {
    final response = await restClient.get('/api/my-feature/$id');
    return MyDto.fromJson(response.data as Map<String, dynamic>);
  }
}

// lib/src/feature/my_feature/data/repositories/my_repository_impl.dart
import 'package:template_flutter_claude/src/feature/my_feature/domain/models/my_entity.dart';
import 'package:template_flutter_claude/src/feature/my_feature/domain/repositories/my_repository.dart';
import 'package:template_flutter_claude/src/feature/my_feature/data/datasources/my_remote_ds.dart';

final class MyRepositoryImpl implements MyRepository {
  MyRepositoryImpl({required this.remoteDataSource});

  final MyRemoteDataSource remoteDataSource;

  @override
  Future<MyEntity> fetchById(String id) async {
    final dto = await remoteDataSource.fetchById(id);
    return dto.toEntity();
  }

  @override
  Future<List<MyEntity>> fetchAll() async {
    // Implementation
    throw UnimplementedError();
  }
}
```

**Шаг 4**: Создать BLoC

```dart
// lib/src/feature/my_feature/presentation/bloc/my_feature_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:template_flutter_claude/src/feature/my_feature/domain/models/my_entity.dart';
import 'package:template_flutter_claude/src/feature/my_feature/domain/repositories/my_repository.dart';

part 'my_feature_event.dart';
part 'my_feature_state.dart';

class MyFeatureBloc extends Bloc<MyFeatureEvent, MyFeatureState> {
  MyFeatureBloc({required this.repository}) : super(const MyFeatureState.idle()) {
    on<MyFeatureEventFetch>(_onFetch);
  }

  final MyRepository repository;

  Future<void> _onFetch(
    MyFeatureEventFetch event,
    Emitter<MyFeatureState> emit,
  ) async {
    emit(const MyFeatureState.loading());

    try {
      final entity = await repository.fetchById(event.id);
      emit(MyFeatureState.success(entity: entity));
    } catch (e, st) {
      emit(MyFeatureState.error(error: e, stackTrace: st));
    }
  }
}

// my_feature_event.dart
part of 'my_feature_bloc.dart';

sealed class MyFeatureEvent {
  const MyFeatureEvent();
}

final class MyFeatureEventFetch extends MyFeatureEvent {
  const MyFeatureEventFetch({required this.id});
  final String id;
}

// my_feature_state.dart
part of 'my_feature_bloc.dart';

sealed class MyFeatureState {
  const MyFeatureState();

  const factory MyFeatureState.idle() = _Idle;
  const factory MyFeatureState.loading() = _Loading;
  const factory MyFeatureState.success({required MyEntity entity}) = _Success;
  const factory MyFeatureState.error({
    required Object error,
    required StackTrace stackTrace,
  }) = _Error;
}

final class _Idle extends MyFeatureState {
  const _Idle();
}

final class _Loading extends MyFeatureState {
  const _Loading();
}

final class _Success extends MyFeatureState {
  const _Success({required this.entity});
  final MyEntity entity;
}

final class _Error extends MyFeatureState {
  const _Error({required this.error, required this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
}
```

**Шаг 5**: Создать UI

```dart
// lib/src/feature/my_feature/presentation/widget/my_feature_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:template_flutter_claude/src/feature/my_feature/presentation/bloc/my_feature_bloc.dart';

class MyFeatureScreen extends StatelessWidget {
  const MyFeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyFeatureBloc, MyFeatureState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('My Feature')),
          body: switch (state) {
            _Idle() => const Center(child: Text('Press button to fetch')),
            _Loading() => const Center(child: CircularProgressIndicator()),
            _Success(:final entity) => Center(child: Text(entity.name)),
            _Error(:final error) => Center(child: Text('Error: $error')),
          },
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.read<MyFeatureBloc>().add(
              const MyFeatureEventFetch(id: '1'),
            ),
            child: const Icon(Icons.refresh),
          ),
        );
      },
    );
  }
}
```

**Шаг 6**: Настроить DI

```dart
// lib/src/feature/my_feature/dependencies/my_feature_dependencies.dart
import 'package:flutter/widgets.dart';
import 'package:template_flutter_claude/src/core/rest_client/rest_client.dart';
import 'package:template_flutter_claude/src/feature/my_feature/data/datasources/my_remote_ds.dart';
import 'package:template_flutter_claude/src/feature/my_feature/data/repositories/my_repository_impl.dart';
import 'package:template_flutter_claude/src/feature/my_feature/domain/repositories/my_repository.dart';
import 'package:template_flutter_claude/src/feature/my_feature/presentation/bloc/my_feature_bloc.dart';

class MyFeatureDependencies {
  MyFeatureDependencies({required RestClient restClient}) {
    _remoteDataSource = MyRemoteDataSource(restClient: restClient);
    _repository = MyRepositoryImpl(remoteDataSource: _remoteDataSource);
    bloc = MyFeatureBloc(repository: _repository);
  }

  late final MyRemoteDataSource _remoteDataSource;
  late final MyRepository _repository;
  late final MyFeatureBloc bloc;

  void dispose() {
    bloc.close();
  }
}
```

---

## ⚠️ Важные замечания

❗ **Регистрируй зависимости в DI перед использованием:**

[Подробнее о DI в проекте](../architecture/dependency-injection.md)

❗ **Запусти codegen после создания моделей с аннотациями:**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## ✅ Checklist создания Feature модуля

- [ ] Создана структура папок в `lib/src/feature/my_feature/`
- [ ] Созданы Domain модели и интерфейсы репозиториев
- [ ] Созданы Data DTOs с JSON сериализацией
- [ ] Созданы Data sources (remote/local)
- [ ] Созданы Data repositories (реализации)
- [ ] Создан BLoC с Events и States
- [ ] Созданы UI виджеты и экраны
- [ ] Настроен DI через Dependencies класс
- [ ] Запущен codegen (`build_runner build`)
- [ ] Написаны тесты в `test/src/feature/my_feature/`

---

## 🔗 См. также

- [Core модули](./core-modules.md) - создание Core модулей
- [BLoC Pattern](../architecture/bloc-pattern.md) - паттерн BLoC
- [Dependency Injection](../architecture/dependency-injection.md) - настройка DI
- [Тестирование BLoC](../testing/bloc-testing.md) - тестирование блоков
