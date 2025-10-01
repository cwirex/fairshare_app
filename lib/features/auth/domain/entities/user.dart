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

    /// Phone number (empty string if not provided)
    @Default('') String phone,

    /// List of group IDs the user is a member of
    @Default([]) List<String> groupIds,

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
  bool get hasPhone => phone.isNotEmpty;

  /// User initials for avatar fallback
  String get initials {
    final words = displayName.split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// Whether user has ever synced
  bool get hasNeverSynced => lastSyncTimestamp == null;

  /// Whether user is a member of a specific group
  bool isMemberOf(String groupId) => groupIds.contains(groupId);
}
