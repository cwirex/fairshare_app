import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fairshare_app/core/database/database_provider.dart';
import 'package:fairshare_app/core/events/event_providers.dart';
import 'package:fairshare_app/core/sync/realtime_sync_service.dart';
import 'package:fairshare_app/core/sync/sync_service.dart';
import 'package:fairshare_app/core/sync/sync_service_interfaces.dart';
import 'package:fairshare_app/core/sync/upload_queue_service.dart';
import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/expenses/data/repositories/synced_expense_repository.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/services/remote_expense_service.dart';
import 'package:fairshare_app/features/groups/data/repositories/synced_group_repository.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/services/remote_group_service.dart';
import 'package:fairshare_app/features/groups/presentation/providers/group_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_providers.g.dart';

/// Firestore instance provider
@riverpod
FirebaseFirestore firestore(Ref ref) {
  return FirebaseFirestore.instance;
}

/// Remote group service provider (abstraction)
@riverpod
RemoteGroupService remoteGroupService(Ref ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreGroupService(firestore);
}

/// Firestore group service provider (concrete implementation)
/// Note: This is kept for backward compatibility with existing services
@Deprecated('Use remoteGroupServiceProvider instead')
@riverpod
FirestoreGroupService firestoreGroupService(Ref ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreGroupService(firestore);
}

/// Firestore expense service provider
@riverpod
RemoteExpenseService firestoreExpenseService(Ref ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreExpenseService(firestore);
}

/// Synced group repository provider (clean architecture - DB + Queue only)
/// User-scoped: Automatically recreated when user changes
@riverpod
GroupRepository groupRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final eventBroker = ref.watch(eventBrokerProvider);
  final currentUser = ref.watch(currentUserProvider);

  final userId = currentUser?.id;
  if (userId == null) {
    throw Exception(
      'GroupRepository requires an authenticated user. Please sign in.',
    );
  }

  return SyncedGroupRepository(
    database: database,
    groupsDao: database.groupsDao,
    syncDao: database.syncDao,
    eventBroker: eventBroker,
    ownerId: userId,
  );
}

/// Synced expense repository provider (clean architecture - DB + Queue only)
/// User-scoped: Automatically recreated when user changes
@riverpod
ExpenseRepository expenseRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final eventBroker = ref.watch(eventBrokerProvider);
  final currentUser = ref.watch(currentUserProvider);

  final userId = currentUser?.id;
  if (userId == null) {
    throw Exception(
      'ExpenseRepository requires an authenticated user. Please sign in.',
    );
  }

  return SyncedExpenseRepository(
    database: database,
    expensesDao: database.expensesDao,
    expenseSharesDao: database.expenseSharesDao,
    syncDao: database.syncDao,
    eventBroker: eventBroker,
    ownerId: userId,
  );
}

/// Upload queue service provider
/// User-scoped: Automatically recreated when user changes
@riverpod
IUploadQueueService uploadQueueService(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final expenseService = ref.watch(firestoreExpenseServiceProvider);
  final groupService = ref.watch(firestoreGroupServiceProvider);
  final firestore = ref.watch(firestoreProvider);
  final currentUser = ref.watch(currentUserProvider);

  final userId = currentUser?.id;
  if (userId == null) {
    throw Exception(
      'UploadQueueService requires an authenticated user. Please sign in.',
    );
  }

  return UploadQueueService(
    database: database,
    expenseService: expenseService,
    groupService: groupService,
    firestore: firestore,
    ownerId: userId,
  );
}

/// Realtime sync service provider
/// User-scoped: Automatically recreated when user changes
@riverpod
IRealtimeSyncService realtimeSyncService(Ref ref) {
  final currentUser = ref.watch(currentUserProvider);

  if (currentUser == null) {
    throw Exception(
      'RealtimeSyncService requires an authenticated user. Please sign in.',
    );
  }

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
/// User-scoped: Automatically recreated when user changes
@riverpod
ISyncService syncService(Ref ref) {
  final currentUser = ref.watch(currentUserProvider);

  if (currentUser == null) {
    throw Exception(
      'SyncService requires an authenticated user. Please sign in.',
    );
  }

  final database = ref.watch(appDatabaseProvider);
  final uploadQueueService = ref.watch(uploadQueueServiceProvider);
  final realtimeSyncService = ref.watch(realtimeSyncServiceProvider);
  final groupInitService = ref.watch(groupInitializationServiceProvider);
  final eventBroker = ref.watch(eventBrokerProvider);

  final service = SyncService(
    database: database,
    uploadQueueService: uploadQueueService,
    realtimeSyncService: realtimeSyncService,
    groupInitializationService: groupInitService,
    eventBroker: eventBroker,
  );

  // Start auto-sync when the service is created
  service.startAutoSync(currentUser.id);

  // Dispose when the provider is disposed (on logout or user change)
  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
