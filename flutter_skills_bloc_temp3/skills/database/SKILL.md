---
name: database
description: Use when working with databases — Drift/SQLite, SQL-based DDL, migrations, multi-isolate support, key-value storage in SQLite, DateTime UTC best practices. MUST use for any database, migration, data storage, or DateTime handling questions in Flutter.
---

# Database / База данных

## Drift (SQLite)

Используй Drift для SQLite на нативных платформах. SharedPreferences — для веба.

### Почему не SQLite на вебе

WASM-сборка SQLite довольно тяжёлая, и надёжность оставляет желать лучшего. Используй SharedPreferences под вебом.

Разделение:
- **Нативные платформы** (Android, iOS, macOS, Windows, Linux): Drift/SQLite
- **Web**: SharedPreferences

```dart
// При инициализации:
if (kIsWeb) {
  deps.storage = SharedPreferencesStorage();
} else {
  deps.database = await DriftDatabase.initialize();
}
```

## SQL-based DDL / Объявление таблиц через SQL

Объявляй таблицы через SQL DDL, а не в объектном виде:

```dart
// ПРЕДПОЧТИТЕЛЬНО — SQL DDL:
@DriftDatabase(
  include: {'tables.drift'},
)
class AppDatabase extends _$AppDatabase { ... }

// tables.drift:
CREATE TABLE chats (
  id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE messages (
  id TEXT PRIMARY KEY NOT NULL,
  chat_id TEXT NOT NULL REFERENCES chats(id),
  content TEXT NOT NULL,
  role TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_messages_chat ON messages(chat_id);
```

Не используй объектный стиль Drift:

```dart
// Менее предпочтительно — объектный стиль:
class Chats extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  // ...
}
```

## Migrations / Миграции

Drift поддерживает миграции через DDL:

```dart
@override
int get schemaVersion => 3;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async {
    await m.createAll();
  },
  onUpgrade: (Migrator m, int from, int to) async {
    if (from < 2) {
      await m.addColumn(chats, chats.updatedAt);
    }
    if (from < 3) {
      await m.createIndex(idx_messages_chat);
    }
  },
);
```

## Multi-Isolate Support / Работа из нескольких изолятов

Drift поддерживает запуск в отдельном изоляте и переиспользование БД из нескольких изолятов:

```dart
// Один инстанс SQLite, несколько изолятов обращаются к нему
final database = DriftDatabase(
  LazyDatabase(() async {
    final file = await getDbFile();
    return NativeDatabase(file);
  }),
);
```

## Key-Value Storage в SQLite

Вместо отдельного key-value хранилища используй таблицу в SQLite:

```sql
CREATE TABLE key_value (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT
);
```

Это даёт:
- Единый источник данных (одна БД)
- Транзакционность
- Работу из нескольких изолятов
- Кэш в единой базе

## DateTime UTC — критически важно

Не передавай дату как local time. Всегда используй UTC.

### Проблема

```dart
// DateTime.now() — локальное время:
print(DateTime.now());
// 2024-07-12 15:30:00.000
// Нет таймзоны! Сервер подумает, что это его локальное время

// Ошибка накапливается:
// Клиент (Москва +3) -> Сервер (UTC) -> Клиент (переехал в UTC+5)
// Каждая конвертация сдвигает время
```

### Решение

```dart
// ВСЕГДА UTC:
print(DateTime.now().toUtc());
// 2024-07-12T12:30:00.000Z  <-- Z означает UTC

// В модели:
class Message {
  final DateTime createdAt; // Всегда UTC!

  Message({required this.createdAt});

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      createdAt: DateTime.parse(json['created_at']).toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}
```

### Правила

1. **Передавай** на сервер — всегда UTC
2. **Требуй** от сервера — всегда UTC
3. **Храни** в базе — всегда UTC
4. **Отображай** пользователю — конвертируй в local

```dart
// Отображение:
Text(DateFormat.yMd().format(message.createdAt.toLocal()))
```

### Если нужна таймзона пользователя

Передавай отдельным полем. Отдельно время в UTC и отдельно таймзона:

```json
{
  "created_at": "2024-07-12T12:30:00.000Z",
  "user_timezone": "+03:00"
}
```

### Проверка в middleware/assert

Добавь assert в middleware HTTP-клиента для проверки, что все DateTime в запросах — UTC:

```dart
assert(
  requestBody['created_at'].endsWith('Z'),
  'DateTime must be in UTC',
);
```

## Key Takeaways

1. **Drift/SQLite** для нативных платформ, **SharedPreferences** для веба
2. SQL DDL предпочтительнее объектного стиля Drift
3. Multi-isolate поддержка — несколько изолятов, одна БД
4. **DateTime ВСЕГДА в UTC** — передача, хранение, получение
5. Таймзону пользователя — отдельным полем, не в DateTime
6. Локальное время только для отображения пользователю
7. Key-value можно хранить в той же SQLite
