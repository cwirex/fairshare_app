import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/logging/app_logger.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.watch(appLoggerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('FairShare'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App logo/icon placeholder
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),

            // App title and subtitle
            Text(
              'Welcome to FairShare',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Split expenses and settle up with friends',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Sign in with Google button
            FilledButton.icon(
              onPressed: () {
                logger.i('Google sign-in button pressed');
                // TODO: Implement Firebase Auth
                // For now, navigate to home
                context.go('/home');
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Continue as guest button
            OutlinedButton.icon(
              onPressed: () {
                logger.i('Guest mode selected');
                // TODO: Implement anonymous auth
                // For now, navigate to home
                context.go('/home');
              },
              icon: const Icon(Icons.person_outline),
              label: const Text('Continue as Guest'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),

            // Terms and privacy text
            Text(
              'By continuing, you agree to our Terms of Service and Privacy Policy',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
