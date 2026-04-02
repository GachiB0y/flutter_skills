---
name: Assets & Optimization
description: Sprite atlas, SVG to Canvas, IconMoon шрифты, WebP, Asset Transformers, LeafRenderObjectWidget
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# Assets & Optimization / Ассеты и оптимизация ресурсов

## Sprite Atlas / Атлас спрайтов

Когда у вас много растровых иконок одинакового размера, каждая -- отдельный файл = отдельное чтение с диска (или GET-запрос на вебе).

### Решение: объединение в один атлас

```
// Вместо:
assets/icons/icon1.png  // Отдельное чтение
assets/icons/icon2.png  // Отдельное чтение
assets/icons/icon3.png  // Отдельное чтение
// ...100 файлов = 100 операций чтения

// Делаем:
assets/atlas.png  // Одно чтение, все иконки в одном изображении
```

Создание атласа: в Фотошопе или через утилиту Sprite Sheet Generator. Каждая иконка в отдельной ячейке изображения.

Использование: загружаешь целиком в память, выводишь нужные кусочки через:
- Canvas отрисовку
- Memory image
- Нарезку по координатам

> "Хороший подход из игр и веба. Загружаешь одну текстуру и используешь кусочками."

## Выбор формата для иконок

### Растровые иконки (PNG/WebP) -- когда размер фиксирован

Если иконка всегда одного размера (24x24, 32x32, 48x48) и одного цвета -- используйте **растр (WebP)**:

```dart
// Иконка всегда 24x24 и всегда серая?
// Растр -- лучший вариант
Image.asset('assets/icons/settings.webp', width: 24, height: 24)
```

> "Если ты знаешь финальный размер и цвет -- растр это твой лучший вариант."

### SVG to Canvas -- для логотипов

Если логотип может менять размер, раскрашиваться, содержит сложные формы:

```dart
// Преобразовать SVG в код CustomPainter/RenderObject
// Утилиты: Flutter Shape Maker, SVG to Canvas конвертеры

// Пример: логотип через LeafRenderObjectWidget
class AppleLogo extends LeafRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderAppleLogo();
  }
}
```

Генерация: `flutter svg to canvas` -- консольные утилиты, которые генерируют Dart-код из SVG.

### Icon Fonts (IconMoon) -- для множества раскрашиваемых иконок

Когда иконок много, они могут менять цвет и размер -- преобразуйте в **шрифт**:

```dart
// Сайт: icomoon.io
// 1. Загружаете свои SVG-иконки
// 2. Экспортируете как TTF-шрифт
// 3. Используете как обычные иконки

class AppIcons {
  static const IconData instagram = IconData(0xe900, fontFamily: 'AppIcons');
  static const IconData youtube = IconData(0xe901, fontFamily: 'AppIcons');
  static const IconData patreon = IconData(0xe902, fontFamily: 'AppIcons');
}

// Использование:
Icon(AppIcons.instagram, color: Colors.pink, size: 32)
```

Преимущества:
- Один файл шрифта вместо множества SVG
- Нативная раскраска через `color`
- Любой размер без потери качества
- Оптимальная производительность

### Anti-pattern: flutter_svg пакет

> "flutter_svg -- стрёмный пакет. SVG разбирается в рантайме Dart'ом, парсится и отрисовывается на Canvas. Это весьма дорого. Результат непредсказуемый."

Проблемы flutter_svg:
- Парсинг SVG в рантайме (дорого)
- Непредсказуемый результат рендеринга
- Каждый SVG-файл -- отдельный GET-запрос на вебе

## WebP формат

> "WebP весит примерно на 40% меньше, чем PNG."

Конвертация всех ассетов в WebP одной командой через ImageMagick:

```bash
# Через ImageMagick:
magick mogrify -format webp assets/**/*.png

# Или через Docker:
docker run --rm -v $(pwd)/assets:/assets \
  dpokidov/imagemagick \
  mogrify -format webp /assets/**/*.png
```

WebP с недавнего времени поддерживает анимации (все браузеры уже поддерживают).

## Asset Transformers

Flutter поддерживает трансформеры ассетов -- преобразование при сборке:

```yaml
# pubspec.yaml
flutter:
  assets:
    - path: assets/icons/
      transformers:
        - package: vector_graphics_compiler
```

Трансформеры позволяют:
- Конвертировать SVG в бинарный формат при сборке (не в рантайме)
- Оптимизировать изображения
- Преобразовывать форматы

> "Есть специальные трансформеры. Они при сборке приложения преобразуют SVG в более бинарный формат, который Flutter'у будет проще переварить."

## LeafRenderObjectWidget vs CustomPainter

### CustomPainter -- ограничения

```dart
// CustomPainter занимает ВСЕ доступное место
// Не позволяет управлять собственными размерами
CustomPaint(
  painter: MyPainter(),
  // Занимает всё пространство, выделенное родителем
)
```

Проблема: в списках, колонках -- ломается, потому что не сообщает свой желаемый размер.

### LeafRenderObjectWidget -- полный контроль

```dart
class LogoWidget extends LeafRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLogo();
  }
}

class RenderLogo extends RenderBox {
  @override
  void performLayout() {
    // Сам определяет свой размер!
    size = constraints.constrain(Size(200, 50));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    // Отрисовка на Canvas
    // Picture Recorder для кэширования
  }

  @override
  bool get sizedByParent => false;
}
```

Преимущества:
- Управление собственными размерами
- Работает в списках и колонках
- Управление перерисовкой
- Picture Recorder для кэширования отрисовки

> "LeafRenderObjectWidget не сложнее CustomPainter. Просто позволяет больше."

### Адаптивная отрисовка

```dart
@override
void paint(PaintingContext context, Offset offset) {
  if (size.width > 200) {
    // Рисуем полный логотип с текстом
    drawFullLogo(context.canvas, offset);
  } else {
    // Рисуем только иконку (места мало)
    drawIconOnly(context.canvas, offset);
  }
}
```

## Оптимизация: минимум ассетов

> "Ассетов тоже было просто больше. Очень много SVG'шек. Я всё повыкидывал и оставил минимум."

Принцип: оставляйте только то, что реально используется. Каждый лишний ассет -- это:
- Размер бандла
- Время загрузки (особенно на вебе)
- Операции чтения с диска

## Key Takeaways / Ключевые выводы

1. **Sprite Atlas** -- объединяйте растровые иконки в один файл
2. **WebP** вместо PNG (на 40% меньше), конвертация через ImageMagick
3. **Icon fonts** (IconMoon) для множества раскрашиваемых иконок
4. **SVG to Canvas** для логотипов (не flutter_svg в рантайме!)
5. **Asset Transformers** для конвертации SVG при сборке
6. **LeafRenderObjectWidget** вместо CustomPainter для контроля размеров
7. Минимум ассетов -- убирайте всё неиспользуемое
