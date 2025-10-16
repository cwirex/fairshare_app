/// Firestore collection and subcollection names.
///
/// Centralized constants to prevent typos and ensure consistency
/// across all Firestore operations.
class FirestoreCollections {
  // Private constructor to prevent instantiation
  FirestoreCollections._();

  // Root collections
  static const String groups = 'groups';
  static const String users = 'users';

  // Subcollections
  static const String members = 'members';
  static const String expenses = 'expenses';
  static const String shares = 'shares';
}
