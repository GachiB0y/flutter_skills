---
name: navigation
description: Use when implementing navigation in Flutter — declarative Navigator with pages list, change() method, deep linking, sealed class pages. MUST use for any navigation setup, screen transitions, deep links, or routing questions. Covers why NOT to use GoRouter or other routing packages.
---

# Navigation / Навигация

## Custom Declarative Navigator / Кастомный декларативный навигатор

Используй собственный навигатор без сторонних пакетов. Никаких GoRouter.

### Navigator vs Router -- это разные вещи

- **Navigator** -- стек экранов с анимациями (карточная стопочка)
- **Router** -- синхронизация состояния навигации с платформой (URL в браузере)

Это вещи, которые работают отдельно. Декларативная навигация не требует роутера.

**Router не нужен большинству приложений**, особенно:
- Если не делаете веб
- Если не нужны deep links через URL
- Если начинающий разработчик

Не тащи роутер. Используй просто декларативный навигатор. Его хватит для всего.

Router можно добавить в **любой момент** позже -- они независимы.

## Declarative Navigation / Декларативная навигация

### Базовая структура Navigator

```dart
Navigator(
  pages: _pages,  // List<Page> -- список страниц
  onDidRemovePage: _onDidRemovePage,  // Обработка удаления
  reportsRouteUpdateToEngine: false,  // Не менять URL автоматически
  transitionDelegate: _transitionDelegate,  // Кастомные анимации
  observers: [_navigationObserver],  // Middleware для навигации
)
```

Два главных поля:
1. `pages` -- список страниц (List<Page>)
2. `onDidRemovePage` -- когда страница удалена из стека

### Как это работает

Навигация -- это просто **изменение списка Page** и вызов `setState`:

```dart
// Изменяете список pages:
_pages = [ChatPage(), SettingsPage()];
setState(() {});
// Навигатор сам анимирует переходы
```

## Метод change -- ядро навигации

Метод `change` — ядро навигации. Через него реализуется любая навигация.

```dart
void change(List<Page> Function(List<Page> currentPages) modifier) {
  setState(() {
    _pages = modifier(List.of(_pages));
  });
}
```

Принимает функцию: текущее состояние -> желаемое состояние.

### Примеры использования

#### Push (добавить экран)

```dart
AppNavigator.change(context, (pages) {
  return [...pages, SettingsPage()];
});
```

#### Pop (убрать верхний экран)

```dart
AppNavigator.change(context, (pages) {
  if (pages.length > 1) {
    return pages.sublist(0, pages.length - 1);
  }
  return pages;
});
```

#### Remove конкретный экран

```dart
AppNavigator.change(context, (pages) {
  return pages.where((p) => p is! SettingsPage).toList();
});
```

#### Reset к главному экрану

```dart
AppNavigator.change(context, (pages) {
  return [ChatPage()]; // Неважно, что было -- теперь только Chat
});
```

#### Показать Settings поверх текущего стека (без дубликатов)

```dart
AppNavigator.change(context, (pages) {
  final filtered = pages.where((p) => p is! SettingsPage).toList();
  return [...filtered, SettingsPage()];
});
```

#### Deep link с восстановлением стека

```dart
AppNavigator.change(context, (pages) {
  return [
    HomePage(),
    CategoryPage(id: categoryId),
    ProductPage(id: productId),
  ];
});
```

## Pages как Sealed Class

Pages -- это не виджеты. Не называй экраны HomePage, SettingsPage как виджеты. Page оставляй для навигатора.

```dart
sealed class AppPage extends Page<void> {
  const AppPage();
}

class ChatPage extends AppPage {
  const ChatPage();

  @override
  Route<void> createRoute(BuildContext context) {
    return MaterialPageRoute(
      settings: this,
      builder: (_) => const ChatScreen(),
    );
  }
}

class SettingsPage extends AppPage {
  const SettingsPage();

  @override
  Route<void> createRoute(BuildContext context) {
    return MaterialPageRoute(
      settings: this,
      builder: (_) => const SettingsScreen(),
    );
  }
}

// Page с параметрами:
class ProductPage extends AppPage {
  final String productId;
  const ProductPage({required this.productId});

  @override
  LocalKey get key => ValueKey('product_$productId');

  @override
  Route<void> createRoute(BuildContext context) {
    return MaterialPageRoute(
      settings: this,
      builder: (_) => ProductScreen(productId: productId),
    );
  }
}
```

### Зачем sealed class, а не enum

Enum подходит только для простых кейсов (без параметров). Sealed class позволяет:
- Передавать параметры (productId, categoryId)
- Задавать уникальные ключи (для правильной идентификации в стеке)
- Кастомные анимации через `createRoute`

### Ключи (keys)

Ключи необходимы, когда:
- В стеке может быть несколько страниц одного типа (категория -> подкатегория -> подкатегория)
- Навигатор должен различать страницы при перестановках

```dart
class CategoryPage extends AppPage {
  final String categoryId;
  const CategoryPage({required this.categoryId});

  @override
  LocalKey get key => ValueKey('category_$categoryId');
  // Навигатор различает Category(id: 1) от Category(id: 2)
}
```

## Deep Linking без Router

Deep link получается **до навигатора** в main:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Получаем стартовый deep link
  final initialRoute = PlatformDispatcher.instance.defaultRouteName;
  // или: WidgetsBinding.instance.defaultRouteName

  // Передаём в NavigationController
  // После инициализации формируем начальный стек pages
}
```

Формирование стека из deep link:

```dart
List<AppPage> pagesFromDeepLink(String route) {
  if (route.startsWith('/settings')) {
    return [ChatPage(), SettingsPage()];
  }
  if (route.startsWith('/product/')) {
    final id = route.split('/').last;
    return [HomePage(), ProductPage(productId: id)];
  }
  return [ChatPage()]; // По умолчанию
}
```

## Анимации

За анимации отвечает **Page** через `createRoute`, а не навигатор:

```dart
class FadeInPage extends AppPage {
  @override
  Route<void> createRoute(BuildContext context) {
    return PageRouteBuilder(
      settings: this,
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (_, animation, __) => FadeTransition(
        opacity: animation,
        child: MyScreen(),
      ),
    );
  }
}
```

## Отдельный навигатор для аутентификации

Аутентификация использует **свой отдельный Navigator** (или просто switch виджетов), размещённый в AuthScope -- выше основного навигатора.

```dart
// В AuthenticationScope:
@override
Widget build(BuildContext context) {
  if (user is AuthenticatedUser) {
    return widget.child; // Основной навигатор приложения
  }
  return AuthNavigator(); // Отдельный навигатор для логина
  // или просто LoginScreen() без навигатора
}
```

## Key Takeaways / Ключевые выводы

1. **Метод change** -- единственный метод для любой навигации (push, pop, reset, deep link)
2. Pages -- sealed class, не виджеты (виджеты называйте Screen)
3. Navigator и Router -- **независимые** вещи, Router не нужен большинству
4. Deep link получать в main через `PlatformDispatcher.instance.defaultRouteName`
5. Никаких GoRouter и подобных пакетов -- это всё из коробки
6. За анимации отвечает Page (createRoute), не Navigator
7. Отдельный навигатор для аутентификации (в AuthScope)
8. Ключи обязательны для одинаковых типов страниц с разными параметрами
