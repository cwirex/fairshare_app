// lib/features/auth/presentation/providers/auth_providers.dart
// Stores the UID of the user whose services have been initialized.
import 'package:fairshare_app/core/sync/sync_providers.dart';
import 'package:fairshare_app/features/auth/domain/entities/user.dart';
import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/groups/presentation/providers/group_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_initializer_providers.g.dart';

final initializedUserIdProvider = StateProvider<String?>((_) => null);

@riverpod
void appInitializer(Ref ref) {
  ref.listen<AsyncValue<User?>>(authStateChangesProvider, (previous, next) {
    final user = next.value;
    // Get the UID of the user whose services were last initialized
    final initializedUserId = ref.read(initializedUserIdProvider);

    if (user != null) {
      // User is logged in

      if (user.id != initializedUserId) {
        // Logged-in user is different from the one whose services were initialized,
        // OR services have not been initialized yet (initializedUserId is null).
        print('🚀 User ${user.id} authenticated, initializing services...');

        // 1. Ensure the personal group exists
        final groupInitService = ref.read(groupInitializationServiceProvider);
        groupInitService.ensurePersonalGroupExists(user.id);

        // 2. Initialize the sync service
        ref.read(syncServiceProvider);

        // 3. Mark services as initialized for this specific user
        ref.read(initializedUserIdProvider.notifier).state = user.id;
      } else {
        // User is logged in, and their services are already initialized. Do nothing.
        print('✅ User ${user.id} services already initialized. Skipping.');
      }
    } else {
      // User has logged out or is null
      if (initializedUserId != null) {
        // A user was previously logged in, now they are not. Reset the state.
        print('🔒 User logged out, resetting initialization flag.');
        // This is important to allow initialization for the next login (which could be the same or a different user).
        ref.read(initializedUserIdProvider.notifier).state = null;
      }
    }
  });
}
