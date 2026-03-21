---
name: Feature Architecture
description: Anti-Clean Architecture, 3 слоя (widgets/controllers/data), модели, JSON parsing, Converter/Codec pattern, always-async repos, anti-Result type
type: flutter-skill
source: Doctorina project review by Misha/Fox (DART SIDE channel)
---

# Feature Architecture / Архитектура фичей

## Anti-Clean Architecture

> "Clean Architecture -- реально очень плохая вещь, которую нужно знать только для собеседований. Это культ, смысла особого не имеет."

> "Дядюшка Боб -- как программист полный ноль. У него нет ни одного нормального продукта. Многие люди, которые топят за Clean Architecture, не открывали даже его Git."

Здравые идеи разделения на слои существовали задолго до Clean Architecture.

### Use Cases -- не нужны

> "Вам ни в коем случае не нужно создавать никакие Use Cases. Они буквально не нужны никому на фронте."

Use Case -- лишняя прослойка между контроллером и репозиторием, которая:
- Дублирует вызов репозитория
- Добавляет бесполезный файл
- Не несёт реальной ценности на фронте

## 3 Layers / 3 слоя

Правильное разделение -- **три слоя** с понятными названиями:

```
feature/
  widgets/      # UI -- виджеты, экраны
  controllers/  # Логика -- стейт-машины
  data/         # Данные -- репозитории, модели
```

> "Давайте прямо так: widgets, data, controller. Любой человек, который на это взглянет, поймёт, что примерно тут ожидается."

### Зачем разделять

Разделение нужно **не для абстрактной красоты**, а потому что человек -- "мясо" с ограниченным окном контекста в голове:

> "Если что-то большое, запутанное, зависимость на зависимость, сайд-эффект на сайд-эффект -- вы сойдёте с ума."

Если метод на 20-30 строк -- разбивать не нужно. Если разросся до 200+ строк -- пора рефакторить.

### Widgets Layer (Виджеты)

- Только отображение и обработка пользовательских действий
- **Никакой бизнес-логики**
- Подписка на стейт контроллера
- Вызов методов контроллера с onSuccess/onError callbacks

### Controllers Layer (Контроллеры)

- Стейт-машина (Idle/Processing/Failed)
- Вызовы репозитория
- Обработка ошибок (runZoneGuarded, try-catch)
- **Никаких Flutter-импортов** (кроме foundation)
- **Никаких виджетов, контекстов, навигаторов**

### Data Layer (Данные)

- Репозитории (без состояния)
- Модели
- Конвертеры (JSON parsing)
- HTTP-запросы, база данных

## Models / Модели

### Правило: модели не зависят от реализации

> "Никаких Drift'ов, никаких JSON-зависимостей, никаких Hive. Модельки должны быть обычные, самые обычные."

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

> "Я сразу закладываю защиту дурака. Пишу updated, last_updated, last_updated_at и так далее."

## Always-Async Repos / Всегда асинхронные репозитории

### Правило: все методы репозитория -- async

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

> "Ни в коем случае не завязывайте синхронность на реализацию. Это грубейшая ошибка."

### Почему

Сейчас настройки из SharedPreferences (синхронные). Завтра нужно получать с бэкенда или из SQLite (асинхронно). Рефакторинг синхронного интерфейса в асинхронный **очень болезненный**:

- Все вызовы нужно обернуть в await
- Конструкторы контроллеров, которые использовали синхронные вызовы, сломаются
- Каскадный рефакторинг по всему проекту

> "Будет очень больно. Все методы у репозитория делайте асинхронными. Если у вас есть синхронные методы -- это с большой долей вероятности костыль."

## Anti-Result Type Pattern

> "Крайне негативно отношусь к Result type. Прямо супер негативно."

### Почему Result тип вреден во Flutter/Dart

```dart
// С Result type вы пишете:
// 1. В каждом data provider: try-catch -> Result.error
// 2. В каждом репозитории: try-catch -> Result.error
// 3. В контроллере: снова обработка Result

// Вы написали кучу кода, чтобы всё равно ловить ошибки в контроллере
```

Dart изначально построен на исключениях, не на Result-монаде (как Go). Попытка натянуть Result:
- Дублирует try-catch на каждом уровне
- Добавляет бесполезный boilerplate
- В контроллере всё равно нужно обрабатывать ошибки

> "Если бы Dart изначально был выстроен по концепции Go, где возвращаешь либо результат, либо ошибку -- то да. А здесь абсолютно не имеет смысла."

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

// Контроллер: ловит ВСЕ ошибки в одном месте
Future<void> create() async {
  try {
    final chat = await _repository.createChat();
    setState(IdleState(data: chat));
  } on Object catch (error) {
    setState(FailedState(error: error));
  }
}
```

## Key Takeaways / Ключевые выводы

1. **Три слоя**: widgets / controllers / data -- не больше
2. **Никаких Use Cases** -- лишняя прослойка
3. Модели -- чистые, без зависимостей от библиотек
4. **Converter/Codec** pattern для сложного парсинга
5. **Все** методы репозитория -- async (даже если сейчас синхронные)
6. **Anti-Result type** -- Dart построен на исключениях, Result добавляет boilerplate
7. Рефакторинг -- для уменьшения когнитивной нагрузки, не для абстрактной красоты
