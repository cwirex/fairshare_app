import 'package:fairshare_app/features/auth/domain/entities/user.dart';
import 'package:result_dart/result_dart.dart';

/// Abstract interface for remote user operations.
///
/// This service handles all network-based user operations (e.g., Firestore).
/// It abstracts the remote data source implementation from the domain layer,
/// following clean architecture and dependency inversion principles.
///
/// Implementations should handle:
/// - Network operations (upload, download)
/// - Real-time streaming (watch operations)
/// - Error handling and logging
///
/// This interface is used by sync services to coordinate remote + local operations.
abstract class RemoteUserService {
  /// Upload a user to the remote database.
  Future<Result<void>> uploadUser(User user);

  /// Download a specific user by ID from the remote database.
  Future<Result<User>> downloadUser(String userId);

  /// Watch real-time changes to a specific user.
  Stream<User> watchUser(String userId);
}
