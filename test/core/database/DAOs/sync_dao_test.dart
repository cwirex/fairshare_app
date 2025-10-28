import 'package:drift/native.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('SyncDao', () {
    test('enqueueOperation should add operation to queue', () async {
      // Act
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp1',
        operationType: 'create',
        metadata: 'group1',
      );

      // Assert
      final operations =
          await database.syncDao.getPendingOperations(ownerId: 'user1');
      expect(operations.length, 1);
      expect(operations[0].entityType, 'expense');
      expect(operations[0].entityId, 'exp1');
      expect(operations[0].operationType, 'create');
    });

    test('enqueueOperation should update existing operation for same entity',
        () async {
      // Arrange - enqueue create
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp1',
        operationType: 'create',
      );

      // Act - enqueue update for same entity
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp1',
        operationType: 'update',
      );

      // Assert - should have only one operation (updated)
      final operations =
          await database.syncDao.getPendingOperations(ownerId: 'user1');
      expect(operations.length, 1);
      expect(operations[0].operationType, 'update');
    });

    test('getPendingOperations should only return operations for specific user',
        () async {
      // Arrange
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp1',
        operationType: 'create',
      );
      await database.syncDao.enqueueOperation(
        ownerId: 'user2',
        entityType: 'expense',
        entityId: 'exp2',
        operationType: 'create',
      );

      // Act
      final user1Ops =
          await database.syncDao.getPendingOperations(ownerId: 'user1');

      // Assert
      expect(user1Ops.length, 1);
      expect(user1Ops[0].ownerId, 'user1');
    });

    test('getPendingOperations should respect limit', () async {
      // Arrange
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp1',
        operationType: 'create',
      );
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp2',
        operationType: 'create',
      );
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp3',
        operationType: 'create',
      );

      // Act
      final operations =
          await database.syncDao.getPendingOperations(ownerId: 'user1', limit: 2);

      // Assert
      expect(operations.length, 2);
    });

    test('removeQueuedOperation should remove operation from queue', () async {
      // Arrange
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp1',
        operationType: 'create',
      );
      final operations =
          await database.syncDao.getPendingOperations(ownerId: 'user1');
      final operationId = operations[0].id;

      // Act
      await database.syncDao.removeQueuedOperation(operationId);

      // Assert
      final remaining =
          await database.syncDao.getPendingOperations(ownerId: 'user1');
      expect(remaining.length, 0);
    });

    test('markOperationFailed should increment retry count and set error',
        () async {
      // Arrange
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp1',
        operationType: 'create',
      );
      final operations =
          await database.syncDao.getPendingOperations(ownerId: 'user1');
      final operationId = operations[0].id;

      // Act
      await database.syncDao
          .markOperationFailed(operationId, 'Network error');

      // Assert
      final updated =
          await database.syncDao.getPendingOperations(ownerId: 'user1');
      expect(updated[0].retryCount, 1);
      expect(updated[0].lastError, 'Network error');
    });

    test('markOperationFailed should increment retry count multiple times',
        () async {
      // Arrange
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp1',
        operationType: 'create',
      );
      final operations =
          await database.syncDao.getPendingOperations(ownerId: 'user1');
      final operationId = operations[0].id;

      // Act
      await database.syncDao.markOperationFailed(operationId, 'Error 1');
      await database.syncDao.markOperationFailed(operationId, 'Error 2');
      await database.syncDao.markOperationFailed(operationId, 'Error 3');

      // Assert
      final updated =
          await database.syncDao.getPendingOperations(ownerId: 'user1');
      expect(updated[0].retryCount, 3);
      expect(updated[0].lastError, 'Error 3');
    });

    test('getPendingOperationCount should return correct count', () async {
      // Arrange
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp1',
        operationType: 'create',
      );
      await database.syncDao.enqueueOperation(
        ownerId: 'user1',
        entityType: 'expense',
        entityId: 'exp2',
        operationType: 'create',
      );
      await database.syncDao.enqueueOperation(
        ownerId: 'user2',
        entityType: 'expense',
        entityId: 'exp3',
        operationType: 'create',
      );

      // Act
      final count = await database.syncDao.getPendingOperationCount('user1');

      // Assert
      expect(count, 2);
    });

    test('getPendingOperationCount should return 0 for user with no operations',
        () async {
      // Act
      final count = await database.syncDao.getPendingOperationCount('user1');

      // Assert
      expect(count, 0);
    });
  });
}
