# SOLID Принципы

> Применяется ко всем файлам в проекте

## 🎯 SOLID - это фундамент чистого кода

### S - Single Responsibility Principle (Принцип единственной ответственности)

**Правило:** Класс должен иметь только одну причину для изменения.

**❌ ПЛОХО:**

```dart
// Класс делает слишком много: управляет пользователем, БД и API
final class UserManager {
  Future<void> saveUser(User user) async {
    // Валидация
    if (user.email.isEmpty) throw Exception('Invalid email');

    // Сохранение в БД
    await database.insert('users', user.toJson());

    // Отправка на сервер
    await http.post('/users', body: user.toJson());

    // Аналитика
    analytics.logEvent('user_saved');
  }
}
```

**✅ ХОРОШО:**

```dart
// Разделили на отдельные классы с одной ответственностью

// 1. Валидация
final class UserValidator {
  void validate(User user) {
    if (user.email.isEmpty) {
      throw ValidationException('Invalid email');
    }
  }
}

// 2. Локальное хранилище
abstract interface class UserLocalDataSource {
  Future<void> saveUser(User user);
}

final class UserLocalDataSourceImpl implements UserLocalDataSource {
  const UserLocalDataSourceImpl({required AppDatabase database})
      : _database = database;

  final AppDatabase _database;

  @override
  Future<void> saveUser(User user) async {
    await _database.usersDao.insertUser(user);
  }
}

// 3. Удаленное хранилище
abstract interface class UserRemoteDataSource {
  Future<void> saveUser(User user);
}

final class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  const UserRemoteDataSourceImpl({required RestClient restClient})
      : _restClient = restClient;

  final RestClient _restClient;

  @override
  Future<void> saveUser(User user) async {
    await _restClient.post('/users', data: user.toJson());
  }
}

// 4. Репозиторий координирует работу
final class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl({
    required UserValidator validator,
    required UserLocalDataSource localDataSource,
    required UserRemoteDataSource remoteDataSource,
    required Analytics analytics,
  })  : _validator = validator,
        _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _analytics = analytics;

  final UserValidator _validator;
  final UserLocalDataSource _localDataSource;
  final UserRemoteDataSource _remoteDataSource;
  final Analytics _analytics;

  @override
  Future<void> saveUser(User user) async {
    _validator.validate(user);
    await _localDataSource.saveUser(user);
    await _remoteDataSource.saveUser(user);
    _analytics.logEvent('user_saved');
  }
}
```

### O - Open/Closed Principle (Принцип открытости/закрытости)

**Правило:** Классы должны быть открыты для расширения, но закрыты для модификации.

**❌ ПЛОХО:**

```dart
// При добавлении нового типа нужно модифицировать класс
final class PaymentProcessor {
  Future<void> processPayment(String type, double amount) async {
    if (type == 'card') {
      // Логика карты
    } else if (type == 'paypal') {
      // Логика PayPal
    } else if (type == 'crypto') {
      // Логика криптовалюты
    }
  }
}
```

**✅ ХОРОШО:**

```dart
// Используем интерфейс - можно добавлять новые способы оплаты без изменения кода
abstract interface class PaymentMethod {
  Future<void> process(double amount);
}

final class CardPayment implements PaymentMethod {
  @override
  Future<void> process(double amount) async {
    // Логика карты
  }
}

final class PayPalPayment implements PaymentMethod {
  @override
  Future<void> process(double amount) async {
    // Логика PayPal
  }
}

final class CryptoPayment implements PaymentMethod {
  @override
  Future<void> process(double amount) async {
    // Логика криптовалюты
  }
}

final class PaymentProcessor {
  const PaymentProcessor({required PaymentMethod paymentMethod})
      : _paymentMethod = paymentMethod;

  final PaymentMethod _paymentMethod;

  Future<void> processPayment(double amount) async {
    await _paymentMethod.process(amount);
  }
}
```

### L - Liskov Substitution Principle (Принцип подстановки Лисков)

**Правило:** Объекты подкласса должны вести себя так же, как объекты базового класса.

**❌ ПЛОХО:**

```dart
abstract class Bird {
  void fly();
}

class Sparrow extends Bird {
  @override
  void fly() {
    print('Flying!');
  }
}

class Penguin extends Bird {
  @override
  void fly() {
    throw Exception('Penguins cannot fly!'); // ❌ Нарушает контракт
  }
}
```

**✅ ХОРОШО:**

```dart
// Разделили на правильные абстракции
abstract class Bird {
  void eat();
}

abstract class FlyingBird extends Bird {
  void fly();
}

final class Sparrow extends FlyingBird {
  @override
  void eat() {
    print('Eating seeds');
  }

  @override
  void fly() {
    print('Flying!');
  }
}

final class Penguin extends Bird {
  @override
  void eat() {
    print('Eating fish');
  }

  void swim() {
    print('Swimming!');
  }
}
```

### I - Interface Segregation Principle (Принцип разделения интерфейса)

**Правило:** Клиенты не должны зависеть от интерфейсов, которые они не используют.

**❌ ПЛОХО:**

