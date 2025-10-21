import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fairshare_app/core/constants/firestore_collections.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/services/remote_group_service.dart';
import 'package:result_dart/result_dart.dart';

/// Firestore implementation of RemoteGroupService.
///
/// Handles all remote group operations using Cloud Firestore.
class FirestoreGroupService with LoggerMixin implements RemoteGroupService {
  final FirebaseFirestore _firestore;

  FirestoreGroupService(this._firestore);

  /// Upload a group to Firestore with server timestamp.
  /// All groups including personal groups are synced for backup.
  @override
  Future<Result<void>> uploadGroup(GroupEntity group) async {
    try {
      final groupData = group.toJson();
      // Use server timestamp for accurate conflict resolution
      groupData[GroupFields.updatedAt] = FieldValue.serverTimestamp();
      groupData[GroupFields.lastActivityAt] = FieldValue.serverTimestamp();

      await _firestore
          .collection(FirestoreCollections.groups)
          .doc(group.id)
          .set(groupData, SetOptions(merge: true));

      log.d('Uploaded group: ${group.id}');
      return Success.unit();
    } catch (e) {
      log.e('Failed to upload group ${group.id}: $e');
      return Failure(Exception('Failed to upload group: $e'));
    }
  }

  /// Upload a group member to Firestore.
  /// All members including personal group members are synced for backup.
  @override
  Future<Result<void>> uploadGroupMember(
    GroupMemberEntity member, {
    bool isPersonalGroup = false,
  }) async {
    try {
      final memberData = member.toJson();

      await _firestore
          .collection(FirestoreCollections.groups)
          .doc(member.groupId)
          .collection(FirestoreCollections.members)
          .doc(member.userId)
          .set(memberData, SetOptions(merge: true));

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to upload group member: $e'));
    }
  }

  /// Download a group from Firestore.
  @override
  Future<Result<GroupEntity>> downloadGroup(String groupId) async {
    try {
      final doc =
          await _firestore
              .collection(FirestoreCollections.groups)
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
  @override
  Future<Result<List<GroupEntity>>> downloadUserGroups(String userId) async {
    try {
      log.d('Querying groups for user: $userId');

      // Query all groups where user is a member
      final querySnapshot =
          await _firestore
              .collectionGroup(FirestoreCollections.members)
              .where(GroupMemberFields.userId, isEqualTo: userId)
              .get();

      log.d('Found ${querySnapshot.docs.length} member documents');

      final groupIds =
          querySnapshot.docs
              .map((doc) => doc.reference.parent.parent!.id)
              .toSet()
              .toList();

      log.d('Extracted ${groupIds.length} unique group IDs');

      final groups = <GroupEntity>[];
      for (final groupId in groupIds) {
        final result = await downloadGroup(groupId);
        await result.fold(
          (group) async {
            log.d('Downloaded group: ${group.displayName}');
            groups.add(group);
          },
          (error) async {
            log.w('Failed to download group $groupId: $error');
          },
        );
      }

      log.i('Downloaded ${groups.length} groups for user $userId');
      return Success(groups);
    } catch (e) {
      log.e('Failed to query user groups: $e');
      return Failure(Exception('Failed to download user groups: $e'));
    }
  }

  /// Download all members of a group.
  @override
  Future<Result<List<GroupMemberEntity>>> downloadGroupMembers(
    String groupId,
  ) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.groups)
              .doc(groupId)
              .collection(FirestoreCollections.members)
              .get();

      final members =
          querySnapshot.docs
              .map((doc) => GroupMemberEntity.fromJson(doc.data()))
              .toList();

      return Success(members);
    } catch (e) {
      return Failure(Exception('Failed to download group members: $e'));
    }
  }

  /// Delete a group from Firestore.
  @override
  Future<Result<void>> deleteGroup(String groupId) async {
    try {
      // Delete all members first
      final membersSnapshot =
          await _firestore
              .collection(FirestoreCollections.groups)
              .doc(groupId)
              .collection(FirestoreCollections.members)
              .get();

      for (final doc in membersSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the group
      await _firestore
          .collection(FirestoreCollections.groups)
          .doc(groupId)
          .delete();

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to delete group: $e'));
    }
  }

  /// Remove a member from a group in Firestore.
  @override
  Future<Result<void>> removeGroupMember(String groupId, String userId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.groups)
          .doc(groupId)
          .collection(FirestoreCollections.members)
          .doc(userId)
          .delete();

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to remove group member: $e'));
    }
  }

  /// Listen to changes in a group.
  @override
  Stream<GroupEntity> watchGroup(String groupId) {
    return _firestore
        .collection(FirestoreCollections.groups)
        .doc(groupId)
        .snapshots()
        .where((doc) => doc.exists)
        .map((doc) {
          final data = doc.data()!;
          return GroupEntity.fromJson(data);
        });
  }

  /// Listen to changes in user's groups.
  @override
  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    return _firestore
        .collectionGroup(FirestoreCollections.members)
        .where(GroupMemberFields.userId, isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final groupIds =
              snapshot.docs
                  .map((doc) => doc.reference.parent.parent!.id)
                  .toSet()
                  .toList();

          final groups = <GroupEntity>[];
          for (final groupId in groupIds) {
            final doc =
                await _firestore
                    .collection(FirestoreCollections.groups)
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
