import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Group repository that syncs with both local database and Firestore.
class SyncedGroupRepository implements GroupRepository {
  final AppDatabase _database;
  final FirestoreGroupService _firestoreService;
  final FirestoreExpenseService _expenseService;
  final Connectivity _connectivity;

  SyncedGroupRepository(
    this._database,
    this._firestoreService,
    this._expenseService, {
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  /// Check if device is online
  Future<bool> _isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  Future<Result<GroupEntity>> createGroup(GroupEntity group) async {
    try {
      // Save to local database first (offline-first)
      await _database.insertGroup(group);

      // Try to sync to Firestore in the background
      _firestoreService.uploadGroup(group);

      return Success(group);
    } catch (e) {
      return Failure(Exception('Failed to create group: $e'));
    }
  }

  @override
  Future<Result<GroupEntity>> getGroupById(String id) async {
    try {
      // First check local database
      final group = await _database.getGroupById(id);
      if (group != null) {
        return Success(group);
      }

      // If not found locally and device is online, try Firestore
      final isOnline = await _isOnline();
      if (isOnline) {
        final firestoreResult = await _firestoreService.downloadGroup(id);
        return await firestoreResult.fold(
          (remoteGroup) async {
            // Save to local database for offline access
            await _database.insertGroup(remoteGroup);

            // Download and save members too
            final membersResult =
                await _firestoreService.downloadGroupMembers(id);
            await membersResult.fold(
              (members) async {
                for (final member in members) {
                  await _database.addGroupMember(member);
                }
              },
              (_) async {},
            );

            return Success(remoteGroup);
          },
          (error) => Failure(error),
        );
      }

      return Failure(Exception('Group not found: $id'));
    } catch (e) {
      return Failure(Exception('Failed to get group: $e'));
    }
  }

  @override
  Future<Result<List<GroupEntity>>> getAllGroups() async {
    try {
      final groups = await _database.getAllGroups();
      return Success(groups);
    } catch (e) {
      return Failure(Exception('Failed to get all groups: $e'));
    }
  }

  @override
  Future<Result<GroupEntity>> updateGroup(GroupEntity group) async {
    try {
      // Update local database first
      await _database.updateGroup(group);

      // Try to sync to Firestore in the background
      _firestoreService.uploadGroup(group);

      return Success(group);
    } catch (e) {
      return Failure(Exception('Failed to update group: $e'));
    }
  }

  @override
  Future<Result<void>> deleteGroup(String id) async {
    try {
      // Delete from local database first
      await _database.deleteGroup(id);

      // Try to delete from Firestore in the background
      _firestoreService.deleteGroup(id);

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to delete group: $e'));
    }
  }

  @override
  Future<Result<void>> addMember(GroupMemberEntity member) async {
    try {
      // Add to local database first
      await _database.addGroupMember(member);

      // Try to sync to Firestore in the background
      _firestoreService.uploadGroupMember(member);

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to add member: $e'));
    }
  }

  @override
  Future<Result<void>> removeMember(String groupId, String userId) async {
    try {
      // Remove from local database first
      await _database.removeGroupMember(groupId, userId);

      // Try to remove from Firestore in the background
      _firestoreService.removeGroupMember(groupId, userId);

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to remove member: $e'));
    }
  }

  @override
  Future<Result<List<String>>> getGroupMembers(String groupId) async {
    try {
      final members = await _database.getGroupMembers(groupId);
      return Success(members);
    } catch (e) {
      return Failure(Exception('Failed to get group members: $e'));
    }
  }

  @override
  Future<Result<List<GroupEntity>>> getUserGroups(String userId) async {
    try {
      final groups = await _database.getUserGroups(userId);
      return Success(groups);
    } catch (e) {
      return Failure(Exception('Failed to get user groups: $e'));
    }
  }

  @override
  Stream<List<GroupEntity>> watchAllGroups() {
    return _database.watchAllGroups();
  }

  @override
  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    return _database.watchUserGroups(userId);
  }

  @override
  Future<Result<GroupEntity>> joinGroupByCode(
      String groupCode, String userId) async {
    try {
      // Check if online first
      final isOnline = await _isOnline();
      if (!isOnline) {
        return Failure(Exception(
            'Internet connection required to join a group. Please check your connection and try again.'));
      }

      // Try to download the group from Firestore
      final firestoreResult = await _firestoreService.downloadGroup(groupCode);

      return await firestoreResult.fold(
        (group) async {
          // Group exists in Firestore, save it locally
          await _database.insertGroup(group);

          // Download existing members
          final membersResult =
              await _firestoreService.downloadGroupMembers(groupCode);
          await membersResult.fold(
            (members) async {
              for (final member in members) {
                await _database.addGroupMember(member);
              }
            },
            (_) async {},
          );

          // Add the current user as a member
          final newMember = GroupMemberEntity(
            groupId: groupCode,
            userId: userId,
            joinedAt: DateTime.now(),
          );

          await _database.addGroupMember(newMember);
          await _firestoreService.uploadGroupMember(newMember);

          // Download expenses for this group
          final expensesResult =
              await _expenseService.downloadGroupExpenses(groupCode);
          await expensesResult.fold(
            (expenses) async {
              for (final expense in expenses) {
                await _database.insertExpense(expense);
              }
            },
            (_) async {},
          );

          return Success(group);
        },
        (error) => Failure(
            Exception('Group not found. Please check the code and try again.')),
      );
    } catch (e) {
      return Failure(Exception('Failed to join group: $e'));
    }
  }
}
