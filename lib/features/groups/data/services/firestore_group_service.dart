import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:result_dart/result_dart.dart';

import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';

/// Firestore service for syncing groups with remote database.
class FirestoreGroupService {
  final FirebaseFirestore _firestore;

  FirestoreGroupService(this._firestore);

  static const String _groupsCollection = 'groups';
  static const String _membersSubcollection = 'members';

  /// Upload a group to Firestore.
  /// All groups including personal groups are synced for backup.
  Future<Result<void>> uploadGroup(GroupEntity group) async {
    try {
      final groupData = group.toJson();

      await _firestore
          .collection(_groupsCollection)
          .doc(group.id)
          .set(groupData, SetOptions(merge: true));

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to upload group: $e'));
    }
  }

  /// Upload a group member to Firestore.
  /// All members including personal group members are synced for backup.
  Future<Result<void>> uploadGroupMember(GroupMemberEntity member, {bool isPersonalGroup = false}) async {
    try {
      final memberData = member.toJson();

      await _firestore
          .collection(_groupsCollection)
          .doc(member.groupId)
          .collection(_membersSubcollection)
          .doc(member.userId)
          .set(memberData, SetOptions(merge: true));

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to upload group member: $e'));
    }
  }

  /// Download a group from Firestore.
  Future<Result<GroupEntity>> downloadGroup(String groupId) async {
    try {
      final doc = await _firestore
          .collection(_groupsCollection)
          .doc(groupId)
          .get();

      if (!doc.exists) {
        return Failure(Exception('Group not found: $groupId'));
      }

      final data = doc.data()!;

      return Success(GroupEntity.fromJson(data));
    } catch (e) {
      return Failure(Exception('Failed to download group: $e'));
    }
  }

  /// Download all groups that the user is a member of.
  Future<Result<List<GroupEntity>>> downloadUserGroups(String userId) async {
    try {
      print('🔍 Firestore: Querying groups for user: $userId');

      // Query all groups where user is a member
      final querySnapshot = await _firestore
          .collectionGroup(_membersSubcollection)
          .where('userId', isEqualTo: userId)
          .get();

      print('🔍 Firestore: Found ${querySnapshot.docs.length} member documents');

      final groupIds = querySnapshot.docs
          .map((doc) {
            final groupId = doc.reference.parent.parent!.id;
            print('   - Member doc path: ${doc.reference.path} → groupId: $groupId');
            return groupId;
          })
          .toSet()
          .toList();

      print('🔍 Firestore: Extracted ${groupIds.length} unique group IDs');

      final groups = <GroupEntity>[];
      for (final groupId in groupIds) {
        print('🔍 Firestore: Downloading group: $groupId');
        final result = await downloadGroup(groupId);
        await result.fold(
          (group) async {
            print('   ✅ Downloaded: ${group.displayName}');
            groups.add(group);
          },
          (error) async {
            print('   ❌ Failed: $error');
          },
        );
      }

      print('🔍 Firestore: Returning ${groups.length} groups total');
      return Success(groups);
    } catch (e) {
      print('🔍 Firestore: Query failed: $e');
      return Failure(Exception('Failed to download user groups: $e'));
    }
  }

  /// Download all members of a group.
  Future<Result<List<GroupMemberEntity>>> downloadGroupMembers(
      String groupId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_groupsCollection)
          .doc(groupId)
          .collection(_membersSubcollection)
          .get();

      final members = querySnapshot.docs
          .map((doc) => GroupMemberEntity.fromJson(doc.data()))
          .toList();

      return Success(members);
    } catch (e) {
      return Failure(Exception('Failed to download group members: $e'));
    }
  }

  /// Delete a group from Firestore.
  Future<Result<void>> deleteGroup(String groupId) async {
    try {
      // Delete all members first
      final membersSnapshot = await _firestore
          .collection(_groupsCollection)
          .doc(groupId)
          .collection(_membersSubcollection)
          .get();

      for (final doc in membersSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the group
      await _firestore.collection(_groupsCollection).doc(groupId).delete();

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to delete group: $e'));
    }
  }

  /// Remove a member from a group in Firestore.
  Future<Result<void>> removeGroupMember(
      String groupId, String userId) async {
    try {
      await _firestore
          .collection(_groupsCollection)
          .doc(groupId)
          .collection(_membersSubcollection)
          .doc(userId)
          .delete();

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to remove group member: $e'));
    }
  }

  /// Listen to changes in a group.
  Stream<GroupEntity> watchGroup(String groupId) {
    return _firestore
        .collection(_groupsCollection)
        .doc(groupId)
        .snapshots()
        .where((doc) => doc.exists)
        .map((doc) {
      final data = doc.data()!;
      return GroupEntity.fromJson(data);
    });
  }

  /// Listen to changes in user's groups.
  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    return _firestore
        .collectionGroup(_membersSubcollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final groupIds = snapshot.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toSet()
          .toList();

      final groups = <GroupEntity>[];
      for (final groupId in groupIds) {
        final doc = await _firestore
            .collection(_groupsCollection)
            .doc(groupId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          groups.add(GroupEntity.fromJson(data));
        }
      }

      return groups;
    });
  }
}
