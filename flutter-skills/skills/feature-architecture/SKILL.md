---
name: feature-architecture
description: Use when creating a new feature, organizing code into layers, defining models, parsing JSON, or choosing between Result type and exceptions. MUST use for any new feature creation, architecture decisions, or model/repository design in Flutter. Covers 3-layer architecture (widgets/bloc/data), Converter/Codec pattern, always-async repos.
---

# Feature Architecture / Архитектура фичей

## Anti-Clean Architecture

Используй прагматичный подход с тремя слоями вместо Clean Architecture. Clean Architecture добавляет избыточные абстракции (Use Cases, Domain Layer), которые на фронтенде не оправданы.

Здравые идеи разделения на слои существовали задолго до Clean Architecture.

### Use Cases -- не нужны

Не создавай Use Cases. Они буквально не нужны на фронте.

Use Case -- лишняя прослойка между BLoC и репозиторием, которая:
- Дублирует вызов репозитория
- Добавляет бесполезный файл
- Не несёт реальной ценности на фронте

## 3 Layers / 3 слоя

Организуй фичу в три папки: `widgets/`, `bloc/`, `data/`.

```
feature/
  widgets/      # UI -- виджеты, экраны
  bloc/         # Логика -- стейт-машины
  data/         # Данные -- репозитории, модели
```

Любой человек, который на это взглянет, поймёт, что примерно тут ожидается.

### Зачем разделять

Разделение нужно **не для абстрактной красоты**, а потому что человек -- "мясо" с ограниченным окном контекста в голове.

Если метод на 20-30 строк -- разбивать не нужно. Если разросся до 200+ строк -- пора рефакторить.

### Widgets Layer (Виджеты)

- Только отображение и обработка пользовательских действий
- **Никакой бизнес-логики**
- Подписка на стейт BLoC
- Вызов методов BLoC с onSuccess/onError callbacks

### BLoC Layer (BLoC)

- Стейт-машина (Idle/Processing/Success/Error)
- Вызовы репозитория
- Обработка ошибок через handle() метод
- **Никаких Flutter-импортов** (кроме foundation)
- **Никаких виджетов, контекстов, навигаторов**

### Data Layer (Данные)

- Репозитории (без состояния)
- Модели
- Конвертеры (JSON parsing)
- HTTP-запросы, база данных

## Models / Модели

### Правило: модели не зависят от реализации

Не добавляй зависимости от библиотек в модели. Модели должны быть чистыми.

```dart
// ПРАВИЛЬНО -- чистая модель
class ChatEntity {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<Message> messages;

  const ChatEntity({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });
}

// НЕПРАВИЛЬНО -- зависимость от реализации
@HiveType(typeId: 0)
class ChatEntity extends HiveObject { ... }
```

Интерфейс репозитория должен возвращать **ваши** модели, не модели библиотек.

## JSON Parsing / Конвертация из JSON

### Три варианта размещения

#### 1. В репозитории (для простых случаев)

```dart
class ChatRepositoryImpl implements ChatRepository {
  @override
  Future<ChatEntity> getChat(String id) async {
    final response = await client.get('/chat/$id');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ChatEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      // ...
    );
  }
}
```

#### 2. fromJson factory (для средних случаев)

```dart
class ChatEntity {
  // ...
  factory ChatEntity.fromJson(Map<String, dynamic> json) {
    return ChatEntity(
      id: json['id'] as String,
      title: json['title'] as String,
    );
  }
}
```

**Важно:** `fromJson` -- небезопасная операция, может бросить ошибку.

#### 3. Converter/Codec pattern (для сложных случаев)

Используется стандартный Dart `Converter` / `Codec`:

```dart
// Конвертер: Map -> ChatEntity
class ChatEntityDecoder extends Converter<Map<String, dynamic>, ChatEntity> {
  const ChatEntityDecoder();

  @override
  ChatEntity convert(Map<String, dynamic> input) {
    return ChatEntity(
      id: input['id'] as String,
      title: input['title'] as String,
      // ...
    );
  }
}

// Кодек: двусторонняя конвертация
class ChatEntityCodec extends Codec<ChatEntity, Map<String, dynamic>> {
  const ChatEntityCodec();

  @override
  Converter<Map<String, dynamic>, ChatEntity> get decoder => const ChatEntityDecoder();

  @override
  Converter<ChatEntity, Map<String, dynamic>> get encoder => const ChatEntityEncoder();
}
```

