import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/core/sync/sync_providers.dart';
import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/groups/data/services/group_initialization_service.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_providers.g.dart';

// Group repository is now provided by sync_providers.dart

/// Provider for GroupInitializationService
@riverpod
GroupInitializationService groupInitializationService(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return GroupInitializationService(repository);
}

/// Provider to watch all groups for the current user.
///
/// This stream updates automatically when groups are created, updated, or deleted.
@Riverpod(keepAlive: true)
Stream<List<GroupEntity>> userGroups(Ref ref) async* {
  final log = AppLogger('UserGroupsProvider');
  final currentUser = ref.watch(currentUserProvider);

  if (currentUser == null) {
    log.w('No current user, yielding empty list');
    yield [];
    return;
  }

  final repository = ref.watch(groupRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);

  log.i('Starting sync for user: ${currentUser.id}');
  // Trigger full bidirectional sync and AWAIT it before watching
  // This ensures Firestore data is downloaded before UI renders
  await syncService.syncAll(currentUser.id);
  log.i('Sync completed, now watching local DB');

  // Watch and yield updates from local database (which now has synced data)
  await for (final groups in repository.watchUserGroups(currentUser.id)) {
    log.i('Local DB emitted ${groups.length} groups');
    yield groups;
  }
}