```dart
// Слишком большой интерфейс
abstract interface class Worker {
  void work();
  void eat();
  void sleep();
  void getPaid();
  void attendMeeting();
}

// Робот не ест и не спит, но вынужден реализовывать эти методы
final class Robot implements Worker {
  @override
  void work() {
    print('Working');
  }

  @override
  void eat() {
    throw UnimplementedError(); // ❌ Не нужно
  }

  @override
  void sleep() {
    throw UnimplementedError(); // ❌ Не нужно
  }

  @override
  void getPaid() {
    throw UnimplementedError(); // ❌ Не нужно
  }

  @override
  void attendMeeting() {
    throw UnimplementedError(); // ❌ Не нужно
  }
}
```

**✅ ХОРОШО:**

```dart
// Разделили на маленькие специфичные интерфейсы
abstract interface class Workable {
  void work();
}

abstract interface class Eatable {
  void eat();
}

abstract interface class Sleepable {
  void sleep();
}

abstract interface class Payable {
  void getPaid();
}

abstract interface class MeetingAttendable {
  void attendMeeting();
}

// Робот реализует только то, что ему нужно
final class Robot implements Workable {
  @override
  void work() {
    print('Working');
  }
}

// Человек реализует все
final class Human implements Workable, Eatable, Sleepable, Payable, MeetingAttendable {
  @override
  void work() => print('Working');

  @override
  void eat() => print('Eating');

  @override
  void sleep() => print('Sleeping');

  @override
  void getPaid() => print('Getting paid');

  @override
  void attendMeeting() => print('Attending meeting');
}
```

### D - Dependency Inversion Principle (Принцип инверсии зависимостей)

**Правило:** Зависеть нужно от абстракций, а не от конкретных реализаций.

**❌ ПЛОХО:**

```dart
// BLoC зависит от конкретной реализации
final class UserBloc {
  UserBloc() : _api = UserApiImpl(); // ❌ Жесткая зависимость

  final UserApiImpl _api; // ❌ Конкретная реализация

  Future<void> fetchUser() async {
    final user = await _api.getUser();
    // ...
  }
}

final class UserApiImpl {
  Future<User> getUser() async {
    // Реализация
  }
}
```

**✅ ХОРОШО:**

```dart
// BLoC зависит от абстракции (интерфейса)
abstract interface class UserRepository {
  Future<User> fetchUser();
}

final class UserBloc {
  const UserBloc({
    required UserRepository repository, // ✅ Абстракция
  }) : _repository = repository;

  final UserRepository _repository; // ✅ Интерфейс

  Future<void> fetchUser() async {
    final user = await _repository.fetchUser();
    // ...
  }
}

// Реализация может быть любой
final class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl({
    required UserRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final UserRemoteDataSource _remoteDataSource;

  @override
  Future<User> fetchUser() async {
    final dto = await _remoteDataSource.getUser();
    return dto.toEntity();
  }
}

// Легко подменить на Mock для тестов
final class MockUserRepository implements UserRepository {
  @override
  Future<User> fetchUser() async {
    return User(id: '1', name: 'Mock User');
  }
}
```

## 🎯 Применение SOLID в проекте

### Repository Pattern с SOLID

```dart
// ✅ Правильная архитектура с соблюдением SOLID

// D - Зависимость от абстракции
abstract interface class UserRepository {
  Future<User> fetchUser();
  Future<void> updateUser(User user);
}

// I - Разделение интерфейсов
abstract interface class UserRemoteDataSource {
  Future<UserDto> fetchUser();
  Future<void> updateUser(UserDto dto);
}

abstract interface class UserLocalDataSource {
  Future<UserDto?> getCachedUser();
  Future<void> cacheUser(UserDto dto);
}

// S - Единственная ответственность
final class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl({
    required UserRemoteDataSource remoteDataSource,
    required UserLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final UserRemoteDataSource _remoteDataSource;
  final UserLocalDataSource _localDataSource;

  @override
  Future<User> fetchUser() async {
    try {
      final dto = await _remoteDataSource.fetchUser();
      await _localDataSource.cacheUser(dto);
      return dto.toEntity();
    } catch (e) {
      final cachedDto = await _localDataSource.getCachedUser();
      if (cachedDto != null) {
        return cachedDto.toEntity();
      }
      rethrow;
    }
  }

  @override
  Future<void> updateUser(User user) async {
    final dto = UserDto.fromEntity(user);
    await _remoteDataSource.updateUser(dto);
    await _localDataSource.cacheUser(dto);
  }
}
```

## ✅ Checklist SOLID

- [ ] **S**: Каждый класс делает только одно дело?
- [ ] **O**: Можно добавить функциональность без изменения существующего кода?
- [ ] **L**: Подклассы можно использовать вместо базовых классов?
- [ ] **I**: Интерфейсы маленькие и специфичные?
- [ ] **D**: Зависимости от абстракций, а не конкретных реализаций?

## 🚀 Преимущества SOLID

1. ✅ **Легко тестировать** - можно мокировать зависимости
2. ✅ **Легко расширять** - новый функционал без изменения старого
3. ✅ **Легко поддерживать** - каждый класс делает одно дело
4. ✅ **Легко понимать** - четкое разделение ответственности
5. ✅ **Гибкость** - легко менять реализации
