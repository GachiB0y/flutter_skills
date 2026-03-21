---
name: UI & Layout
description: Адаптивная вёрстка, LayoutBuilder, Constraints, CustomPainter vs LeafRenderObjectWidget, компонентный подход, MaterialApp.builder, Overlay
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# UI & Layout / Вёрстка и адаптивность

## Adaptive Layout / Адаптивная вёрстка

> "Адаптивная вёрстка -- это база."

### Ключевые виджеты для адаптивности

- **LayoutBuilder** -- основной виджет, must know
- **CustomMultiChildLayout**
- **Flow**
- **CustomPainter** / **LeafRenderObjectWidget**
- **AspectRatio**
- **MediaQuery**
- **Constraints** (BoxConstraints)

### LayoutBuilder -- обязательно знать

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      return DesktopLayout();
    }
    return MobileLayout();
  },
)
```

### Constraints -- must have знание

> "Это спрашивают на собеседованиях. Flutter спускает ограничения, поднимает размеры. Эту концепцию желательно понять, иначе во всём углублении будут проблемы."

Документация Flutter содержит отдельный топик "Understanding constraints":
- Родитель спускает constraints (ограничения) вниз
- Ребёнок определяет свой size (размер) и сообщает наверх
- Родитель позиционирует ребёнка

## MaterialApp.builder -- важная точка

> "Одна из самых интересных вещей, которую очень многие игнорируют у MaterialApp -- это builder."

```dart
MaterialApp(
  builder: (context, child) {
    // Здесь:
    // - Есть MaterialApp контекст (тема, локализация, направление текста)
    // - НЕТ навигатора (child = навигатор)
    // - Можно встроить что-то МЕЖДУ MaterialApp и навигатором

    return Column(
      children: [
        Expanded(child: child!),  // Навигатор
        // Что-то под навигатором
      ],
    );
  },
)
```

### Что размещать в builder

1. **Скоупы** (AuthScope, SettingsScope) -- зависимости над навигатором
2. **Overlay** -- для отладочной информации, уведомлений
3. **MediaQuery** -- пропатчить MediaQuery
4. **Экраны без навигатора** -- аутентификация, force update

### Overlay Pattern

```dart
MaterialApp(
  builder: (context, child) {
    return Overlay(
      initialEntries: [
        OverlayEntry(builder: (_) => child!),  // Навигатор
        // Можно добавлять OverlayEntry поверх
      ],
    );
  },
)
```

Overlay в builder отображается **поверх любого экрана** навигатора:

```dart
// Показать диалог обновления поверх всего:
final overlay = Overlay.of(context);
overlay.insert(OverlayEntry(
  builder: (_) => UpdateDialog(mandatory: true),
));
```

### Debug Overlay

```dart
// Отладочная информация (только в development):
if (kDebugMode) {
  overlay.insert(OverlayEntry(
    builder: (_) => Positioned(
      right: 8,
      top: 8,
      child: DebugInfo(
        environment: 'staging',
        endpoint: 'api.dev.example.com',
        version: '1.2.3',
      ),
    ),
  ));
}
```

> "Вещи, которые показываются в отладке -- через Overlay. Чтобы в дебаге было понятно, что это staging, что такой-то endpoint."

## CustomPainter vs LeafRenderObjectWidget

### CustomPainter -- ограничения

```dart
CustomPaint(
  painter: MyPainter(),
  // Проблема: занимает ВСЕ доступное пространство
  // Не сообщает свой желаемый размер
  // Ломается в ListView, Column если не обёрнут в SizedBox
)
```

> "CustomPainter не позволяет управлять размерами. Занимает все размеры, доступные и выделенные ему."

### LeafRenderObjectWidget -- полный контроль

```dart
class AdaptiveLogo extends LeafRenderObjectWidget {
  const AdaptiveLogo();

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLogo();
  }
}

class _RenderLogo extends RenderBox {
  @override
  void performLayout() {
    // Сам определяет свой размер
    // "Спасибо, что предоставил огромный размер,
    // но я использую только малую часть"
    size = constraints.constrain(Size(200, 50));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    // Адаптивная отрисовка в зависимости от размера
    if (size.width > 150) {
      _drawFullLogo(canvas, offset);    // Иконка + текст
    } else {
      _drawIconOnly(canvas, offset);    // Только иконка
    }
  }
}
```

### Оптимизация: Picture Recorder

```dart
// Кэширование отрисовки через Picture Recorder
Picture? _cachedPicture;
Size? _cachedSize;

@override
void paint(PaintingContext context, Offset offset) {
  if (_cachedPicture == null || _cachedSize != size) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    _drawLogo(canvas, Size.zero);
    _cachedPicture = recorder.endRecording();
    _cachedSize = size;
  }
  context.canvas.drawPicture(_cachedPicture!);
}
```

## Компонентный подход к вёрстке

### Anti-pattern: магические числа и константы

```dart
// ПЛОХО:
Padding(padding: EdgeInsets.all(16))
Text('Hello', style: TextStyle(fontSize: 14, fontFamily: 'Roboto'))

// ПЛОХО (всё ещё магические числа):
Padding(padding: EdgeInsets.all(UIConstants.defaultPadding))
Text('Hello', style: TextStyle(fontSize: UIConstants.smallSize))
```

### Правильно: компоненты

```dart
// Создать компоненты в UI Kit:
class AppButton extends StatelessWidget { ... }
class AppText extends StatelessWidget { ... }
class AppTextField extends StatelessWidget { ... }
class AppCard extends StatelessWidget { ... }
```

Тема, цвета, типографика используются **внутри компонентов**, а не в экранах.

## Pixel Perfect

> "Что тебе мешает сделать Pixel Perfect? Бери и делай."

Ограничение: ошибка плавающей запятой (double) накапливается. Это баг Skia, с ним ничего не сделать. Где-то будет "полу-Pixel Perfect".

## Работа с дизайнерами

### Проблема: дизайнеры без компонентов

> "Когда дизайнеры верстают сами не компонентами -- они верстают херню. Прямо буквально."

Проявления:
- Кнопки разной высоты (56px и 48px)
- Разные скругления (12, 16, 20)
- Разные отступы без системы
- Каждый элемент создаётся с нуля

### Решение

1. Найти в Figma стандартный Material Design UI Kit
2. Показать дизайнерам: "Используйте компоненты, не копипастите"
3. Создать UI Kit в коде, синхронизировать с дизайном
4. Если дизайнер делает непоследовательно -- самому исправлять в коде

## Key Takeaways / Ключевые выводы

1. **LayoutBuilder** -- основной виджет для адаптивности
2. **Constraints** (спускает ограничения, поднимает размеры) -- must know
3. **MaterialApp.builder** -- точка между MaterialApp и навигатором
4. **Overlay** в builder -- поверх всех экранов навигатора
5. **LeafRenderObjectWidget** > CustomPainter (контроль размеров)
6. **Компоненты**, не магические числа
7. **Picture Recorder** для кэширования отрисовки на Canvas
8. Заставляйте дизайнеров работать с компонентами
