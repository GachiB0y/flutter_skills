# База данных (Drift + SQLite)

## Цель

Type-safe работа с SQLite через Drift ORM с автогенерацией кода.

---

## Архитектура

### Stack

```yaml
dependencies:
  drift: latest
  drift_flutter: latest

dev_dependencies:
  drift_dev: latest
  build_runner: latest
```

### Структура

```
core/database/
├── lib/
│   ├── database.dart              # Public API
│   └── src/
│       ├── database.dart          # AppDatabase класс
│       ├── database.g.dart        # Автогенерация
│       ├── tables/                # Table definitions
│       ├── data/                  # DataSources, Wrappers
│       ├── logic/                 # Business logic
│       └── models/                # Domain models
└── test/
    └── database_test.dart
```

---

## Правило: Определяй таблицы через Table классы

**Обоснование:** Type-safety, автогенерация, compile-time валидация

### Базовая таблица

```dart
import 'package:drift/drift.dart';

@DataClassName('User')
class UsersTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text().unique()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
```

### Foreign Key

```dart
@DataClassName('Order')
class OrdersTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
    UsersTable,
    #id,
    onDelete: KeyAction.cascade,  // ✅ Каскадное удаление
  )();
  TextColumn get productName => text()();
  RealColumn get totalPrice => real()();
  DateTimeColumn get orderDate => dateTime().withDefault(currentDateAndTime)();
}
```

### Композитный unique key

```dart
@DataClassName('Product')
class ProductsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sku => text()();
  TextColumn get region => text()();
  TextColumn get name => text()();

  @override
  List<Set<Column>>? get uniqueKeys => [
    {sku, region},  // ✅ Уникальная пара
  ];
}
```

---

## 🔧 Правило: Регистрируй таблицы в @DriftDatabase

**Обоснование:** Централизация, версионирование, миграции

### Минимальная конфигурация

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DriftDatabase(tables: [UsersTable, OrdersTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase.defaults({required String name})
      : super(
          driftDatabase(
            name: name,
            native: const DriftNativeOptions(shareAcrossIsolates: true),
            web: DriftWebOptions(/* ... */),  // Cross-platform
          ),
        );

  @override
  int get schemaVersion => 1;
}
```

### С миграциями

```dart
@DriftDatabase(tables: [UsersTable, OrdersTable])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async => await m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from == 1 && to == 2) {
          await m.addColumn(usersTable, usersTable.phoneNumber);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');  // ✅ Обязательно
      },
    );
  }
}
```

---

## Генерация кода

```bash
make gen         # Однократно
make gen-watch   # Непрерывно
```

**Генерируется:**

- Data классы с toJson/fromJson
- Companion классы для insert/update
- Query builders

---

## Правило: Используй транзакции для комплексных операций

**Обоснование:** Атомарность, rollback, консистентность

```dart
Future<int> createOrderWithItems({
  required int userId,
  required List<OrderItem> items,
}) async {
  return await transaction(() async {
    // Все или ничего
    final orderId = await into(ordersTable).insert(/* ... */);

    for (final item in items) {
      await into(orderItemsTable).insert(/* ... */);
    }

    await _decrementStock(items);

    return orderId;
  });
}
```

---

## 🧩 Domain Models

```dart
class OrderWithDetails {
  const OrderWithDetails({
    required this.order,
    required this.user,
    required this.items,
  });

  final Order order;
  final User user;
  final List<OrderItem> items;
}

// Получение в AppDatabase
Future<OrderWithDetails?> getOrderWithDetails(int orderId) async {
  return await transaction(() async {
    final order = await getOrderById(orderId);
    if (order == null) return null;

    final user = await getUserById(order.userId);
    final items = await getOrderItems(orderId);

    return OrderWithDetails(order: order, user: user, items: items);
  });
}
```

---

## ⚡ Реактивные запросы

```dart
// Stream вместо Future
Stream<List<User>> watchActiveUsers() {
  return (select(usersTable)
    ..where((t) => t.isActive.equals(true))
  ).watch();  // ⚡ Автообновление
}

// В UI
StreamBuilder<List<User>>(
  stream: database.watchActiveUsers(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    return ListView(children: snapshot.data!.map(/* ... */).toList());
  },
)
```

---

## 🔄 Миграции

### Добавление колонки

```dart
// 1. Добавь в Table
TextColumn get phoneNumber => text().nullable()();  // nullable!

// 2. Увеличь версию
@override
int get schemaVersion => 2;

// 3. Миграция
onUpgrade: (m, from, to) async {
  if (from == 1 && to == 2) {
    await m.addColumn(usersTable, usersTable.phoneNumber);
  }
}
```

### Создание таблицы

```dart
// 1. Создай Table класс
// 2. Добавь в @DriftDatabase(tables: [...])
// 3. schemaVersion++
// 4. onUpgrade: await m.createTable(newTable);
```

---

## Тестирование

```dart
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => await database.close());

  test('создание пользователя', () async {
    final id = await database.createUser(email: 'test@test.com', name: 'Test');
    final user = await database.getUserById(id);

    expect(user, isNotNull);
    expect(user!.email, 'test@test.com');
  });

  test('rollback транзакции', () async {
    await database.createUser(email: 'user1@test.com', name: 'User 1');

    await expectLater(
      () => database.transaction(() async {
        await database.createUser(email: 'user2@test.com', name: 'User 2');
        throw Exception('Error');
      }),
      throwsException,
    );

    final users = await database.getAllUsers();
    expect(users, hasLength(1));  // ✅ Второй не создан
  });
}
```

---

## Anti-patterns

| ❌ ПЛОХО         | ✅ ХОРОШО                   |
| ---------------- | --------------------------- |
| Raw SQL запросы  | Query builders              |
| Без транзакций   | `transaction(() async { })` |
| BLOB для файлов  | Храни путь к файлу          |
| Забыть FK pragma | `PRAGMA foreign_keys = ON`  |
| Все NOT NULL     | Nullable для опциональных   |

---

## Best Practices

| Практика           | Решение                        |
| ------------------ | ------------------------------ |
| **Запросы**        | Query builders, не raw SQL     |
| **Транзакции**     | Для всех комплексных операций  |
| **Foreign Keys**   | Включай через PRAGMA + CASCADE |
| **Default values** | `.withDefault()` в Table       |
| **Файлы**          | Путь в TEXT, не BLOB           |
| **Тесты**          | In-memory database             |
| **Версии**         | Увеличивай `schemaVersion`     |
| **Генерация**      | `make gen` после изменений     |

---

## Индексы

```dart
@override
List<Index> get customIndexes => [
  Index('idx_users_email', [email]),           // ✅ Частые поиски
  Index('idx_orders_user_date', [userId, orderDate]),  // Композитный
];
```

---

## Workflow добавления таблицы

```
1. Создай tables/new_table.dart
2. Extends Table, определи колонки
3. Добавь в @DriftDatabase(tables: [])
4. schemaVersion++
5. Добавь миграцию onUpgrade
6. make gen
7. Напиши методы
8. Тесты
```

---
