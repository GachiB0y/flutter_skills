# Flutter General Rules

> Применяется ко всем Dart файлам в проекте

## 🎯 Общие принципы

Ты опытный Flutter/Dart разработчик с 5+ годами опыта. Твоя задача - писать чистый, масштабируемый и поддерживаемый код.

## 📋 Основные правила

### 1. Не делай виджеты через методы , которые возвращают виджет, это важно потому что методы - увеличивают ресурсы на перестроение , т.к идет сравнение типов, а тут метод ,а не класс

**❌ НЕ ДЕЛАЙ ТАК:**

```dart
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildContent(),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() => Container(...);
  Widget _buildContent() => ListView(...);
  Widget _buildFooter() => Row(...);
}
```

**✅ ДЕЛАЙ ТАК:**

```dart
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _MyHeader(),
        _MyContent(),
        _MyFooter(),
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

final class _MyFooter extends StatelessWidget {
  const _MyFooter();

  @override
  Widget build(BuildContext context) => Row(...);
}
```

**Исключение:** Не нужно извлекать каждый простой виджет. Извлекай только сложные и большие компоненты.

### 2. Неизменяемость (Immutability)

- Все виджеты должны быть `const` где возможно
- Используй `final` для всех полей
- Предпочитай `final class` для запечатанных классов

Это нужно чтобы было больше const классов

```dart
// ✅ ХОРОШО
final class User {
  const User({required this.name, required this.email});

  final String name;
  final String email;
}

// ❌ ПЛОХО
class User {
  String name;
  String email;
}
```

### 3. Документация

Всегда документируй публичные API:

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

## Что НЕ делать

1. Не используй методы `build` внутри классов для создания виджетов
2. Не создавай глобальные переменные без крайней необходимости
3. Не игнорируй `const` конструкторы
4. Не используй `setState` в StatelessWidget
5. Не создавай "God Objects" (классы с множеством ответственностей)
6. Не забывай про `dispose()` для контроллеров и подписок
7. Не используй `BuildContext` после async операций без проверки `mounted`

## Best Practices

1. Всегда используй типизацию (`List<String>` вместо `List`)
2. Предпочитай композицию наследованию
3. Используй `sealed class` для закрытых иерархий
4. Применяй `extension` для расширения функциональности
5. Пиши тесты (unit, widget, integration)
6. Используй `key` для виджетов в списках, если это нужно
7. Проверяй `mounted` перед использованием `context` после async

```dart
// ✅ Безопасное использование context после async
Future<void> loadData() async {
  await repository.fetch();

  if (!mounted) return; // Проверка перед использованием context

  Navigator.of(context).pop();
}
```

## Производительность

1. Используй `const` конструкторы - критично для производительности
2. Избегай `Opacity` - используй `AnimatedOpacity`
3. Используй `ListView.builder` вместо `ListView` для больших списков
4. Применяй `RepaintBoundary` для изоляции перерисовки
5. Используй `ValueListenableBuilder` вместо полной перестройки

```dart
// ✅ ХОРОШО для производительности
ValueListenableBuilder<int>(
  valueListenable: counterNotifier,
  builder: (context, count, child) {
    return Text('$count');
  },
)

// ❌ ПЛОХО - перерисовывает всё дерево
setState(() {
  counter++;
});
```

## 🧪 Тестирование

Всегда пиши тесты для:

- Бизнес логики (unit тесты)
- Виджетов (widget тесты)

```dart
// Пример widget теста
testWidgets('MyWidget отображает title', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: MyWidget(title: 'Тест'),
    ),
  );

  expect(find.text('Тест'), findsOneWidget);
});
```

## Импорты

```dart
// Порядок импортов
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
