---
name: ui-layout
description: Use when building adaptive layouts, working with LayoutBuilder, Constraints, MaterialApp.builder, Overlay, Canvas painting (LeafRenderObjectWidget vs CustomPainter), or creating UI components. MUST use for any layout, adaptive design, or custom painting questions in Flutter.
---

# UI & Layout / Вёрстка и адаптивность

## Adaptive Layout / Адаптивная вёрстка

Адаптивная вёрстка — обязательное требование.

### Ключевые виджеты для адаптивности

- **LayoutBuilder** — основной виджет, must know
- **CustomMultiChildLayout**
- **Flow**
- **CustomPainter** / **LeafRenderObjectWidget**
- **AspectRatio**
- **MediaQuery**
- **Constraints** (BoxConstraints)

### LayoutBuilder — обязательно знай

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

### Constraints — обязательное знание

Flutter спускает ограничения, поднимает размеры. Пойми эту концепцию:
- Родитель спускает constraints (ограничения) вниз
- Ребёнок определяет свой size (размер) и сообщает наверх
- Родитель позиционирует ребёнка

Документация Flutter содержит отдельный топик "Understanding constraints".

## MaterialApp.builder — важная точка

Используй `MaterialApp.builder` для встраивания скоупов и overlay между MaterialApp и навигатором:

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

1. **Скоупы** (AuthScope, SettingsScope) — зависимости над навигатором
2. **Overlay** — для отладочной информации, уведомлений
3. **MediaQuery** — пропатчи MediaQuery
4. **Экраны без навигатора** — аутентификация, force update

### Overlay Pattern

```dart
MaterialApp(
  builder: (context, child) {
    return Overlay(
      initialEntries: [
        OverlayEntry(builder: (_) => child!),  // Навигатор
        // Добавляй OverlayEntry поверх
      ],
    );
  },
)
```

Overlay в builder отображается поверх любого экрана навигатора:

```dart
// Покажи диалог обновления поверх всего:
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

## CustomPainter vs LeafRenderObjectWidget

### CustomPainter — ограничения

Не используй CustomPainter, если нужен контроль над размерами. Он занимает все доступные размеры и ломается в ListView, Column если не обёрнут в SizedBox:

```dart
CustomPaint(
  painter: MyPainter(),
  // Проблема: занимает ВСЕ доступное пространство
  // Не сообщает свой желаемый размер
  // Ломается в ListView, Column если не обёрнут в SizedBox
)
```

### LeafRenderObjectWidget — полный контроль

Используй LeafRenderObjectWidget для полного контроля над размерами:

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
    // Сам определяй свой размер
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

Кэшируй отрисовку через Picture Recorder:

```dart
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

Создавай компоненты в UI Kit:

```dart
class AppButton extends StatelessWidget { ... }
class AppText extends StatelessWidget { ... }
class AppTextField extends StatelessWidget { ... }
class AppCard extends StatelessWidget { ... }
```

Тема, цвета, типографика используются внутри компонентов, а не в экранах.

## Pixel Perfect

Pixel Perfect возможен, но есть ограничение: ошибка плавающей запятой (double) накапливается. Это баг Skia, с ним ничего не сделать.

## Работа с дизайнерами

### Проблема: дизайнеры без компонентов

Если дизайнеры верстают не компонентами — получается непоследовательный дизайн:
- Кнопки разной высоты (56px и 48px)
- Разные скругления (12, 16, 20)
- Разные отступы без системы
- Каждый элемент создаётся с нуля

### Решение

1. Найди в Figma стандартный Material Design UI Kit
2. Покажи дизайнерам: "Используйте компоненты, не копипастите"
3. Создай UI Kit в коде, синхронизируй с дизайном
4. Если дизайнер делает непоследовательно — сам исправляй в коде

## Key Takeaways

1. **LayoutBuilder** — основной виджет для адаптивности
2. **Constraints** (спускает ограничения, поднимает размеры) — must know
3. **MaterialApp.builder** — точка между MaterialApp и навигатором
4. **Overlay** в builder — поверх всех экранов навигатора
5. **LeafRenderObjectWidget** > CustomPainter (контроль размеров)
6. **Компоненты**, не магические числа
7. **Picture Recorder** для кэширования отрисовки на Canvas
8. Заставляй дизайнеров работать с компонентами
