# Создание Core модулей

## 🎯 Цель документа

Научить создавать **Core модули** в едином Flutter репозитории:

- Переиспользуемые компоненты без бизнес-логики
- Модули, независимые от Feature модулей
- Обеспечить единую структуру Core модулей
- Все модули находятся в `lib/src/core/`

---

## Что такое Core модуль?

**Core модуль** - это переиспользуемая папка в `lib/src/core/`, которая:

- ❌ **НЕ содержит** бизнес-логику приложения
- ✅ **Содержит** общую функциональность (logger, network, database, UI kit)
- ✅ **Может использоваться** любым Feature модулем
- ❌ **НЕ зависит** от Feature модулей
- ⚠️ **Минимально зависит** от других Core модулей

### Примеры Core модулей

- `database` - работа с БД (Drift)
- `rest_client` - HTTP клиент
- `ui_library` - UI компоненты (кнопки, карточки, inputs)
- `logger` - логирование
- `analytics` - аналитика
- `error_reporter` - отчеты об ошибках (Sentry)
- `translations` - локализация
- `navigator_api` - навигация
- `common` - общие утилиты и расширения

---

## Структура Core модуля

```
lib/src/core/
└── my_module/
    ├── my_interface.dart        # Интерфейс
    ├── my_impl.dart             # Реализация
    ├── models/                  # Модели (если нужны)
    │   └── my_model.dart
    └── utils/                   # Утилиты (если нужны)
        └── my_helper.dart

# Тесты
test/src/core/my_module/
└── my_impl_test.dart
```

### Ключевые принципы структуры

1. **Простота** - Core модуль должен быть простым и понятным
2. **Интерфейс + Реализация** - всегда используй abstract interface class
3. **Минимум зависимостей** - избегай зависимостей от других Core модулей
4. **Package импорты** - используй полные пути `package:template_flutter_claude/src/...`

---

## Правила работы с Core модулями

### Правило 1: Интерфейс + Реализация

**Правило:**
Всегда создавай `abstract interface class` для Core модуля

**Обоснование:**

- **Тестируемость**: Легко мокировать в тестах
- **Гибкость**: Можно заменить реализацию
- **Dependency Inversion**: Зависимость от абстракции, а не реализации

**Пример:**

```dart
// ✅ ХОРОШО - интерфейс + реализация
// lib/src/core/logger/app_logger.dart
abstract interface class AppLogger {
  void debug(String message);
  void error(String message, {Object? error, StackTrace? stackTrace});
}

// lib/src/core/logger/app_logger_impl.dart
final class AppLoggerImpl implements AppLogger {
  @override
  void debug(String message) => print('[DEBUG] $message');

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    print('[ERROR] $message');
    if (error != null) print('Error: $error');
  }
}

// ❌ ПЛОХО - только реализация без интерфейса
final class AppLogger {
  void debug(String message) => print('[DEBUG] $message');
}
```

### Правило 2: Полные package импорты

**Правило:**
Всегда используй полные package импорты вместо относительных

**Обоснование:**

- **Явность**: Четко видно откуда импортируется модуль
- **IDE поддержка**: Автоматический рефакторинг работает лучше
- **Единообразие**: Один стиль импортов во всем проекте

**Пример:**

```dart
// ✅ ПРАВИЛЬНО - полные package импорты
import 'package:template_flutter_claude/src/core/logger/app_logger.dart';
import 'package:template_flutter_claude/src/core/rest_client/rest_client.dart';

// ❌ НЕПРАВИЛЬНО - относительные импорты
import '../logger/app_logger.dart';
import '../../feature/auth/auth_bloc.dart';
```

---

## Быстрый старт

### Создание нового Core модуля

**Используем Make команду:**

```bash
make create-core NAME=cache
```

Эта команда автоматически создаст:

- ✅ Структуру папок `lib/src/core/cache/`
- ✅ Файл интерфейса `cache.dart`
- ✅ Файл реализации `cache_impl.dart`
- ✅ Тестовый файл `test/src/core/cache/cache_test.dart`
- ✅ README с инструкциями

**Или вручную:**

**Шаг 1**: Создать папку модуля

