import 'dart:math';

import 'package:fairshare_app/core/sync/sync_providers.dart';
import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/groups/data/services/group_initialization_service.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_providers.g.dart';

// Group repository is now provided by sync_providers.dart

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
      isPersonal: false, // Explicitly mark as shared group (not personal)
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

    groupResult.fold((success) async {
      final memberResult = await repository.addMember(member);
      memberResult.fold(
        (_) => state = const AsyncData(null),
        (error) => state = AsyncError(error, StackTrace.current),
      );
    }, (error) => state = AsyncError(error, StackTrace.current));
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

    // Use the new joinGroupByCode method that handles everything
    final result = await repository.joinGroupByCode(groupCode, currentUser.id);

    result.fold(
      (_) => state = const AsyncData(null),
      (error) => state = AsyncError(error, StackTrace.current),
    );
  }

  String _generateGroupId() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
}
