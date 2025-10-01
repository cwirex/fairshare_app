import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/core/sync/sync_providers.dart';
import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/groups/presentation/providers/group_providers.dart';
import 'package:fairshare_app/firebase_options.dart';
import 'package:fairshare_app/shared/routes/app_router.dart';
import 'package:fairshare_app/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run the app with Riverpod
  runApp(const ProviderScope(child: FairShareApp()));
}

class FairShareApp extends ConsumerWidget with LoggerMixin {
  const FairShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    log.i('FairShare app starting...');

    _ensurePersonalGroupExists(ref);

    return MaterialApp.router(
      title: 'FairShare',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  void _ensurePersonalGroupExists(WidgetRef ref) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      final groupInitService = ref.read(groupInitializationServiceProvider);
      groupInitService.ensurePersonalGroupExists(currentUser.id);

      // Initialize sync service to start syncing with Firestore
      ref.read(syncServiceProvider);

      // Download user's groups from Firestore when they log in
      final syncService = ref.read(syncServiceProvider);
      syncService.downloadUserGroups(currentUser.id);
    }
  }
}
