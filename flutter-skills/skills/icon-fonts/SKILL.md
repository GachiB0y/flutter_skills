---
name: icon-fonts
description: Use when working with custom icons in Flutter via TTF/OTF icon fonts — generating icon fonts from SVG, integrating TTF into a project, creating Dart icon classes, using Foxic/FlutterIcon/IcoMoon. MUST use for any custom icon font setup, SVG-to-font conversion, or IconData class generation in Flutter.
---

# Icon Fonts / Иконочные шрифты во Flutter

> Иконочный шрифт — это TTF/OTF файл, где вместо букв — векторные иконки. Каждая иконка = глиф с уникальным кодом, доступный через `IconData`. Это самый производительный способ использовать кастомные иконки во Flutter.

## Почему иконочный шрифт, а не SVG

| Критерий | Icon Font (TTF) | flutter_svg | PNG/WebP |
|----------|----------------|-------------|----------|
| Рендеринг | Нативный (Skia) | Парсинг в рантайме | Растр |
| Цвет | `Icon(icon, color: ...)` | Нужен `colorFilter` | Нельзя менять |
| Размер | Вектор, любой size | Вектор | Фиксирован |
| Файлы | 1 TTF на все иконки | N файлов = N запросов | N файлов |
| Производительность | Отличная | Плохая | Хорошая |

## Сервисы для генерации иконочных шрифтов

### 1. Foxic (icons.plugfox.dev) — рекомендуемый

- **URL:** https://icons.plugfox.dev
- Веб-генератор от PlugFox (Михаил Матюнин)
- Поддержка командной работы (проекты с совместным доступом)
- Экспорт TTF + Dart-класс
- Русский и английский интерфейс

### 2. FlutterIcon (fluttericon.com)

- **URL:** https://www.fluttericon.com
- Специализирован под Flutter
- Drag & drop SVG, выбор глифов, скачивание пакета
- Генерирует TTF + готовый Dart-класс + pubspec-конфиг
- Есть встроенные наборы иконок (Typicons, Fontellio и др.)

### 3. IcoMoon (icomoon.io)

- **URL:** https://icomoon.io/app
- Универсальный генератор (не только Flutter)
- Большая библиотека бесплатных иконок
- Экспорт TTF/WOFF/SVG font
- Dart-класс нужно писать вручную или генерировать утилитой

### 4. icon_font_generator (CLI)

- **pub.dev:** `icon_font_generator`
- Консольный инструмент — без веб-интерфейса
- Автоматизация через CI/CD
- Генерирует OTF + Dart-класс из папки с SVG

```bash
# Установка
flutter pub add --dev icon_font_generator

# Генерация
flutter pub run icon_font_generator:generate \
  assets/svg/ \
  fonts/app_icons.otf \
  --output-class-file=lib/src/app_icons.dart \
  --class-name=AppIcons \
  --font-name="App Icons"
```

## Workflow: генерация через Foxic

### Шаг 1. Подготовка SVG-иконок

Перед загрузкой в генератор убедись:

- Каждая иконка — отдельный SVG-файл
- Все формы сконвертированы в `<path>` (в Figma: Flatten Selection)
- Убраны заливки с фиксированным цветом (иконка должна быть одноцветной — `currentColor`)
- Размер artboard одинаковый (обычно 24x24 или 16x16)
- Нет вложенных `<svg>`, `<image>`, `<text>` элементов

```
assets/svg_source/
├── home.svg
├── search.svg
├── profile.svg
├── settings.svg
├── notification.svg
└── chat.svg
```

### Шаг 2. Генерация в Foxic

1. Открой https://icons.plugfox.dev
2. Создай проект (или открой существующий для командной работы)
3. Загрузи SVG-файлы (drag & drop)
4. Проверь глифы — каждая иконка должна отображаться корректно
5. Экспортируй — скачается архив с:
   - `AppIcons.ttf` — файл шрифта
   - `app_icons.dart` — Dart-класс с константами
   - Конфиг для повторной генерации

### Шаг 3. Интеграция TTF в проект

Положи шрифт в папку ассетов:

```
lib/
assets/
└── fonts/
    └── AppIcons.ttf
```

Зарегистрируй в `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: AppIcons
      fonts:
        - asset: assets/fonts/AppIcons.ttf
```

### Шаг 4. Dart-класс иконок

Если генератор дал готовый файл — положи его в проект. Если нужно написать вручную (например, после IcoMoon), используй этот шаблон:

```dart
// lib/src/ui/icons/app_icons.dart
import 'package:flutter/widgets.dart';

/// Кастомные иконки приложения, сгенерированные из SVG.
///
/// Использование:
/// ```dart
/// Icon(AppIcons.home, size: 24, color: Colors.black)
/// ```
abstract final class AppIcons {
  /// Имя семейства шрифта — должно совпадать с `family` в pubspec.yaml.
  static const String _fontFamily = 'AppIcons';

