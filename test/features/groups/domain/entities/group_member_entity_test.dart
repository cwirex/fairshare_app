import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupMemberEntity', () {
    test('should serialize to JSON correctly', () {
      // Arrange
      final member = GroupMemberEntity(
        groupId: 'group1',
        userId: 'user1',
        joinedAt: DateTime(2025, 1, 1),
      );

      // Act
      final json = member.toJson();

      // Assert
      expect(json['group_id'], 'group1');
      expect(json['user_id'], 'user1');
      expect(json['joined_at'], isNotNull);
    });

    test('should deserialize from JSON correctly', () {
      // Arrange
      final json = {
        'group_id': 'group1',
        'user_id': 'user1',
        'joined_at': '2025-01-01T00:00:00.000',
      };

      // Act
      final member = GroupMemberEntity.fromJson(json);

      // Assert
      expect(member.groupId, 'group1');
      expect(member.userId, 'user1');
      expect(member.joinedAt, DateTime(2025, 1, 1));
    });

    test('key should return composite key of groupId and userId', () {
      // Arrange
      final member = GroupMemberEntity(
        groupId: 'group1',
        userId: 'user1',
        joinedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(member.key, 'group1-user1');
    });

    test('copyWith should create copy with updated fields', () {
      // Arrange
      final member = GroupMemberEntity(
        groupId: 'group1',
        userId: 'user1',
        joinedAt: DateTime(2025, 1, 1),
      );

      // Act
      final updated = member.copyWith(joinedAt: DateTime(2025, 1, 2));

      // Assert
      expect(updated.groupId, 'group1');
      expect(updated.userId, 'user1');
      expect(updated.joinedAt, DateTime(2025, 1, 2));
    });

    test('equality should work correctly', () {
      // Arrange
      final member1 = GroupMemberEntity(
        groupId: 'group1',
        userId: 'user1',
        joinedAt: DateTime(2025, 1, 1),
      );
      final member2 = GroupMemberEntity(
        groupId: 'group1',
        userId: 'user1',
        joinedAt: DateTime(2025, 1, 1),
      );
      final member3 = GroupMemberEntity(
        groupId: 'group1',
        userId: 'user2',
        joinedAt: DateTime(2025, 1, 1),
      );

      // Assert
      expect(member1, equals(member2));
      expect(member1, isNot(equals(member3)));
    });
  });
}
