# Темизация приложения (Theme Architecture)

> Применяется к работе с темой в **/ui_library/theme/**

## 🎨 Архитектура темы в проекте

В проекте используется **расширенная система темизации** через `ThemeExtension`, что позволяет:

- ✅ Кастомные цвета и градиенты
- ✅ Типографика с семантическими названиями
- ✅ Тени (shadows) для компонентов
- ✅ Поддержка светлой и темной темы
- ✅ Типобезопасный доступ через extensions

## 📁 Структура темы

```
core/ui_library/lib/src/
├── theme/
│   ├── theme.dart                        # Главный файл (part'ы)
│   └── app/
│       ├── constants.dart                # Базовые цвета и стили
│       ├── light_theme.dart              # Светлая тема
│       ├── dark_theme.dart               # Темная тема
│       ├── text_theme.dart               # TextTheme для Flutter
│       ├── theme_colors.dart             # ThemeExtension для цветов
│       ├── theme_text_styles.dart        # ThemeExtension для типографики
│       ├── theme_gradients.dart          # ThemeExtension для градиентов
│       └── app_shadow.dart               # ThemeExtension для теней
│
└── extensions/
    ├── color_extension.dart              # BuildContext расширения для цветов
    ├── text_style_extension.dart         # BuildContext расширения для стилей
    └── shadow_extension.dart             # BuildContext расширения для теней
```

## 🏗️ Компоненты системы темизации

### 1. Constants (Константы)

Базовые цвета и текстовые стили.

```dart
// theme/app/constants.dart
part of '../theme.dart';

// Базовые TextStyle константы
const titleSmall = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: AppColors.blackMain,
);

const labelMedium = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: AppColors.blackMain,
);

const labelLarge = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: AppColors.blackMain,
);

const labelXL = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w400,
  color: AppColors.blackMain,
);

// Палитра цветов приложения
abstract base class AppColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color blackMain = Color(0xFF251A05);

  static const Color greenMain = Color(0xFF5EBDBC);
  static const Color greenMainHover = Color(0xFF539C97);
  static const Color greenMainTransparent = Color(0x265EBDBC); // 15% прозрачность

  static const Color purpleMain = Color(0xFF936FB0);
  static const Color orangeMain = Color(0xFFFA8C16);
  static const Color blue = Color(0xFF78BDE8);

  // Neutral scale
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFE5E5E5);
  static const Color neutral300 = Color(0xFFD4D4D4);
  static const Color neutral400 = Color(0xFFA3A3A3);
  static const Color neutral500 = Color(0xFF737373);
  static const Color neutral600 = Color(0xFF525252);
  static const Color neutral700 = Color(0xFF404040);
  static const Color neutral900 = Color(0xFF251A05);

  // Transparencies
  static const Color neutral251ATransparent = Color(0x40251A05); // 25%
  static const Color neutral251ATransparentLight = Color(0x0D251A05); // 5%

  // Status colors
  static const Color red500 = Color(0xFFF5222D);
  static const Color red600 = Color(0xFFCF1322);
  static const Color red700 = Color(0xFFA8071A);
}
```

### 2. ThemeExtension для цветов

Семантические цвета с поддержкой light/dark.

```dart
// theme/app/theme_colors.dart
part of '../theme.dart';

class ThemeColors extends ThemeExtension<ThemeColors> {
  const ThemeColors({
    required this.primary,
    required this.white,
    required this.black,
    required this.blue,
    required this.grey,
    required this.greyLight,
    required this.greyLighter,
    required this.greenMainHover,
    required this.redDefault,
    required this.successColor,
    required this.errorColor,
    required this.disableElementColor,
    required this.disableElementColorLight,
    required this.purpleMain,
    required this.orangeMain,
  });

  // Семантические цвета
  final Color primary;               // Основной цвет
  final Color white;
  final Color black;
  final Color blue;
  final Color grey;                  // Neutral500
  final Color greyLight;             // Neutral200
  final Color greyLighter;           // Neutral100
  final Color greenMainHover;        // Hover состояние
  final Color errorColor;            // Red600
  final Color redDefault;            // Red500
  final Color successColor;          // GreenMain
  final Color disableElementColor;   // 25% прозрачность
  final Color disableElementColorLight; // 5% прозрачность
  final Color purpleMain;
  final Color orangeMain;

  @override
  ThemeExtension<ThemeColors> copyWith({
    Color? primary,
    Color? white,
    // ... все поля
  }) => ThemeColors(
    primary: primary ?? this.primary,
    // ... остальные поля
  );

  @override
  ThemeExtension<ThemeColors> lerp(
    ThemeExtension<ThemeColors>? other,
    double t,
  ) {
    if (other is! ThemeColors) return this;

    return ThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      // ... все цвета с lerp
    );
  }

  // Фабрики для light и dark тем
  static ThemeColors get light => const ThemeColors(
    white: AppColors.white,
    black: AppColors.blackMain,
    primary: AppColors.greenMain,
    greenMainHover: AppColors.greenMainHover,
    errorColor: AppColors.red600,
    redDefault: AppColors.red500,
    successColor: AppColors.greenMain,
    disableElementColor: AppColors.neutral251ATransparent,
    disableElementColorLight: AppColors.neutral251ATransparentLight,
    blue: AppColors.blue,
    greyLight: AppColors.neutral200,
    greyLighter: AppColors.neutral100,
    grey: AppColors.neutral500,
    purpleMain: AppColors.purpleMain,
    orangeMain: AppColors.orangeMain,
  );

  static ThemeColors get dark => const ThemeColors(
    // ... аналогично light, но с другими цветами
    white: AppColors.white,
    black: AppColors.blackMain,
    primary: AppColors.greenMain,
    // ...
  );
}
```

### 3. ThemeExtension для типографики

Семантические текстовые стили.

```dart
// theme/app/theme_text_styles.dart
part of '../theme.dart';

class ThemeTextStyles extends ThemeExtension<ThemeTextStyles> {
  const ThemeTextStyles({
    // Заголовки
    required this.heading1,           // 38px, w700
    required this.heading2,           // 30px, w700
    required this.heading3,           // 24px, w700
    required this.heading3Light,      // 24px, w700, белый
    required this.heading4,           // 20px, w700
    required this.heading4Light,      // 20px, w700, белый
    required this.heading5,           // 16px, w700
    required this.heading5Light,      // 16px, w700, белый

    // Base (14px)
    required this.baseNormal,         // Черный
    required this.baseNormalLight,    // Белый
    required this.baseNormalGrey,     // Neutral500
    required this.baseNormalGreyLight, // Neutral400
    required this.baseStrong,         // Bold
    required this.baseUnderline,
    required this.baseDelete,
    required this.baseItalic,

    // Small (12px)
    required this.sMNormal,
    required this.sMNormalLight,
    required this.sMNormalGrey,
    required this.sMStrong,
    required this.sMUnderline,
    required this.sMDelete,
    required this.sMItalic,

    // Large (16px)
    required this.lGNormal,
    required this.lGNormalLight,
    required this.lGStrong,
    required this.lGUnderline,
    required this.lGDelete,
    required this.lGItalic,

    // XL (20px)
    required this.xlNormal,
    required this.xlStrong,
    required this.xlUnderline,
    required this.xlDelete,
    required this.xlItalic,

    // Специальные
    required this.errorText,          // 14px, w400, красный
  });

  // ... copyWith и lerp аналогично ThemeColors

  static ThemeTextStyles get light => ThemeTextStyles(
    heading1: labelXL.copyWith(
      fontSize: 38,
      fontWeight: FontWeight.w700,
    ),
    heading2: labelXL.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
    ),
    heading3: labelXL.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
    heading3Light: labelXL.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: AppColors.white,
    ),
    baseNormal: labelMedium.copyWith(),
    baseNormalLight: labelMedium.copyWith(color: AppColors.white),
    baseNormalGrey: labelMedium.copyWith(color: AppColors.neutral500),
    baseStrong: labelMedium.copyWith(fontWeight: FontWeight.w700),
    // ... остальные стили
    errorText: labelMedium.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.red600,
    ),
  );

  static ThemeTextStyles get dark => ThemeTextStyles(
    // ... аналогично light
  );
}
```

### 4. ThemeExtension для градиентов

```dart
// theme/app/theme_gradients.dart
part of '../theme.dart';

class ThemeGradients extends ThemeExtension<ThemeGradients> {
  const ThemeGradients({
    required this.mainGradient,
    required this.orangeGradient,
    required this.orangeGradientReverse,
    required this.greyGradient,
  });

  final LinearGradient mainGradient;
  final LinearGradient orangeGradient;
  final LinearGradient orangeGradientReverse;
  final LinearGradient greyGradient;

  @override
  ThemeExtension<ThemeGradients> copyWith({
    LinearGradient? mainGradient,
    LinearGradient? orangeGradient,
    LinearGradient? orangeGradientReverse,
    LinearGradient? greyGradient,
  }) => ThemeGradients(
    mainGradient: mainGradient ?? this.mainGradient,
    orangeGradient: orangeGradient ?? this.orangeGradient,
    orangeGradientReverse: orangeGradientReverse ?? this.orangeGradientReverse,
    greyGradient: greyGradient ?? this.greyGradient,
  );

  @override
  ThemeExtension<ThemeGradients> lerp(
    covariant ThemeExtension<ThemeGradients>? other,
    double t,
  ) {
    if (other is! ThemeGradients) return this;

    return ThemeGradients(
      mainGradient: LinearGradient.lerp(mainGradient, other.mainGradient, t)!,
      orangeGradient: LinearGradient.lerp(orangeGradient, other.orangeGradient, t)!,
      orangeGradientReverse: LinearGradient.lerp(
        orangeGradientReverse,
        other.orangeGradientReverse,
        t,
      )!,
      greyGradient: LinearGradient.lerp(greyGradient, other.greyGradient, t)!,
    );
  }

  static ThemeGradients get light => ThemeGradients(
    mainGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.fromRGBO(255, 255, 255, 0), // прозрачный
        Color(0xFF59B8B6), // бирюзовый
      ],
      stops: [0.2309, 0.4594],
    ),
    orangeGradient: const LinearGradient(
      colors: [
        Color(0xFFFA8C16), // оранжевый
        Color(0xFFFFD666), // желтый
      ],
      stops: [0.2309, 0.4594],
    ),
    orangeGradientReverse: const LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        Color(0xFFFA8C16),
        Color(0xFFFFD666),
      ],
      stops: [0.2309, 0.4594],
    ),
    greyGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 1.0],
      colors: [
        Color.fromRGBO(31, 32, 36, 0),
        Color.fromRGBO(31, 32, 36, 0.5),
      ],
    ),
  );

  static ThemeGradients get dark => ThemeGradients(
    // ... аналогично
  );
}
```

### 5. ThemeExtension для теней

```dart
// theme/app/app_shadow.dart
import 'package:flutter/material.dart';

class AppShadows extends ThemeExtension<AppShadows> {
  const AppShadows({
    required this.notificationShadow,
    required this.cardShadow,
    required this.modalShadow,
  });

  final List<BoxShadow> notificationShadow;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> modalShadow;

  @override
  ThemeExtension<AppShadows> copyWith({
    List<BoxShadow>? notificationShadow,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? modalShadow,
  }) {
    return AppShadows(
      notificationShadow: notificationShadow ?? this.notificationShadow,
      cardShadow: cardShadow ?? this.cardShadow,
      modalShadow: modalShadow ?? this.modalShadow,
    );
  }

  @override
  ThemeExtension<AppShadows> lerp(
    covariant ThemeExtension<AppShadows>? other,
    double t,
  ) {
    if (other is! AppShadows) return this;

    return AppShadows(
      notificationShadow: List.generate(notificationShadow.length, (index) {
        return BoxShadow.lerp(
          notificationShadow[index],
          other.notificationShadow[index],
          t,
        )!;
      }),
      cardShadow: List.generate(cardShadow.length, (index) {
        return BoxShadow.lerp(cardShadow[index], other.cardShadow[index], t)!;
      }),
      modalShadow: List.generate(modalShadow.length, (index) {
        return BoxShadow.lerp(modalShadow[index], other.modalShadow[index], t)!;
      }),
    );
  }

  static AppShadows get light => const AppShadows(
    notificationShadow: [
      BoxShadow(
        color: Color(0x0D000000),
        offset: Offset(0, 9),
        blurRadius: 28,
        spreadRadius: 8,
      ),
      BoxShadow(
        color: Color(0x0A000000),
        offset: Offset(0, 3),
        blurRadius: 6,
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Color(0x146B8B8B),
        offset: Offset(0, 6),
        blurRadius: 16,
      ),
    ],
    cardShadow: [
      BoxShadow(
        color: Color(0x0D000000),
        offset: Offset(0, 2),
        blurRadius: 8,
      ),
    ],
    modalShadow: [
      BoxShadow(
        color: Color(0x201B5656),
        offset: Offset(0, 10),
        blurRadius: 30,
      ),
    ],
  );

  static AppShadows get dark => const AppShadows(
    // ... аналогично light
  );
}
```

### 6. Создание ThemeData

```dart
// theme/app/light_theme.dart
part of '../theme.dart';

ThemeData createLightTheme(Color? seed) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed ?? AppColors.greenMain,
  );

  return ThemeData(
    colorScheme: colorScheme,
    textTheme: createTextTheme(),
    scaffoldBackgroundColor: AppColors.white,

    // ✅ Регистрируем все ThemeExtension
    extensions: <ThemeExtension<dynamic>>[
      ThemeColors.light,
      ThemeTextStyles.light,
      ThemeGradients.light,
      AppShadows.light,
    ],

    // Настройка стандартных компонентов
    appBarTheme: AppBarTheme(
      color: AppColors.white,
      iconTheme: const IconThemeData(
        color: AppColors.blackMain,
      ),
      titleTextStyle: ThemeTextStyles.light.heading3,
    ),

    iconTheme: const IconThemeData(
      color: AppColors.neutral900,
    ),

    primaryColor: AppColors.greenMain,
    canvasColor: AppColors.white,
  );
}
```

```dart
// theme/app/dark_theme.dart
part of '../theme.dart';

ThemeData createDarkTheme(Color? seed) => ThemeData(
  textTheme: createTextTheme(),
  scaffoldBackgroundColor: AppColors.white,

  extensions: <ThemeExtension<dynamic>>[
    ThemeColors.dark,
    ThemeTextStyles.dark,
    ThemeGradients.dark,
    AppShadows.dark,
  ],

  appBarTheme: AppBarTheme(
    color: AppColors.white,
    titleTextStyle: labelLarge.copyWith(
      color: AppColors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
);
```

### 7. BuildContext Extensions

Удобный доступ к теме через context.

```dart
// extensions/color_extension.dart
import 'package:flutter/material.dart';
import 'package:ui_library/src/theme/theme.dart';

extension AppColorsExt on BuildContext {
  /// Доступ к кастомным цветам
  ThemeColors get color => Theme.of(this).extension<ThemeColors>()!;

  /// Доступ к градиентам
  ThemeGradients get gradients => Theme.of(this).extension<ThemeGradients>()!;

  /// Проверка темной темы
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
```

```dart
// extensions/text_style_extension.dart
import 'package:flutter/material.dart';
import 'package:ui_library/src/theme/theme.dart';

extension AppTextStyleExtension on BuildContext {
  /// Доступ к типографике
  ThemeTextStyles get textStyles => Theme.of(this).extension<ThemeTextStyles>()!;
}
```

```dart
// extensions/shadow_extension.dart
import 'package:flutter/material.dart';
import 'package:ui_library/src/theme/app/app_shadow.dart';

extension AppShadowExtension on BuildContext {
  /// Доступ к теням
  AppShadows get shadows => Theme.of(this).extension<AppShadows>()!;
}
```

## 🎯 Использование темы в виджетах

### 1. Базовое использование

```dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // ✅ Используем кастомные цвета
      color: context.color.primary,

      // ✅ Используем кастомную типографику
      child: Text(
        'Hello',
        style: context.textStyles.heading1,
      ),
    );
  }
}
```

### 2. Градиенты

```dart
class GradientCard extends StatelessWidget {
  const GradientCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: context.gradients.mainGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Card with gradient'),
    );
  }
}
```

### 3. Тени

```dart
class CardWithShadow extends StatelessWidget {
  const CardWithShadow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.shadows.cardShadow,
      ),
      child: const Text('Card with shadow'),
    );
  }
}
```

### 4. Комбинированное использование

```dart
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    required this.name,
    required this.email,
    super.key,
  });

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.shadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Text(
            name,
            style: context.textStyles.heading4,
          ),
          const SizedBox(height: 4),

          // Подзаголовок
          Text(
            email,
            style: context.textStyles.baseNormalGrey,
          ),
          const SizedBox(height: 12),

          // Кнопка с градиентом
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              gradient: context.gradients.orangeGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'View Profile',
              style: context.textStyles.baseNormalLight,
            ),
          ),
        ],
      ),
    );
  }
}
```

## ✅ Best Practices

### 1. Используй семантические названия

```dart
// ✅ ХОРОШО - семантические
context.color.primary
context.color.errorColor
context.color.successColor

// ❌ ПЛОХО - по цвету
context.color.greenMain
context.color.red600
```

### 2. Используй extensions вместо Theme.of()

```dart
// ✅ ХОРОШО
context.color.primary
context.textStyles.heading1
context.gradients.mainGradient

// ❌ ПЛОХО
Theme.of(context).extension<ThemeColors>()!.primary
Theme.of(context).extension<ThemeTextStyles>()!.heading1
```

### 3. Группируй связанные стили

```dart
// ✅ ХОРОШО - группы стилей
heading1, heading2, heading3, heading4, heading5
baseNormal, baseStrong, baseUnderline
sMNormal, sMStrong, sMUnderline

// ❌ ПЛОХО - разрозненные
titleBig, mediumText, smallBold
```

### 4. Используй lerp для анимаций

```dart
// lerp() автоматически обрабатывает интерполяцию между темами
@override
ThemeExtension<ThemeColors> lerp(
  ThemeExtension<ThemeColors>? other,
  double t,
) {
  if (other is! ThemeColors) return this;

  return ThemeColors(
    primary: Color.lerp(primary, other.primary, t)!,
    // ...
  );
}
```

### 5. Создавай фабрики для light/dark

```dart
// ✅ ХОРОШО - фабрики
static ThemeColors get light => const ThemeColors(...);
static ThemeColors get dark => const ThemeColors(...);

// ❌ ПЛОХО - условия в коде
final colors = isDark ? ThemeColors(...) : ThemeColors(...);
```

## 🎨 Добавление нового цвета

### Шаг 1: Добавь в AppColors

```dart
// theme/app/constants.dart
abstract base class AppColors {
  // ...
  static const Color myNewColor = Color(0xFF123456);
}
```

### Шаг 2: Добавь в ThemeColors

```dart
// theme/app/theme_colors.dart
class ThemeColors extends ThemeExtension<ThemeColors> {
  const ThemeColors({
    // ...
    required this.myNewColor,
  });

  final Color myNewColor;

  @override
  ThemeExtension<ThemeColors> copyWith({
    // ...
    Color? myNewColor,
  }) => ThemeColors(
    // ...
    myNewColor: myNewColor ?? this.myNewColor,
  );

  @override
  ThemeExtension<ThemeColors> lerp(
    ThemeExtension<ThemeColors>? other,
    double t,
  ) {
    if (other is! ThemeColors) return this;

    return ThemeColors(
      // ...
      myNewColor: Color.lerp(myNewColor, other.myNewColor, t)!,
    );
  }

  static ThemeColors get light => const ThemeColors(
    // ...
    myNewColor: AppColors.myNewColor,
  );

  static ThemeColors get dark => const ThemeColors(
    // ...
    myNewColor: AppColors.myNewColor, // или другой цвет для dark
  );
}
```

### Шаг 3: Используй в коде

```dart
Container(
  color: context.color.myNewColor,
  child: const Text('Hello'),
)
```

## 🎨 Добавление нового текстового стиля

Аналогично цветам, добавь в `ThemeTextStyles`:

```dart
class ThemeTextStyles extends ThemeExtension<ThemeTextStyles> {
  const ThemeTextStyles({
    // ...
    required this.myNewStyle,
  });

  final TextStyle myNewStyle;

  // ... copyWith, lerp

  static ThemeTextStyles get light => ThemeTextStyles(
    // ...
    myNewStyle: labelLarge.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
    ),
  );
}
```

## 🚫 Что НЕ делать

1. ❌ **Не хардкодь цвета и стили**

   ```dart
   // ❌ ПЛОХО
   Container(
     color: const Color(0xFF5EBDBC),
     child: Text(
       'Hello',
       style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
     ),
   )

   // ✅ ХОРОШО
   Container(
     color: context.color.primary,
     child: Text(
       'Hello',
       style: context.textStyles.heading5,
     ),
   )
   ```

2. ❌ **Не используй Theme.of() напрямую**

   ```dart
   // ❌ ПЛОХО
   final color = Theme.of(context).extension<ThemeColors>()!.primary;

   // ✅ ХОРОШО
   final color = context.color.primary;
   ```

3. ❌ **Не создавай дубликаты цветов**

   ```dart
   // ❌ ПЛОХО
   static const Color greenPrimary = Color(0xFF5EBDBC);
   static const Color mainGreen = Color(0xFF5EBDBC);
   static const Color primaryColor = Color(0xFF5EBDBC);

   // ✅ ХОРОШО - один цвет, семантическое имя
   static const Color primary = Color(0xFF5EBDBC);
   ```

4. ❌ **Не забывай про lerp()**

   ```dart
   // ❌ ПЛОХО - анимации не будут работать
   @override
   ThemeExtension<ThemeColors> lerp(other, t) => this;

   // ✅ ХОРОШО
   @override
   ThemeExtension<ThemeColors> lerp(other, t) {
     return ThemeColors(
       primary: Color.lerp(primary, other.primary, t)!,
     );
   }
   ```

## 📚 Резюме

**Структура темы:**

1. `AppColors` - палитра базовых цветов
2. `ThemeColors` - семантические цвета с light/dark
3. `ThemeTextStyles` - типографика
4. `ThemeGradients` - градиенты
5. `AppShadows` - тени
6. Extensions - удобный доступ через context

**Использование:**

```dart
// Цвета
context.color.primary
context.color.errorColor

// Типографика
context.textStyles.heading1
context.textStyles.baseNormal

// Градиенты
context.gradients.mainGradient

// Тени
context.shadows.cardShadow

// Проверка темы
context.isDarkMode
```

**Преимущества:**

- ✅ Типобезопасность
- ✅ Автодополнение в IDE
- ✅ Централизованное управление
- ✅ Поддержка анимаций (lerp)
- ✅ Легкое переключение light/dark
- ✅ Семантические названия

---

**См. также:**

- [ui/widgets.md](widgets.md) - Создание виджетов
- [global/flutter-general.md](../global/flutter-general.md) - Flutter правила
