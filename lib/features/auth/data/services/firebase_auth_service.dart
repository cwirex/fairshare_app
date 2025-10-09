// lib/features/auth/data/services/firebase_auth_service.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:result_dart/result_dart.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'firestore_user_service.dart';

/// Detailed sync status information for risk assessment
class SyncStatusInfo {
  final int unsyncedUsers;
  final int unsyncedGroups;
  final int unsyncedExpenses;
  final int unsyncedGroupMembers;
  final int unsyncedExpenseShares;
  final DateTime? lastSyncTime;

  SyncStatusInfo({
    required this.unsyncedUsers,
    required this.unsyncedGroups,
    required this.unsyncedExpenses,
    required this.unsyncedGroupMembers,
    required this.unsyncedExpenseShares,
    this.lastSyncTime,
  });

  int get totalUnsyncedItems =>
      unsyncedUsers +
      unsyncedGroups +
      unsyncedExpenses +
      unsyncedGroupMembers +
      unsyncedExpenseShares;

  bool get hasUnsyncedData => totalUnsyncedItems > 0;

  List<String> get unsyncedItemDescriptions {
    final descriptions = <String>[];

    if (unsyncedExpenses > 0) {
      descriptions.add(
        '$unsyncedExpenses expense${unsyncedExpenses == 1 ? '' : 's'}',
      );
    }
    if (unsyncedGroups > 0) {
      descriptions.add(
        '$unsyncedGroups group${unsyncedGroups == 1 ? '' : 's'}',
      );
    }
    if (unsyncedUsers > 0) {
      descriptions.add(
        '$unsyncedUsers user profile${unsyncedUsers == 1 ? '' : 's'}',
      );
    }
    if (unsyncedGroupMembers > 0) {
      descriptions.add(
        '$unsyncedGroupMembers group membership${unsyncedGroupMembers == 1 ? '' : 's'}',
      );
    }
    if (unsyncedExpenseShares > 0) {
      descriptions.add(
        '$unsyncedExpenseShares expense share${unsyncedExpenseShares == 1 ? '' : 's'}',
      );
    }

    return descriptions;
  }
}

