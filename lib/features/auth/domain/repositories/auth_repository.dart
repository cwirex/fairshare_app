import 'package:result_dart/result_dart.dart';
import '../entities/user.dart';

/// Enum representing the risk level of signing out
///
/// With the multi-user offline-first architecture, signing out is much safer
/// because data is preserved locally per user. Pending operations will sync
/// automatically when the user signs back in.
enum SignOutRisk {
  /// No pending operations - safe to sign out
  safe,

  /// Pending operations exist - informational only
  /// Data is preserved and will sync on next login
  dataLoss,

  /// No internet connection (deprecated - may be removed)
  /// Signing out offline is now safe due to data preservation
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

  /// Check the risk level of signing out based on pending sync operations.
  ///
  /// With the multi-user offline-first architecture:
  /// - Data is preserved locally per user between sessions
  /// - Pending operations will sync automatically on next login
  /// - Signing out is now much safer even with pending operations
  ///
  /// Returns:
  /// - [SignOutRisk.safe] if no pending sync operations exist
  /// - [SignOutRisk.dataLoss] if pending operations exist (informational - data is preserved)
  /// - [SignOutRisk.offline] if no internet connection (deprecated, may be removed)
  Future<Result<SignOutRisk>> checkSignOutRisk();

  /// Sign out current user while preserving local data.
  ///
  /// With the multi-user offline-first architecture:
  /// - Local data is preserved and scoped by user ID
  /// - Pending sync operations remain in queue for next login
  /// - Riverpod automatically invalidates user-scoped providers
  /// - No risk of cross-user data leakage
  ///
  /// Should be called after risk assessment via [checkSignOutRisk].
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