Преимущества Converter/Codec:
- Часть стандартной библиотеки Dart
- Поддержка fuse (композиция конвертеров)
- Работа со стримами (`stream.transform(decoder)`)
- Чёткое разделение encode/decode

### Pattern Matching при парсинге сложных структур

```dart
// Парсинг чат-событий через pattern matching:
ChatEntity parseEvent(Map<String, dynamic> json) {
  return switch (json['type']) {
    'user_message' => parseUserMessage(json),
    'assistant_message' => parseAssistantMessage(json),
    'status_update' => parseStatusUpdate(json),
    _ => throw FormatException('Unknown event type: ${json['type']}'),
  };
}
```

### Защита от битых данных

```dart
// Проверка нескольких вариантов названий полей:
final updatedAt = json['updated_at']
    ?? json['updatedAt']
    ?? json['last_updated']
    ?? json['last_updated_at'];

// Fallback для отсутствующих полей:
final title = json['title']?.toString() ?? 'Untitled';
```

Сразу закладывай защиту дурака. Проверяй updated, last_updated, last_updated_at и так далее.

## Always-Async Repos / Всегда асинхронные репозитории

### Правило: все методы репозитория -- async

Не делай синхронные методы в репозитории. Все методы — async.

```dart
// ПРАВИЛЬНО
abstract class SettingsRepository {
  Future<Settings> getSettings();
  Future<void> saveSettings(Settings settings);
}

// НЕПРАВИЛЬНО -- синхронный метод
abstract class SettingsRepository {
  Settings getSettings();  // ОШИБКА!
}
```

### Почему

Сейчас настройки из SharedPreferences (синхронные). Завтра нужно получать с бэкенда или из SQLite (асинхронно). Рефакторинг синхронного интерфейса в асинхронный **очень болезненный**:

- Все вызовы нужно обернуть в await
- Конструкторы BLoC, которые использовали синхронные вызовы, сломаются
- Каскадный рефакторинг по всему проекту

Все методы у репозитория делай асинхронными. Если есть синхронные методы -- это с большой долей вероятности костыль.

## Anti-Result Type Pattern

В этом подходе предпочитаются исключения вместо Result type. Dart изначально построен на исключениях, и Result type добавляет неоправданный boilerplate.

### Почему Result тип вреден во Flutter/Dart

```dart
// С Result type вы пишете:
// 1. В каждом data provider: try-catch -> Result.error
// 2. В каждом репозитории: try-catch -> Result.error
// 3. В BLoC: снова обработка Result

// Вы написали кучу кода, чтобы всё равно ловить ошибки в BLoC
```

Dart изначально построен на исключениях, не на Result-монаде (как Go). Попытка натянуть Result:
- Дублирует try-catch на каждом уровне
- Добавляет бесполезный boilerplate
- В BLoC всё равно нужно обрабатывать ошибки

### Правильный подход

```dart
// Репозиторий: просто бросает ошибки (естественно для Dart)
class ChatRepositoryImpl implements ChatRepository {
  @override
  Future<ChatEntity> createChat() async {
    final response = await client.post('/chat');
    // Ошибка? Пусть летит!
    return ChatEntity.fromJson(jsonDecode(response.body));
  }
}

// BLoC: ловит ВСЕ ошибки в одном месте
Future<void> create() async {
  try {
    final chat = await _repository.createChat();
    setState(SuccessState(data: chat));
  } on Object catch (error) {
    setState(ErrorState(error: error));
  }
}
```

## Key Takeaways / Ключевые выводы

1. **Три слоя**: widgets / bloc / data -- не больше
2. **Никаких Use Cases** -- лишняя прослойка
3. Модели -- чистые, без зависимостей от библиотек
4. **Converter/Codec** pattern для сложного парсинга
5. **Все** методы репозитория -- async (даже если сейчас синхронные)
6. **Anti-Result type** -- Dart построен на исключениях, Result добавляет boilerplate
7. Рефакторинг -- для уменьшения когнитивной нагрузки, не для абстрактной красоты
