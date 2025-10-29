import 'package:fairshare_app/core/config/gemini_config.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/firebase_options.dart';
import 'package:fairshare_app/shared/routes/app_router.dart';
import 'package:fairshare_app/shared/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Google Gemini (if API key is configured)
  if (GeminiConfig.enabled) {
    Gemini.init(apiKey: GeminiConfig.apiKey);
  }

  // Run the app with Riverpod
  runApp(const ProviderScope(child: FairShareApp()));
}

class FairShareApp extends ConsumerWidget with LoggerMixin {
  const FairShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log.d('Building FairShareApp widget...');

    final router = ref.watch(appRouterProvider);

    log.i('FairShare app starting...');

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
