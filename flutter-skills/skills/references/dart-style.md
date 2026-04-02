# Dart & Flutter Code Style / Стиль кода Dart и Flutter

> Этот файл -- справочник общих правил. Применяется ко всем Dart/Flutter файлам.

## 1. Pattern Matching (Dart 3+)

Используй switch expressions для более читаемого кода:

```dart
String getStatusText(Status status) {
  return switch (status) {
    Status.loading => 'Загрузка...',
    Status.success => 'Успешно',
    Status.error => 'Ошибка',
  };
}
```

Используй pattern matching в BLoC для обработки состояний:

```dart
BlocBuilder<UserBloc, UserState>(
  builder: (context, state) {
    return switch (state) {
      UserProfileState$Idle() => const SizedBox.shrink(),
      UserProfileState$Processing() => const CircularProgressIndicator(),
      UserProfileState$Success(:final data) => UserWidget(user: data),
      UserProfileState$Error(:final error) => ErrorWidget(message: error.toString()),
    };
  },
)
```

## 2. Null Safety

Никогда не используй `!` (bang) оператор -- он может выстрелить в рантайме.

Делай явную проверку на null вместо bang оператора:

```dart
String? nullableValue;
String nonNullableValue = '';

// ХОРОШО -- явная проверка
if (value != null) {
  useValue(value);
}

// ПЛОХО -- bang оператор
useValue(value!);
```

Используй `late` инициализацию осознанно:

```dart
late final MyService service;
```

Используй cascade оператор для цепочек:

```dart
myObject
  ..property1 = value1
  ..property2 = value2
  ..method();
```

## 3. Неизменяемость (Immutability)

Используй `final` для всех полей. Предпочитай `final class` для запечатанных классов. Добавляй `const` конструкторы:

```dart
// ХОРОШО
final class User {
  const User({required this.name, required this.email});

  final String name;
  final String email;
}

// ПЛОХО
class User {
  String name;
  String email;
}
```

## 4. Const конструкторы

Используй `const` конструкторы везде где возможно -- это критично для производительности Flutter:

```dart
// ХОРОШО
const Text('Hello')
const SizedBox(height: 16)
const Icon(Icons.home)

// ПЛОХО
Text('Hello')
SizedBox(height: 16)
Icon(Icons.home)
```

## 5. Импорты

Соблюдай порядок импортов:

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:ui';

// 2. Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. Пакеты
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
```

## 6. Виджеты: классы, а не методы _build

Не создавай виджеты через методы `_buildXXX()`. Методы увеличивают ресурсы на перестроение, потому что Flutter сравнивает типы виджетов.

```dart
// ПЛОХО
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildContent(),
      ],
    );
  }

  Widget _buildHeader() => Container(...);
  Widget _buildContent() => ListView(...);
}

// ХОРОШО
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _MyHeader(),
        _MyContent(),
      ],
    );
  }
}

final class _MyHeader extends StatelessWidget {
  const _MyHeader();

  @override
  Widget build(BuildContext context) => Container(...);
}

final class _MyContent extends StatelessWidget {
  const _MyContent();

  @override
  Widget build(BuildContext context) => ListView(...);
}
```

Исключение: не извлекай каждый простой виджет. Извлекай только сложные и большие компоненты.

## 7. Проверка mounted после async

Проверяй `mounted` перед использованием `context` после async операций:

```dart
Future<void> loadData() async {
  await repository.fetch();

  if (!mounted) return;

  Navigator.of(context).pop();
}
```

## 8. Производительность

1. Используй `const` конструкторы -- критично для производительности
2. Избегай `Opacity` -- используй `AnimatedOpacity`
3. Используй `ListView.builder` вместо `ListView` для больших списков
4. Применяй `RepaintBoundary` для изоляции перерисовки
5. Используй `ValueListenableBuilder` вместо полной перестройки через `setState`

```dart
// ХОРОШО
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(title: Text(items[index]));
  },
)

// ПЛОХО
ListView(
  children: items.map((item) => ListTile(title: Text(item))).toList(),
)
```

## 9. Документация

Документируй публичные API:

```dart
/// {@template my_widget}
/// Краткое описание виджета и его назначения.
/// {@endtemplate}
final class MyWidget extends StatelessWidget {
  /// {@macro my_widget}
  const MyWidget({
    required this.title,
    this.onTap,
    super.key,
  });

  /// Заголовок виджета
  final String title;

  /// Обработчик нажатия
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

## Чего не делать

1. Не используй `!` (bang) оператор -- делай явную проверку на null
2. Не создавай методы `_buildXXX()` -- создавай отдельные виджеты-классы
3. Не создавай глобальные переменные без крайней необходимости
4. Не игнорируй `const` конструкторы
5. Не используй `BuildContext` после async без проверки `mounted`
6. Не забывай про `dispose()` для контроллеров и подписок
7. Не создавай "God Objects" (классы с множеством ответственностей)
