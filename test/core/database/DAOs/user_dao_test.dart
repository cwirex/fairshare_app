import 'package:drift/native.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('UserDao', () {
    test('insertUser should add user to database', () async {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Act
      await database.userDao.insertUser(user);

      // Assert
      final retrieved = await database.userDao.getUserById('user1');
      expect(retrieved, isNotNull);
      expect(retrieved!.displayName, 'Test User');
      expect(retrieved.email, 'test@example.com');
    });

    test('insertUser should replace existing user (upsert)', () async {
      // Arrange
      final user1 = User(
        id: 'user1',
        displayName: 'Original Name',
        email: 'original@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.userDao.insertUser(user1);

      final user2 = User(
        id: 'user1',
        displayName: 'Updated Name',
        email: 'updated@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
      );

      // Act
      await database.userDao.insertUser(user2);

      // Assert
      final retrieved = await database.userDao.getUserById('user1');
      expect(retrieved!.displayName, 'Updated Name');
      expect(retrieved.email, 'updated@example.com');
    });

    test('getUserById should return null for non-existent user', () async {
      // Act
      final result = await database.userDao.getUserById('nonexistent');

      // Assert
      expect(result, isNull);
    });

    test('updateUser should update existing user', () async {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'Original Name',
        email: 'original@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.userDao.insertUser(user);

      final updated = User(
        id: 'user1',
        displayName: 'Updated Name',
        email: 'updated@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
      );

      // Act
      await database.userDao.updateUser(updated);

      // Assert
      final retrieved = await database.userDao.getUserById('user1');
      expect(retrieved!.displayName, 'Updated Name');
    });

    test('deleteUser should remove user from database', () async {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.userDao.insertUser(user);

      // Act
      await database.userDao.deleteUser('user1');

      // Assert
      final retrieved = await database.userDao.getUserById('user1');
      expect(retrieved, isNull);
    });
  });
}
