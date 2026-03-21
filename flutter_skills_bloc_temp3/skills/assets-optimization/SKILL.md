---
name: assets-optimization
description: Use when optimizing assets — sprite atlas, SVG to Canvas, IconMoon icon fonts, WebP conversion, Asset Transformers. MUST use for any icon, image, or asset optimization questions in Flutter. Covers why NOT to use flutter_svg.
---

# Assets & Optimization / Ассеты и оптимизация ресурсов

## Sprite Atlas / Атлас спрайтов

Если у тебя много растровых иконок одного размера — объединяй их в sprite atlas. Каждая отдельная иконка = отдельное чтение с диска (или GET-запрос на вебе).

### Решение: объединение в один атлас

```
// Вместо:
assets/icons/icon1.png  // Отдельное чтение
assets/icons/icon2.png  // Отдельное чтение
assets/icons/icon3.png  // Отдельное чтение
// ...100 файлов = 100 операций чтения

// Делай:
assets/atlas.png  // Одно чтение, все иконки в одном изображении
```

Создавай атлас в Фотошопе или через утилиту Sprite Sheet Generator. Каждая иконка — в отдельной ячейке изображения.

Загружай целиком в память, выводи нужные кусочки через:
- Canvas отрисовку
- Memory image
- Нарезку по координатам

## Выбор формата для иконок

### Растровые иконки (PNG/WebP) — когда размер фиксирован

Используй растр (WebP), если иконка фиксированного размера и цвета:

```dart
// Иконка всегда 24x24 и всегда серая?
// Растр — лучший вариант
Image.asset('assets/icons/settings.webp', width: 24, height: 24)
```

### SVG to Canvas — для логотипов

Если логотип может менять размер, раскрашиваться, содержит сложные формы — конвертируй SVG в код CustomPainter/RenderObject:

```dart
// Преобразуй SVG в код CustomPainter/RenderObject
// Утилиты: Flutter Shape Maker, SVG to Canvas конвертеры

// Пример: логотип через LeafRenderObjectWidget
class AppleLogo extends LeafRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderAppleLogo();
  }
}
```

Используй `flutter svg to canvas` — консольные утилиты, которые генерируют Dart-код из SVG.

### Icon Fonts (IconMoon) — для множества раскрашиваемых иконок

Когда иконок много и они могут менять цвет и размер — преобразуй в шрифт:

```dart
// Сайт: icomoon.io
// 1. Загружай свои SVG-иконки
// 2. Экспортируй как TTF-шрифт
// 3. Используй как обычные иконки

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

### Anti-pattern: flutter_svg

Не используй flutter_svg. SVG парсится в рантайме Dart'ом — это дорого и непредсказуемо.

Проблемы flutter_svg:
- Парсинг SVG в рантайме (дорого)
- Непредсказуемый результат рендеринга
- Каждый SVG-файл — отдельный GET-запрос на вебе

## WebP формат

WebP весит примерно на 40% меньше, чем PNG. Конвертируй все ассеты в WebP одной командой через ImageMagick:

```bash
# Через ImageMagick:
magick mogrify -format webp assets/**/*.png

# Или через Docker:
docker run --rm -v $(pwd)/assets:/assets \
  dpokidov/imagemagick \
  mogrify -format webp /assets/**/*.png
```

WebP поддерживает анимации (все браузеры уже поддерживают).

## Asset Transformers

Используй трансформеры ассетов для преобразования при сборке:

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

## LeafRenderObjectWidget vs CustomPainter

Не используй CustomPainter, если нужен контроль над размерами. Используй LeafRenderObjectWidget. Подробное сравнение и примеры — см. скилл `ui-layout`.

## Оптимизация: минимум ассетов

Оставляй только то, что реально используется. Каждый лишний ассет — это:
- Размер бандла
- Время загрузки (особенно на вебе)
- Операции чтения с диска

Убирай всё неиспользуемое.

## Key Takeaways

1. **Sprite Atlas** — объединяй растровые иконки в один файл
2. **WebP** вместо PNG (на 40% меньше), конвертируй через ImageMagick
3. **Icon fonts** (IconMoon) для множества раскрашиваемых иконок
4. **SVG to Canvas** для логотипов (не flutter_svg в рантайме!)
5. **Asset Transformers** для конвертации SVG при сборке
6. **LeafRenderObjectWidget** вместо CustomPainter — подробнее в скилле `ui-layout`
7. Минимум ассетов — убирай всё неиспользуемое
