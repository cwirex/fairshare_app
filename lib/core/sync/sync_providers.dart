import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fairshare_app/core/database/database_provider.dart';
import 'package:fairshare_app/core/events/event_providers.dart';
import 'package:fairshare_app/core/sync/realtime_sync_service.dart';
import 'package:fairshare_app/core/sync/sync_service.dart';
import 'package:fairshare_app/core/sync/upload_queue_service.dart';
import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/expenses/data/repositories/synced_expense_repository.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fairshare_app/features/groups/data/repositories/synced_group_repository.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_providers.g.dart';

/// Firestore instance provider
@riverpod
FirebaseFirestore firestore(FirestoreRef ref) {
  return FirebaseFirestore.instance;
}

/// Firestore group service provider
@riverpod
FirestoreGroupService firestoreGroupService(FirestoreGroupServiceRef ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreGroupService(firestore);
}

/// Firestore expense service provider
@riverpod
FirestoreExpenseService firestoreExpenseService(
  FirestoreExpenseServiceRef ref,
) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreExpenseService(firestore);
}

/// Synced group repository provider (clean architecture - DB + Queue only)
@riverpod
GroupRepository groupRepository(GroupRepositoryRef ref) {
  final database = ref.watch(appDatabaseProvider);
  final eventBroker = ref.watch(eventBrokerProvider);
  return SyncedGroupRepository(database, eventBroker);
}

/// Synced expense repository provider (clean architecture - DB + Queue only)
@riverpod
ExpenseRepository expenseRepository(ExpenseRepositoryRef ref) {
  final database = ref.watch(appDatabaseProvider);
  final eventBroker = ref.watch(eventBrokerProvider);
  return SyncedExpenseRepository(database, eventBroker);
}

/// Upload queue service provider
@riverpod
UploadQueueService uploadQueueService(UploadQueueServiceRef ref) {
  final database = ref.watch(appDatabaseProvider);
  final expenseService = ref.watch(firestoreExpenseServiceProvider);
  final groupService = ref.watch(firestoreGroupServiceProvider);
  final firestore = ref.watch(firestoreProvider);

  return UploadQueueService(
    database: database,
    expenseService: expenseService,
    groupService: groupService,
    firestore: firestore,
  );
}

/// Realtime sync service provider
@riverpod
RealtimeSyncService realtimeSyncService(RealtimeSyncServiceRef ref) {
  final database = ref.watch(appDatabaseProvider);
  final groupService = ref.watch(firestoreGroupServiceProvider);
  final expenseService = ref.watch(firestoreExpenseServiceProvider);
  final eventBroker = ref.watch(eventBrokerProvider);

  return RealtimeSyncService(
    database: database,
    groupService: groupService,
    expenseService: expenseService,
    eventBroker: eventBroker,
  );
}

/// Sync service provider (orchestrator)
@riverpod
SyncService syncService(SyncServiceRef ref) {
  final database = ref.watch(appDatabaseProvider);
  final uploadQueueService = ref.watch(uploadQueueServiceProvider);
  final realtimeSyncService = ref.watch(realtimeSyncServiceProvider);
  final currentUser = ref.watch(currentUserProvider);

  final service = SyncService(
    database: database,
    uploadQueueService: uploadQueueService,
    realtimeSyncService: realtimeSyncService,
  );

  // Start auto-sync when the service is created, passing userId
  service.startAutoSync(currentUser?.id);

  // Dispose when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
