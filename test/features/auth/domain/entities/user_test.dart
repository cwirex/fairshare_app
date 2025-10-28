import 'package:fairshare_app/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User', () {
    test('should serialize to JSON correctly', () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John Doe',
        email: 'john@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        phone: '+1234567890',
        lastSyncTimestamp: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Act
      final json = user.toJson();

      // Assert
      expect(json['id'], 'user1');
      expect(json['display_name'], 'John Doe');
      expect(json['email'], 'john@example.com');
      expect(json['avatar_url'], 'https://example.com/avatar.jpg');
      expect(json['phone'], '+1234567890');
    });

    test('should deserialize from JSON correctly', () {
      // Arrange
      final json = {
        'id': 'user1',
        'display_name': 'John Doe',
        'email': 'john@example.com',
        'avatar_url': 'https://example.com/avatar.jpg',
        'phone': '+1234567890',
        'last_sync_timestamp': '2025-01-01T00:00:00.000',
        'created_at': '2025-01-01T00:00:00.000',
        'updated_at': '2025-01-01T00:00:00.000',
      };

      // Act
      final user = User.fromJson(json);

      // Assert
      expect(user.id, 'user1');
      expect(user.displayName, 'John Doe');
      expect(user.email, 'john@example.com');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.phone, '+1234567890');
    });

    test('should handle optional fields correctly', () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(user.avatarUrl, ''); // Default value
      expect(user.phone, isNull);
      expect(user.lastSyncTimestamp, isNull);
    });

    test('hasAvatar should return true when avatarUrl is not empty', () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John Doe',
        email: 'john@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(user.hasAvatar, true);
    });

    test('hasAvatar should return false when avatarUrl is empty', () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(user.hasAvatar, false);
    });

    test('hasPhone should return true when phone is provided', () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John Doe',
        email: 'john@example.com',
        phone: '+1234567890',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(user.hasPhone, true);
    });

    test('hasPhone should return false when phone is null', () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(user.hasPhone, false);
    });

    test('initials should return first letters of first and last name', () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(user.initials, 'JD');
    });

    test('initials should return first letter for single name', () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John',
        email: 'john@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(user.initials, 'J');
    });

    test('initials should return ? for empty name', () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: '',
        email: 'john@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(user.initials, '?');
    });

    test('hasNeverSynced should return true when lastSyncTimestamp is null',
        () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(user.hasNeverSynced, true);
    });

    test('hasNeverSynced should return false when lastSyncTimestamp is set',
        () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John Doe',
        email: 'john@example.com',
        lastSyncTimestamp: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(user.hasNeverSynced, false);
    });

    test('copyWith should create copy with updated fields', () {
      // Arrange
      final user = User(
        id: 'user1',
        displayName: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Act
      final updated = user.copyWith(displayName: 'Jane Doe');

      // Assert
      expect(updated.id, 'user1');
      expect(updated.displayName, 'Jane Doe');
      expect(updated.email, 'john@example.com');
    });
  });
}
