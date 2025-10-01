import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:fairshare_app/core/database/database_provider.dart';
import 'package:fairshare_app/core/sync/sync_service.dart';
import 'package:fairshare_app/core/sync/upload_queue_service.dart';
import 'package:fairshare_app/features/expenses/data/repositories/synced_expense_repository.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fairshare_app/features/groups/data/repositories/synced_group_repository.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';

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
    FirestoreExpenseServiceRef ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreExpenseService(firestore);
}

/// Synced group repository provider
@riverpod
GroupRepository groupRepository(GroupRepositoryRef ref) {
  final database = ref.watch(appDatabaseProvider);
  final firestoreService = ref.watch(firestoreGroupServiceProvider);
  final expenseService = ref.watch(firestoreExpenseServiceProvider);
  return SyncedGroupRepository(database, firestoreService, expenseService);
}

/// Synced expense repository provider
@riverpod
ExpenseRepository expenseRepository(ExpenseRepositoryRef ref) {
  final database = ref.watch(appDatabaseProvider);
  final firestoreService = ref.watch(firestoreExpenseServiceProvider);
  return SyncedExpenseRepository(database, firestoreService);
}

/// Upload queue service provider
@riverpod
UploadQueueService uploadQueueService(UploadQueueServiceRef ref) {
  final database = ref.watch(appDatabaseProvider);
  final expenseService = ref.watch(firestoreExpenseServiceProvider);
  final groupService = ref.watch(firestoreGroupServiceProvider);
  return UploadQueueService(
    database: database,
    expenseService: expenseService,
    groupService: groupService,
  );
}

/// Sync service provider
@riverpod
SyncService syncService(SyncServiceRef ref) {
  final database = ref.watch(appDatabaseProvider);
  final groupService = ref.watch(firestoreGroupServiceProvider);
  final expenseService = ref.watch(firestoreExpenseServiceProvider);
  final uploadQueueService = ref.watch(uploadQueueServiceProvider);

  final service = SyncService(
    database: database,
    groupService: groupService,
    expenseService: expenseService,
    uploadQueueService: uploadQueueService,
  );

  // Start auto-sync when the service is created
  service.startAutoSync();

  // Dispose when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
