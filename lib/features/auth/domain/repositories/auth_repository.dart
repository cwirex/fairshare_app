import 'package:result_dart/result_dart.dart';
import '../entities/user.dart';

/// Enum representing the risk level of signing out
enum SignOutRisk {
  /// All data is synced - safe to sign out with standard warning
  safe,

  /// Unsynced data exists - requires extra confirmation
  dataLoss,

  /// No internet connection - cannot sign out safely
  offline,
}

/// Repository interface for authentication operations.
///
/// Handles Google Sign-In, user state management, and secure sign-out.
/// Supports offline-first approach with Firebase Auth persistence.
abstract class AuthRepository {
  /// Sign in with Google account.
  ///
  /// Requires internet connection for initial OAuth flow.
  /// Returns [User] on success or [Exception] on failure.
  Future<Result<User>> signInWithGoogle();

  /// Check the risk level of signing out based on sync status.
  ///
  /// Returns:
  /// - [SignOutRisk.safe] if all data is synced
  /// - [SignOutRisk.dataLoss] if unsynced data exists
  /// - [SignOutRisk.offline] if no internet connection
  Future<Result<SignOutRisk>> checkSignOutRisk();

  /// Sign out current user and clear all local data.
  ///
  /// Requires internet connection and should only be called after
  /// risk assessment via [checkSignOutRisk].
  ///
  /// WARNING: This permanently deletes all local data!
  Future<Result<void>> signOut();

  /// Get currently authenticated user from local cache.
  ///
  /// Returns null if no user is signed in.
  /// Works offline using Firebase Auth persistence.
  User? getCurrentUser();

  /// Stream of authentication state changes.
  ///
  /// Emits [User] when signed in, null when signed out.
  /// Automatically handles token refresh and validation.
  Stream<User?> authStateChanges();

  /// Whether user is currently authenticated.
  ///
  /// Convenience method that checks if [getCurrentUser] returns non-null.
  bool get isAuthenticated => getCurrentUser() != null;
}