/// Firebase implementation of AuthRepository with enhanced risk assessment.
class FirebaseAuthService implements AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final AppDatabase _database;
  final FirestoreUserService _userService;
  final Connectivity _connectivity;

  FirebaseAuthService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    required AppDatabase database,
    required FirestoreUserService userService,
    Connectivity? connectivity,
  }) : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(),
       _database = database,
       _userService = userService,
       _connectivity = connectivity ?? Connectivity();

  @override
  Future<Result<User>> signInWithGoogle() async {
    try {
      // Start Google Sign-In flow - let Firebase handle connectivity issues
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return Failure(Exception('Google Sign-In was cancelled'));
      }

      // Get authentication credentials
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final firebase_auth.UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return Failure(Exception('Failed to get user from Firebase'));
      }

      // Create domain user
      final now = DateTime.now();
      final user = User(
        id: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? 'Unknown User',
        email: firebaseUser.email ?? '',
        avatarUrl: firebaseUser.photoURL ?? '',
        createdAt: now,
        updatedAt: now,
      );

      // Store user in local database
      await _database.userDao.insertUser(user);

      // Upload user to Firestore
      await _userService.uploadUser(user);

      // Mark as synced since we just uploaded to Firestore
      final syncedUser = user.copyWith(lastSyncTimestamp: now);
      await _database.userDao.updateUser(syncedUser);

      return Success(syncedUser);
    } on firebase_auth.FirebaseAuthException catch (e) {
      return Failure(Exception('Firebase Auth Error: ${e.message}'));
    } catch (e) {
      return Failure(Exception('Sign-in failed: $e'));
    }
  }

  @override
  Future<Result<SignOutRisk>> checkSignOutRisk() async {
    try {
      // Get detailed sync status - this tells us the real story
      final syncStatus = await _getDetailedSyncStatus();

      // If there's unsynced data, it means user has been working offline
      // or sync has failed - this is risky regardless of current connectivity
      if (syncStatus.hasUnsyncedData) {
        return const Success(SignOutRisk.dataLoss);
      }

      // All data is synced - safe to sign out
      return const Success(SignOutRisk.safe);
    } catch (e) {
      return Failure(Exception('Failed to check sign-out risk: $e'));
    }
  }

  /// Get detailed sync status information for risk assessment
  Future<SyncStatusInfo> _getDetailedSyncStatus() async {
    // TODO: Implement timestamp-based sync status checking
    // For now, return zero counts since we removed isSynced tracking
    final totalUnsynced = 0;

    final unsyncedExpenses = 0;
    final unsyncedGroups = 0;
    final unsyncedUsers = 0;

    return SyncStatusInfo(
      unsyncedUsers: unsyncedUsers,
      unsyncedGroups: unsyncedGroups,
      unsyncedExpenses: unsyncedExpenses,
      unsyncedGroupMembers: 0, // TODO: Implement
      unsyncedExpenseShares: 0, // TODO: Implement
      lastSyncTime: DateTime.now().subtract(
        const Duration(minutes: 15),
      ), // TODO: Get real last sync time
    );
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      // Check one more time for unsynced data
      final syncStatus = await _getDetailedSyncStatus();
      if (syncStatus.hasUnsyncedData) {
        // In production, you might want to attempt a final sync here
        // TODO: Implement final sync attempt
        // await _performFinalSync();
      }

      // Sign out from Firebase Auth
      await _firebaseAuth.signOut();

      // Sign out from Google
      await _googleSignIn.signOut();

      // Clear all local data
      await _database.clearAllData();

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Sign-out failed: $e'));
    }
  }

  /// Attempt to sync all unsynced data before sign-out
  /// TODO: Implement this method when sync functionality is ready
  Future<Result<void>> _performFinalSync() async {
    try {
      // This would coordinate syncing all unsynced items to Firebase
      // 1. Sync unsynced users
      // 2. Sync unsynced groups
      // 3. Sync unsynced expenses
      // 4. Sync unsynced group memberships
      // 5. Sync unsynced expense shares

      // For now, just return success
      return Success.unit();
    } catch (e) {
      return Failure(Exception('Final sync failed: $e'));
    }
  }

  @override
  User? getCurrentUser() {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;

    // Return a basic user structure
    // Note: In a real app, you'd want to fetch from local database asynchronously
    return User(
      id: firebaseUser.uid,
      displayName: firebaseUser.displayName ?? 'Unknown User',
      email: firebaseUser.email ?? '',
      avatarUrl: firebaseUser.photoURL ?? '',
      createdAt: DateTime.now(), // This should come from database
      updatedAt: DateTime.now(), // This should come from database
    );
  }

  @override
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      // Try to get full user data from local database
      final localUser = await _database.userDao.getUserById(firebaseUser.uid);

      if (localUser != null) {
        return localUser;
      }

      // Fallback to Firebase data if not in database
      return User(
        id: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? 'Unknown User',
        email: firebaseUser.email ?? '',
        avatarUrl: firebaseUser.photoURL ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  /// Get detailed sync status for UI display
  /// This can be used by the UI to show specific unsynced item counts
  Future<Result<SyncStatusInfo>> getSyncStatus() async {
    try {
      final syncStatus = await _getDetailedSyncStatus();
      return Success(syncStatus);
    } catch (e) {
      return Failure(Exception('Failed to get sync status: $e'));
    }
  }

  /// Force sync all unsynced data
  /// TODO: Implement this when sync functionality is ready
  Future<Result<void>> forceSyncAll() async {
    try {
      // Perform sync operations
      return await _performFinalSync();
    } catch (e) {
      return Failure(Exception('Sync failed: $e'));
    }
  }
}