  /// Пакет, если шрифт находится в отдельном пакете (например, ui_library).
  /// Если шрифт в основном приложении — убери параметр `fontPackage`.
  // static const String _fontPackage = 'ui_library';

  static const IconData home = IconData(
    0xe900,
    fontFamily: _fontFamily,
    // fontPackage: _fontPackage,
  );
  static const IconData search = IconData(
    0xe901,
    fontFamily: _fontFamily,
  );
  static const IconData profile = IconData(
    0xe902,
    fontFamily: _fontFamily,
  );
  static const IconData settings = IconData(
    0xe903,
    fontFamily: _fontFamily,
  );
  static const IconData notification = IconData(
    0xe904,
    fontFamily: _fontFamily,
  );
  static const IconData chat = IconData(
    0xe905,
    fontFamily: _fontFamily,
  );
}
```

Коды глифов (`0xe900`, `0xe901`, ...) берутся из генератора. Каждый генератор показывает Unicode-код для каждого глифа.

### Шаг 5. Использование в виджетах

```dart
import 'package:my_app/src/ui/icons/app_icons.dart';

// Базовое использование
Icon(AppIcons.home)

// С настройкой размера и цвета
Icon(
  AppIcons.notification,
  size: 28,
  color: context.color.primary,
)

// В кнопке
IconButton(
  icon: const Icon(AppIcons.settings),
  onPressed: () => _openSettings(),
)

// В BottomNavigationBar
BottomNavigationBarItem(
  icon: const Icon(AppIcons.home),
  activeIcon: const Icon(AppIcons.home), // или AppIcons.homeFilled
  label: 'Home',
)

// В AppBar
AppBar(
  leading: IconButton(
    icon: const Icon(AppIcons.chat),
    onPressed: () {},
  ),
)
```

## Шрифт в отдельном пакете (монорепо)

Если иконки живут в UI-библиотеке (например, `core/ui_library/`), добавь параметр `fontPackage`:

```dart
abstract final class AppIcons {
  static const String _fontFamily = 'AppIcons';
  static const String _fontPackage = 'ui_library';

  static const IconData home = IconData(
    0xe900,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );
}
```

И зарегистрируй шрифт в `pubspec.yaml` пакета `ui_library`:

```yaml
# core/ui_library/pubspec.yaml
flutter:
  fonts:
    - family: AppIcons
      fonts:
        - asset: assets/fonts/AppIcons.ttf
```

Приложение, подключающее `ui_library`, автоматически получит шрифт.

## Обновление набора иконок

При добавлении новых иконок:

1. Добавь новые SVG в проект Foxic (или другой генератор)
2. Перегенерируй шрифт — существующие коды глифов не должны меняться
3. Замени TTF-файл в `assets/fonts/`
4. Обнови Dart-класс — добавь новые константы
5. Выполни `flutter pub get` и горячую перезагрузку

Foxic сохраняет проект, поэтому при повторной генерации старые коды сохраняются — это гарантирует, что существующие иконки не сломаются.

## Автоматизация через CLI (icon_font_generator)

Для проектов с частым обновлением иконок удобнее использовать CLI вместо веб-генератора:

```yaml
# pubspec.yaml — секция icon_font (конфиг для генератора)
icon_font:
  input_svg_dir: "assets/svg_source/"
  output_font_file: "assets/fonts/AppIcons.otf"
  output_class_file: "lib/src/ui/icons/app_icons.dart"
  class_name: "AppIcons"
  font_name: "AppIcons"
  normalize: true
  recursive: false
```

```bash
# Генерация одной командой
flutter pub run icon_font_generator:generate
```

Можно добавить в Makefile или CI:

```makefile
icons:
	flutter pub run icon_font_generator:generate
```

## Типичные проблемы

### Иконка не отображается (пустой квадрат)

- `fontFamily` в Dart-классе не совпадает с `family` в `pubspec.yaml`
- Забыл `flutter pub get` после изменения pubspec
- Неправильный Unicode-код глифа
- TTF-файл повреждён или не обновлён

### Иконка отображается криво

- SVG содержит `stroke` вместо `fill` — конвертируй обводки в заливки (Outline Stroke в Figma)
- Разный размер artboard у разных иконок
- SVG содержит `clip-path` или маски — упрости перед экспортом

### fontPackage не работает

- Убедись, что шрифт зарегистрирован в `pubspec.yaml` пакета, а не приложения
- Имя пакета в `fontPackage` должно совпадать с `name` в pubspec.yaml пакета

## Чеклист интеграции

- [ ] SVG подготовлены (paths, одноцветные, одинаковый artboard)
- [ ] TTF сгенерирован через Foxic / FlutterIcon / CLI
- [ ] TTF лежит в `assets/fonts/`
- [ ] Шрифт зарегистрирован в `pubspec.yaml` (секция `flutter.fonts`)
- [ ] Dart-класс создан с правильными Unicode-кодами
- [ ] `fontPackage` указан, если шрифт в отдельном пакете
- [ ] `flutter pub get` выполнен
- [ ] Иконки проверены визуально в приложении
