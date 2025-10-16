import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupEntity', () {
    final now = DateTime.now();
    final testGroup = GroupEntity(
      id: 'group123',
      displayName: 'Test Group',
      avatarUrl: 'https://example.com/avatar.png',
      isPersonal: false,
      defaultCurrency: 'USD',
      createdAt: now,
      updatedAt: now,
      lastActivityAt: now,
      deletedAt: null,
    );

    group('JSON serialization', () {
      test('toJson should serialize correctly', () {
        final json = testGroup.toJson();

        expect(json['id'], 'group123');
        expect(json['display_name'], 'Test Group');
        expect(json['avatar_url'], 'https://example.com/avatar.png');
        expect(json['is_personal'], false);
        expect(json['default_currency'], 'USD');
        expect(json['created_at'], isA<String>());
        expect(json['updated_at'], isA<String>());
        expect(json['last_activity_at'], isA<String>());
        expect(json['deleted_at'], null);
      });

      test('fromJson should deserialize from ISO8601 strings', () {
        final json = {
          'id': 'group123',
          'display_name': 'Test Group',
          'avatar_url': 'https://example.com/avatar.png',
          'is_personal': false,
          'default_currency': 'USD',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'last_activity_at': now.toIso8601String(),
          'deleted_at': null,
        };

        final group = GroupEntity.fromJson(json);

        expect(group.id, 'group123');
        expect(group.displayName, 'Test Group');
        expect(group.avatarUrl, 'https://example.com/avatar.png');
        expect(group.isPersonal, false);
        expect(group.defaultCurrency, 'USD');
        expect(group.createdAt, isA<DateTime>());
        expect(group.updatedAt, isA<DateTime>());
        expect(group.lastActivityAt, isA<DateTime>());
        expect(group.deletedAt, null);
      });

      test('fromJson should deserialize from Firestore Timestamps', () {
        final timestamp = Timestamp.fromDate(now);
        final json = {
          'id': 'group123',
          'display_name': 'Test Group',
          'avatar_url': 'https://example.com/avatar.png',
          'is_personal': false,
          'default_currency': 'USD',
          'created_at': timestamp,
          'updated_at': timestamp,
          'last_activity_at': timestamp,
          'deleted_at': null,
        };

        final group = GroupEntity.fromJson(json);

        expect(group.id, 'group123');
        expect(group.displayName, 'Test Group');
        expect(group.createdAt, isA<DateTime>());
        expect(group.updatedAt, isA<DateTime>());
        expect(group.lastActivityAt, isA<DateTime>());
      });

      test('roundtrip serialization preserves data', () {
        final json = testGroup.toJson();
        final deserialized = GroupEntity.fromJson(json);

        expect(deserialized.id, testGroup.id);
        expect(deserialized.displayName, testGroup.displayName);
        expect(deserialized.avatarUrl, testGroup.avatarUrl);
        expect(deserialized.isPersonal, testGroup.isPersonal);
        expect(deserialized.defaultCurrency, testGroup.defaultCurrency);
      });
    });

    group('default values', () {
      test('should apply default values when missing', () {
        final json = {
          'id': 'group123',
          'display_name': 'Test Group',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'last_activity_at': now.toIso8601String(),
        };

        final group = GroupEntity.fromJson(json);

        expect(group.avatarUrl, '');
        expect(group.isPersonal, false);
        expect(group.defaultCurrency, 'USD');
        expect(group.deletedAt, null);
      });
    });

    group('extensions', () {
      test('isDeleted should return true when deletedAt is set', () {
        final deletedGroup = testGroup.copyWith(deletedAt: now);
        expect(deletedGroup.isDeleted, true);
      });

      test('isDeleted should return false when deletedAt is null', () {
        expect(testGroup.isDeleted, false);
      });

      test('isActive should return true when deletedAt is null', () {
        expect(testGroup.isActive, true);
      });

      test('isActive should return false when deletedAt is set', () {
        final deletedGroup = testGroup.copyWith(deletedAt: now);
        expect(deletedGroup.isActive, false);
      });

      test('key should return id', () {
        expect(testGroup.key, 'group123');
      });
    });
  });
}
