# Widget Creation Rules / Правила создания виджетов

> Этот файл -- справочник. Основной скилл: ui-layout/SKILL.md

## Принципы создания виджетов

### 1. Извлечение виджетов в отдельные классы

Извлекай виджет в отдельный класс, а не в метод `_buildXXX()`. Методы увеличивают ресурсы на перестроение, потому что Flutter сравнивает типы виджетов, а метод возвращает тот же тип.

НЕ ТАК:

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

ТАК:

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
      child: Image.network(url, fit: BoxFit.cover),
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

### 2. Когда извлекать виджет

Извлекай виджет когда:

- Виджет содержит больше 5-7 элементов
- Виджет имеет сложную логику
- Виджет переиспользуется
- Виджет имеет собственное состояние
- Виджет замедляет производительность

Не извлекай виджет когда:

- Простой виджет из 1-3 элементов
- Одноразовый виджет без логики
- Inline виджеты типа `SizedBox`, `Padding`

### 3. Приватные vs Публичные виджеты

Приватные виджеты (`_WidgetName`) -- используй только внутри файла:

```dart
final class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) => Card(...);
}
```

Публичные виджеты (`WidgetName`) -- экспортируй для использования в других модулях:

```dart
final class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, super.key});

  final Product product;

  @override
  Widget build(BuildContext context) => Card(...);
}
```

### 4. Типы виджетов

#### Screen Widget (Экраны)

Корневой виджет экрана с BlocProvider:

```dart
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

#### Content Widget (Контент)

Приватный виджет для отображения контента экрана:

```dart
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

#### Component Widget (Компоненты)

Переиспользуемый компонент:

```dart
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

### 5. Использование const

Используй `const` везде где возможно:

```dart
// ХОРОШО
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

// ПЛОХО
class MyScreen extends StatelessWidget {
  MyScreen({super.key}); // нет const

  @override
  Widget build(BuildContext context) {
    return Column( // нет const
      children: [
        Text('Title'), // нет const
        SizedBox(height: 16), // нет const
      ],
    );
  }
}
```

### 6. Производительность

Используй const constructors для всех виджетов без динамических данных:

```dart
const Text('Hello')
const SizedBox(height: 16)
const Icon(Icons.home)
```

Используй RepaintBoundary для изоляции часто перерисовываемых виджетов:

```dart
RepaintBoundary(
  child: AnimatedWidget(...),
)
```

Используй ListView.builder для больших списков вместо ListView с children:

```dart
// ХОРОШО
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(title: Text(items[index]));
  },
)

// ПЛОХО
ListView(
  children: items.map((item) => ListTile(title: Text(item))).toList(),
)
```

Избегай Opacity, используй AnimatedOpacity:

```dart
// ХОРОШО
AnimatedOpacity(
  opacity: _isVisible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 300),
  child: MyWidget(),
)

// ПЛОХО
Opacity(
  opacity: _isVisible ? 1.0 : 0.0,
  child: MyWidget(),
)
```

## Что делать

1. Используй `const` везде где возможно
2. Извлекай сложные виджеты в отдельные классы, а не методы
3. Используй `final class` для виджетов
4. Документируй публичные виджеты
5. Проверяй `mounted` перед использованием `context` после async
6. Используй `key` для виджетов в списках
7. Оптимизируй с помощью `RepaintBoundary` и `ListView.builder`

## Чего не делать

1. Не создавай методы `_buildXXX()` -- создавай отдельные виджеты-классы
2. Не забывай про `dispose()` в StatefulWidget
3. Не используй `context` после async без проверки `mounted`
4. Не игнорируй `const` конструкторы
5. Не создавай виджеты больше 300 строк
6. Не используй глобальные ключи без необходимости
