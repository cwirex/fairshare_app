import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fairshare_app/core/constants/firestore_collections.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:fairshare_app/features/expenses/domain/services/remote_expense_service.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:result_dart/result_dart.dart';

/// Firestore implementation of RemoteExpenseService.
///
/// Handles all remote expense operations using Cloud Firestore.
/// Expenses are stored as subcollection under groups: groups/{groupId}/expenses/{expenseId}
class FirestoreExpenseService with LoggerMixin implements RemoteExpenseService {
  final FirebaseFirestore _firestore;

  FirestoreExpenseService(this._firestore);

  /// Upload an expense to Firestore under its group with server timestamp.
  /// Personal expenses ARE synced for backup, but personal groups are NOT synced.
  @override
  Future<Result<void>> uploadExpense(ExpenseEntity expense) async {
    try {
      final expenseData = expense.toJson();
      // Use server timestamp for accurate conflict resolution
      expenseData[ExpenseFields.updatedAt] = FieldValue.serverTimestamp();

      await _firestore
          .collection(FirestoreCollections.groups)
          .doc(expense.groupId)
          .collection(FirestoreCollections.expenses)
          .doc(expense.id)
          .set(expenseData, SetOptions(merge: true));

      // Update group's lastActivityAt
      await _firestore
          .collection(FirestoreCollections.groups)
          .doc(expense.groupId)
          .update({GroupFields.lastActivityAt: FieldValue.serverTimestamp()});

      log.d('Uploaded expense: ${expense.id}');
      return Success.unit();
    } catch (e) {
      log.e('Failed to upload expense ${expense.id}: $e');
      return Failure(Exception('Failed to upload expense: $e'));
    }
  }

  /// Upload an expense share to Firestore.
  @override
  Future<Result<void>> uploadExpenseShare(ExpenseShareEntity share) async {
    try {
      final shareData = share.toJson();

      // Find the group for this expense first
      final expenseQuery = await _firestore
          .collectionGroup(FirestoreCollections.expenses)
          .where(ExpenseFields.id, isEqualTo: share.expenseId)
          .limit(1)
          .get();

      if (expenseQuery.docs.isEmpty) {
        return Failure(
          Exception('Expense not found for share: ${share.expenseId}'),
        );
      }

      final expenseDoc = expenseQuery.docs.first;
      final groupId = expenseDoc.reference.parent.parent!.id;

      await _firestore
          .collection(FirestoreCollections.groups)
          .doc(groupId)
          .collection(FirestoreCollections.expenses)
          .doc(share.expenseId)
          .collection(FirestoreCollections.shares)
          .doc(share.userId)
          .set(shareData, SetOptions(merge: true));

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to upload expense share: $e'));
    }
  }

  /// Download an expense from Firestore.
  @override
  Future<Result<ExpenseEntity>> downloadExpense(
    String groupId,
    String expenseId,
  ) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.groups)
          .doc(groupId)
          .collection(FirestoreCollections.expenses)
          .doc(expenseId)
          .get();

      if (!doc.exists) {
        return Failure(Exception('Expense not found: $expenseId'));
      }

      final data = doc.data()!;

      return Success(ExpenseEntity.fromJson(data));
    } catch (e) {
      return Failure(Exception('Failed to download expense: $e'));
    }
  }

  /// Download all expenses for a group.
  @override
  Future<Result<List<ExpenseEntity>>> downloadGroupExpenses(
    String groupId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirestoreCollections.groups)
          .doc(groupId)
          .collection(FirestoreCollections.expenses)
          .get();

      final expenses = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return ExpenseEntity.fromJson(data);
      }).toList();

      return Success(expenses);
    } catch (e) {
      return Failure(Exception('Failed to download group expenses: $e'));
    }
  }

  /// Download all shares for an expense.
  @override
  Future<Result<List<ExpenseShareEntity>>> downloadExpenseShares(
    String groupId,
    String expenseId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirestoreCollections.groups)
          .doc(groupId)
          .collection(FirestoreCollections.expenses)
          .doc(expenseId)
          .collection(FirestoreCollections.shares)
          .get();

      final shares = querySnapshot.docs
          .map((doc) => ExpenseShareEntity.fromJson(doc.data()))
          .toList();

      return Success(shares);
    } catch (e) {
      return Failure(Exception('Failed to download expense shares: $e'));
    }
  }

  /// Delete an expense from Firestore.
  @override
  Future<Result<void>> deleteExpense(String groupId, String expenseId) async {
    try {
      // Delete all shares first
      final sharesSnapshot = await _firestore
          .collection(FirestoreCollections.groups)
          .doc(groupId)
          .collection(FirestoreCollections.expenses)
          .doc(expenseId)
          .collection(FirestoreCollections.shares)
          .get();

      for (final doc in sharesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the expense
      await _firestore
          .collection(FirestoreCollections.groups)
          .doc(groupId)
          .collection(FirestoreCollections.expenses)
          .doc(expenseId)
          .delete();

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to delete expense: $e'));
    }
  }

  /// Listen to changes in a group's expenses.
  @override
  Stream<List<ExpenseEntity>> watchGroupExpenses(String groupId) {
    return _firestore
        .collection(FirestoreCollections.groups)
        .doc(groupId)
        .collection(FirestoreCollections.expenses)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ExpenseEntity.fromJson(data);
          }).toList();
        });
  }

  /// Listen to changes in an expense.
  @override
  Stream<ExpenseEntity> watchExpense(String groupId, String expenseId) {
    return _firestore
        .collection(FirestoreCollections.groups)
        .doc(groupId)
        .collection(FirestoreCollections.expenses)
        .doc(expenseId)
        .snapshots()
        .where((doc) => doc.exists)
        .map((doc) {
          final data = doc.data()!;
          return ExpenseEntity.fromJson(data);
        });
  }

  /// Listen to changes in an expense's shares.
  @override
  Stream<List<ExpenseShareEntity>> watchExpenseShares(
    String groupId,
    String expenseId,
  ) {
    return _firestore
        .collection(FirestoreCollections.groups)
        .doc(groupId)
        .collection(FirestoreCollections.expenses)
        .doc(expenseId)
        .collection(FirestoreCollections.shares)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExpenseShareEntity.fromJson(doc.data()))
              .toList();
        });
  }
}
