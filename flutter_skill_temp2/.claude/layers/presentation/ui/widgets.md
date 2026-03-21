# Создание виджетов

> Применяется к виджетам в **/widget/**

## Принципы создания виджетов

### 1. Извлечение виджетов, чтобы вертка не была слишком большой и не было сложности с читаемостью кода

**❌ НЕ ТАК:**

```dart
class ProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _buildImage(),
          _buildTitle(),
          _buildPrice(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildImage() => Image.network(imageUrl);
  Widget _buildTitle() => Text(title);
  Widget _buildPrice() => Text('\$$price');
  Widget _buildActions() => Row(children: [...]);
}
```

**✅ ТАК:**

```dart
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.product,
    this.onTap,
    super.key,
  });

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            _ProductImage(url: product.imageUrl),
            _ProductTitle(title: product.title),
            _ProductPrice(price: product.price),
            _ProductActions(product: product),
          ],
        ),
      ),
    );
  }
}

final class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.network(
        url,
        fit: BoxFit.cover,
      ),
    );
  }
}

final class _ProductTitle extends StatelessWidget {
  const _ProductTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
```

## Когда извлекать виджет?

**✅ Извлекай когда:**

- Виджет содержит > 5-7 элементов
- Виджет имеет сложную логику
- Виджет переиспользуется
- Виджет имеет собственное состояние
- Виджет замедляет производительность

**❌ Не извлекай когда:**

- Простой виджет из 1-3 элементов
- Одноразовый виджет без логики
- Inline виджеты типа `SizedBox`, `Padding`

### 2. Извлечение методов из верстки, чтобы вертка не была слишком большой и не было сложности с читаемостью кода

```dart
final class ButtonApp extends StatelessWidget {
 const ButtonApp({required this.title});

 final String title;
 final bool isLoading;

 @override
 Widget build(BuildContext context) {
   return ElevatedButton(
     onPressed: isLoading ? null : _onPressed,
     child: isLoading
         ? const SizedBox(
             height: 20,
             width: 20,
             child: CircularProgressIndicator(strokeWidth: 2),
           )
         : Text(text),
   );
 }

 void _onPressed () {
   print("Click bttn!");
 }
}
```

### 3. Приватные vs Публичные виджеты

**Приватные виджеты** (`_WidgetName`):

```dart
// Используются только внутри файла
final class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) => Card(...);
}
```

**Публичные виджеты** (`WidgetName`):

```dart
// Экспортируются и используются в других модулях
final class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, super.key});

  final Product product;

  @override
  Widget build(BuildContext context) => Card(...);
}
```

## 4. Типы виджетов

### 1. Screen Widget (Экраны)

```dart
// Корневой виджет экрана с BlocProvider
final class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UserProfileBloc(
        userProfileRepository: context.read(),
      )..add(const UserProfileEvent.fetch()),
      child: const _UserProfileView(),
    );
  }
}

// View виджет с Scaffold
final class _UserProfileView extends StatelessWidget {
  const _UserProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: BlocBuilder<UserProfileBloc, UserProfileState>(
        builder: (context, state) {
          return switch (state) {
            UserProfileState$Processing() => const LoadingWidget(),
            UserProfileState$Success(:final data) => _ProfileContent(user: data),
            UserProfileState$Error(:final error) => ErrorWidget(message: error),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}
```

### 2. Content Widget (Контент)

```dart
// Приватный виджет для отображения контента
final class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});

  final UserProfileEntity user;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 16),
          _ProfileInfo(user: user),
          const SizedBox(height: 16),
          _ProfileActions(user: user),
        ],
      ),
    );
  }
}
```

### 3. Component Widget (Компоненты)

```dart
// Переиспользуемый компонент из ui_library
final class AppButton extends StatelessWidget {
  const AppButton({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.type = AppButtonType.primary,
    super.key,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: _getButtonStyle(theme),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(text),
    );
  }

  ButtonStyle _getButtonStyle(ThemeData theme) {
    return switch (type) {
      AppButtonType.primary => ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
        ),
      AppButtonType.secondary => ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
        ),
      AppButtonType.outlined => OutlinedButton.styleFrom(
          side: BorderSide(color: theme.colorScheme.primary),
        ),
    };
  }
}

enum AppButtonType { primary, secondary, outlined }
```

## 5. Использование const

```dart
// ✅ ХОРОШО - все const где возможно
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('Title'),
        SizedBox(height: 16),
        _MyWidget(),
      ],
    );
  }
}

// ❌ ПЛОХО - забыли const
class MyScreen extends StatelessWidget {
  MyScreen({super.key});  // <- нет const

  @override
  Widget build(BuildContext context) {
    return Column(  // <- нет const
      children: [
        Text('Title'),  // <- нет const
        SizedBox(height: 16),  // <- нет const
        _MyWidget(),  // <- нет const
      ],
    );
  }
}
```

## 6. Производительность

### 1. Используй const constructors

```dart
// ✅ ХОРОШО
const Text('Hello')
const SizedBox(height: 16)
const Icon(Icons.home)

// ❌ ПЛОХО
Text('Hello')
SizedBox(height: 16)
Icon(Icons.home)
```

### 2. Используй RepaintBoundary, только если это нужно

```dart
// Изолируй часто перерисовываемые виджеты
RepaintBoundary(
  child: AnimatedWidget(...),
)
```

### 3. Используй ListView.builder

```dart
// ✅ ХОРОШО для больших списков
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(title: Text(items[index]));
  },
)

// ❌ ПЛОХО для больших списков
ListView(
  children: items.map((item) => ListTile(title: Text(item))).toList(),
)
```

### 4. Избегай Opacity, используй AnimatedOpacity

```dart
// ✅ ХОРОШО
AnimatedOpacity(
  opacity: _isVisible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 300),
  child: MyWidget(),
)

// ❌ ПЛОХО - медленно
Opacity(
  opacity: _isVisible ? 1.0 : 0.0,
  child: MyWidget(),
)
```

## ✅ Best Practices

1. ✅ Используй `const` везде где возможно
2. ✅ Извлекай сложные виджеты в отдельные классы
3. ✅ Используй `final class` для виджетов
4. ✅ Документируй публичные виджеты
5. ✅ Проверяй `mounted` перед использованием `context` после async
6. ✅ Используй `key` для виджетов в списках
7. ✅ Оптимизируй с помощью `RepaintBoundary` и `ListView.builder`

## 🚫 Что НЕ делать

1. ❌ Не создавай методы `_buildXXX()` - создавай отдельные виджеты
2. ❌ Не забывай про `dispose()` в StatefulWidget
3. ❌ Не используй `context` после async без проверки `mounted`
4. ❌ Не игнорируй `const` constructors
5. ❌ Не создавай слишком большие виджеты (> 300 строк)
6. ❌ Не используй глобальные ключи без необходимости