```bash
mkdir -p lib/src/core/my_module
mkdir -p test/src/core/my_module
```

**Шаг 2**: Создать файлы интерфейса и реализации

```bash
touch lib/src/core/my_module/my_module.dart
touch lib/src/core/my_module/my_module_impl.dart
touch test/src/core/my_module/my_module_impl_test.dart
```

**Шаг 3**: Реализовать интерфейс

```dart
// lib/src/core/my_module/my_module.dart
abstract interface class MyModule {
  Future<void> doSomething();
}

// lib/src/core/my_module/my_module_impl.dart
import 'package:template_flutter_claude/src/core/my_module/my_module.dart';

final class MyModuleImpl implements MyModule {
  @override
  Future<void> doSomething() async {
    // Implementation
  }
}
```

**Шаг 4**: Написать тесты

```dart
// test/src/core/my_module/my_module_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:template_flutter_claude/src/core/my_module/my_module_impl.dart';

void main() {
  group('MyModuleImpl', () {
    test('should do something', () async {
      // Arrange
      final module = MyModuleImpl();

      // Act
      await module.doSomething();

      // Assert
      // Add assertions
    });
  });
}
```

---

## Примеры Core модулей

### Пример 1: Logger

```dart
// lib/src/core/logger/app_logger.dart
abstract interface class AppLogger {
  void debug(String message);
  void info(String message);
  void error(String message, {Object? error, StackTrace? stackTrace});
}

// lib/src/core/logger/app_logger_impl.dart
final class AppLoggerImpl implements AppLogger {
  @override
  void debug(String message) => print('[DEBUG] $message');

  @override
  void info(String message) => print('[INFO] $message');

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    print('[ERROR] $message');
    if (error != null) print('Error: $error');
    if (stackTrace != null) print('StackTrace: $stackTrace');
  }
}
```

### Пример 2: REST Client

```dart
// lib/src/core/rest_client/rest_client.dart
import 'package:dio/dio.dart';

abstract interface class RestClient {
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  });

  Future<Response<T>> post<T>(
    String path, {
    Map<String, dynamic>? data,
  });
}

// lib/src/core/rest_client/rest_client_impl.dart
import 'package:dio/dio.dart';
import 'package:template_flutter_claude/src/core/logger/app_logger.dart';
import 'package:template_flutter_claude/src/core/rest_client/rest_client.dart';

final class RestClientImpl implements RestClient {
  RestClientImpl({
    required this.baseUrl,
    required this.logger,
  }) : _dio = Dio(BaseOptions(baseUrl: baseUrl));

  final String baseUrl;
  final AppLogger logger;
  final Dio _dio;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    logger.debug('GET $path');
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } catch (e) {
      logger.error('GET $path failed', error: e);
      rethrow;
    }
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    logger.debug('POST $path');
    try {
      return await _dio.post<T>(path, data: data);
    } catch (e) {
      logger.error('POST $path failed', error: e);
      rethrow;
    }
  }
}
```

---

## Важные замечания

❗ **Используй полные package импорты:**

```dart
// ✅ Правильно
import 'package:template_flutter_claude/src/core/logger/app_logger.dart';

// ❌ Неправильно
import '../logger/app_logger.dart';
```

❗ **Минимизируй зависимости между Core модулями:**

Core модули должны быть максимально независимыми. Допустимы зависимости только на общие утилиты (например, logger).

❗ **Используй Dependency Injection для регистрации:**

[Подробнее о DI в проекте](../architecture/dependency-injection.md)

---

## Checklist создания Core модуля

- [ ] Создана структура через `make create-core NAME=my_module`
- [ ] Создан интерфейс (`abstract interface class`)
- [ ] Создана реализация интерфейса (`final class`)
- [ ] Написаны unit тесты в `test/src/core/my_module/`
- [ ] Добавлена документация (dartdoc комментарии)
- [ ] Настроена регистрация в DI (если нужно)
- [ ] Проверена работа с другими модулями
- [ ] Используются полные package импорты

---

## 🔗 См. также

- [Feature модули](./feature-modules.md) - создание Feature модулей
- [Dependency Injection](../architecture/dependency-injection.md) - настройка DI
- [Тестирование](../testing/) - гайды по тестированию
