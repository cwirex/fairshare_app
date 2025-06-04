import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/logging/app_logger.dart';
import 'firebase_options.dart';
import 'shared/routes/app_router.dart';
import 'shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run the app with Riverpod
  runApp(const ProviderScope(child: FairShareApp()));
}

class FairShareApp extends ConsumerWidget {
  const FairShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final logger = ref.watch(appLoggerProvider);

    // Log app startup
    logger.i('🚀 FairShare app starting...');

    return MaterialApp.router(
      title: 'FairShare',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
