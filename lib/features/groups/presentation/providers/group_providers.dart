import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:math';

import 'package:fairshare_app/core/database/database_provider.dart';
import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/groups/data/repositories/local_group_repository.dart';
import 'package:fairshare_app/features/groups/data/services/group_initialization_service.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';

part 'group_providers.g.dart';

@Riverpod(keepAlive: true)
GroupRepository groupRepository(GroupRepositoryRef ref) {
  final database = ref.watch(appDatabaseProvider);
  return LocalGroupRepository(database);
}

@Riverpod(keepAlive: true)
GroupInitializationService groupInitializationService(
  GroupInitializationServiceRef ref,
) {
  final repository = ref.watch(groupRepositoryProvider);
  return GroupInitializationService(repository);
}

@riverpod
Stream<List<GroupEntity>> userGroups(UserGroupsRef ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) {
    return Stream.value([]);
  }
  final repository = ref.watch(groupRepositoryProvider);
  return repository.watchUserGroups(currentUser.id);
}

@riverpod
class GroupNotifier extends _$GroupNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> createGroup({
    required String displayName,
    String? avatarUrl,
    String defaultCurrency = 'USD',
  }) async {
    state = const AsyncLoading();

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      state = AsyncError(
        Exception('User must be logged in to create groups'),
        StackTrace.current,
      );
      return;
    }

    final groupId = _generateGroupId();
    final now = DateTime.now();

    final group = GroupEntity(
      id: groupId,
      displayName: displayName,
      avatarUrl: avatarUrl ?? '',
      defaultCurrency: defaultCurrency,
      createdAt: now,
      updatedAt: now,
    );

    final member = GroupMemberEntity(
      groupId: groupId,
      userId: currentUser.id,
      joinedAt: now,
    );

    final repository = ref.read(groupRepositoryProvider);
    final groupResult = await repository.createGroup(group);

    await groupResult.fold(
      (success) async {
        final memberResult = await repository.addMember(member);
        memberResult.fold(
          (_) => state = const AsyncData(null),
          (error) => state = AsyncError(error, StackTrace.current),
        );
      },
      (error) => state = AsyncError(error, StackTrace.current),
    );
  }

  /// Join an existing group by code
  Future<void> joinGroup(String groupCode) async {
    state = const AsyncLoading();

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      state = AsyncError(
        Exception('User must be logged in to join groups'),
        StackTrace.current,
      );
      return;
    }

    final repository = ref.read(groupRepositoryProvider);

    // Check if group exists
    final groupResult = await repository.getGroupById(groupCode);

    await groupResult.fold(
      (group) async {
        // Add current user as member
        final member = GroupMemberEntity(
          groupId: groupCode,
          userId: currentUser.id,
          joinedAt: DateTime.now(),
        );

        final memberResult = await repository.addMember(member);
        memberResult.fold(
          (_) => state = const AsyncData(null),
          (error) => state = AsyncError(error, StackTrace.current),
        );
      },
      (error) {
        state = AsyncError(
          Exception('Group not found. Please check the code and try again.'),
          StackTrace.current,
        );
      },
    );
  }

  String _generateGroupId() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
}