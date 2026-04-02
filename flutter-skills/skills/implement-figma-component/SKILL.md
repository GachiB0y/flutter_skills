---
name: implement-figma-component
description: Use when implementing a UI component from a Figma design. MUST use when the user provides a Figma link or screenshot and asks to implement a widget/component. Covers step-by-step workflow from Figma inspection to code review.
---

# Implement Figma Component / Реализация компонента из Figma

## Необходимые артефакты

Перед началом убедись, что у тебя есть:
1. Ссылка на компонент в Figma (или скриншот)
2. Путь до файла, где будет реализован компонент

Если пользователь не предоставил — запроси.

## Порядок реализации

### Шаг 1: Изучи тему приложения

Прочитай файлы темы проекта, чтобы понять доступные цвета, стили текста, тени и градиенты. Ищи файлы:
- `theme_colors.dart` — кастомные цвета
- `theme_text_styles.dart` — типографика
- `theme_gradients.dart` — градиенты
- `app_shadow.dart` — тени

Подробнее о системе темизации — см. скилл `theming`.

### Шаг 2: Изучи компонент в Figma

Через MCP Figma (если доступен) или по скриншоту:
- Определи размеры, отступы, скругления
- Соотнеси цвета с переменными из темы
- Определи типографику (heading, base, sm и т.д.)
- Найди иконки/изображения в проекте

### Шаг 3: Определи зависимости

- Какие данные принимает компонент (props)?
- Есть ли callback'и (onTap, onChanged)?
- Зависит ли от других компонентов?
- Нужен ли BLoC или это чистый UI?

### Шаг 4: Реализуй компонент

Следуй правилам из `references/widgets.md`:
- Извлекай подвиджеты в отдельные `final class` (не методы `_build`)
- Используй `const` конструкторы
- Используй `context.color.xxx`, `context.textStyles.xxx` вместо хардкода
- Приватные подвиджеты с `_` префиксом
- `super.key` в конструкторе публичных виджетов

### Шаг 5: Код-ревью

1. Запусти `make autofix SCOPE=<путь/к/файлу>` (если Makefile доступен)
2. Запусти `make analyze SCOPE=<путь/к/файлу>` или `flutter analyze`
3. Проверь:
   - Все цвета из темы, не захардкожены
   - Все стили текста из темы
   - Const constructors где возможно
   - Нет методов `_buildXxx()` — только отдельные виджеты
   - Публичные виджеты задокументированы
