import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fairshare_app/core/constants/firestore_collections.dart';
import 'package:fairshare_app/features/auth/domain/entities/user.dart';
import 'package:fairshare_app/features/auth/domain/services/remote_user_service.dart';
import 'package:result_dart/result_dart.dart';

/// Firestore implementation of RemoteUserService.
///
/// Handles all remote user operations using Cloud Firestore.
class FirestoreUserService implements RemoteUserService {
  final FirebaseFirestore _firestore;

  FirestoreUserService(this._firestore);

  /// Upload a user to Firestore.
  Future<Result<void>> uploadUser(User user) async {
    try {
      final userData = user.toJson();

      await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.id)
          .set(userData, SetOptions(merge: true));

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to upload user: $e'));
    }
  }

  /// Download a user from Firestore.
  Future<Result<User>> downloadUser(String userId) async {
    try {
      final doc =
          await _firestore.collection(FirestoreCollections.users).doc(userId).get();

      if (!doc.exists) {
        return Failure(Exception('User not found: $userId'));
      }

      final data = doc.data()!;

      return Success(User.fromJson(data));
    } catch (e) {
      return Failure(Exception('Failed to download user: $e'));
    }
  }

  /// Listen to changes in a user.
  Stream<User> watchUser(String userId) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .snapshots()
        .where((doc) => doc.exists)
        .map((doc) {
      final data = doc.data()!;
      return User.fromJson(data);
    });
  }
}
