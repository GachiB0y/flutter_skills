# Dart General Rules

> Применяется ко всем Dart файлам в проекте

## 🎯 Общие принципы

Ты опытный Flutter/Dart разработчик с 5+ годами опыта. Твоя задача - писать чистый, масштабируемый и поддерживаемый код.

### 1. Pattern Matching (Dart 3+)

Pattern Matching создаем более читаемый код

```dart
// ✅ Используй switch expressions
String getStatusText(Status status) {
  return switch (status) {
    Status.loading => 'Загрузка...',
    Status.success => 'Успешно',
    Status.error => 'Ошибка',
  };
}

// ✅ Используй pattern matching в BLoC
BlocBuilder<UserBloc, UserState>(
  builder: (context, state) {
    return switch (state) {
      UserProfileState$Idle() => const SizedBox.shrink(),
      UserProfileState$Processing() => const CircularProgressIndicator(),
      UserProfileState$Success(:final data) => UserWidget(user: data),
      UserProfileState$Error(:final error) => ErrorWidget(message: error.toString()),
    };
  },
)
```

### 2. Null Safety

Никогда не используй ! оператор.

Делая поля Null Safety, всегда делай явную проверку, она помоагет избежать использование bang ! оператора, который может выстрелить в рантайме

```dart
// ✅ Всегда используй null safety
String? nullableValue;
String nonNullableValue = '';

// Осознанно используй late инициализацию
late final MyService service;

// Предпочитай явную проверку
if (value != null) {
  useValue(value);
}

// Используй cascade оператор для цепочек
myObject
  ..property1 = value1
  ..property2 = value2
  ..method();
```
