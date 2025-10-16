import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// User entity representing an authenticated user in the FairShare app.
///
/// Uses timestamp-based sync tracking instead of boolean flags.
/// All users authenticate via Google Sign-In.
@freezed
abstract class User with _$User {
  const factory User({
    /// Unique user ID from Firebase Auth
    required String id,

    /// Display name from Google account
    required String displayName,

    /// Email from Google account
    required String email,

    /// Avatar URL from Google account (empty string if not available)
    @Default('') String avatarUrl,

    /// Phone number (optional)
    String? phone,

    /// Last time user synced data with Firestore
    /// Used to determine which groups need syncing
    DateTime? lastSyncTimestamp,

    /// When the user first signed up
    required DateTime createdAt,

    /// Last time user data was updated
    required DateTime updatedAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

/// Extension methods for User entity
extension UserX on User {
  /// Whether user has an avatar image
  bool get hasAvatar => avatarUrl.isNotEmpty;

  /// Whether user has provided phone number
  bool get hasPhone => phone != null && phone!.isNotEmpty;

  /// User initials for avatar fallback
  String get initials {
    final words = displayName.split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// Whether user has ever synced
  bool get hasNeverSynced => lastSyncTimestamp == null;
}

/// Firestore field names for User
abstract class UserFields {
  static const String id = 'id';
  static const String displayName = 'display_name';
  static const String email = 'email';
  static const String avatarUrl = 'avatar_url';
  static const String phone = 'phone';
  static const String lastSyncTimestamp = 'last_sync_timestamp';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}
