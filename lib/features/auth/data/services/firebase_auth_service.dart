import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:result_dart/result_dart.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Firebase implementation of AuthRepository.
///
/// Handles Google Sign-In, offline persistence, and data safety for sign-out.
class FirebaseAuthService implements AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final AppDatabase _database;
  final Connectivity _connectivity;

  FirebaseAuthService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    required AppDatabase database,
    Connectivity? connectivity,
  }) : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(),
       _database = database,
       _connectivity = connectivity ?? Connectivity();

  @override
  Future<Result<User>> signInWithGoogle() async {
    try {
      // Check internet connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return Failure(Exception('Internet connection required for sign-in'));
      }

      // Start Google Sign-In flow
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
        isSynced: false, // Will sync after storing locally
      );

      // Store user in local database
      await _database.insertUser(user);

      // Mark as synced since we just created it
      final syncedUser = user.copyWith(isSynced: true);
      await _database.updateUser(syncedUser);

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
      // Check internet connectivity first
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return const Success(SignOutRisk.offline);
      }

      // Check for unsynced data
      final unsyncedCount = await _database.getUnsyncedItemsCount();

      if (unsyncedCount > 0) {
        return const Success(SignOutRisk.dataLoss);
      }

      return const Success(SignOutRisk.safe);
    } catch (e) {
      return Failure(Exception('Failed to check sign-out risk: $e'));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      // Double-check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return Failure(Exception('Internet connection required for sign-out'));
      }

      // Sign out from Firebase Auth
      await _firebaseAuth.signOut();

      // Sign out from Google
      await _googleSignIn.signOut();

      // Clear all local data
      await _database.clearAllData();

      return const Success('Signed out and data cleared');
    } catch (e) {
      return Failure(Exception('Sign-out failed: $e'));
    }
  }

  @override
  User? getCurrentUser() {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;

    // Try to get user from local database
    // Note: This should be called within an async context in real usage
    // For now, we'll return a basic user structure
    // The proper implementation would use a FutureOr or require async
    return User(
      id: firebaseUser.uid,
      displayName: firebaseUser.displayName ?? 'Unknown User',
      email: firebaseUser.email ?? '',
      avatarUrl: firebaseUser.photoURL ?? '',
      createdAt: DateTime.now(), // This should come from database
      updatedAt: DateTime.now(), // This should come from database
      isSynced: true, // Assume synced if from Firebase
    );
  }

  @override
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      // Try to get full user data from local database
      final localUser = await _database.getUserById(firebaseUser.uid);

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
        isSynced: true,
      );
    });
  }

  @override
  bool get isAuthenticated => _firebaseAuth.currentUser != null;
}
