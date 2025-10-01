import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/groups/presentation/providers/group_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isSigningIn = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
    });

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final result = await authNotifier.signInWithGoogle();

    if (mounted) {
      setState(() {
        _isSigningIn = false;
      });

      result.fold(
        (user) async {
          final groupInitService =
              ref.read(groupInitializationServiceProvider);
          await groupInitService.ensurePersonalGroupExists(user.id);

          _showSuccessSnackBar('Welcome, ${user.displayName}!');
        },
        (error) {
          _showErrorSnackBar(error.toString());
        },
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listen to auth state changes for automatic navigation
    ref.listen(authNotifierProvider, (previous, next) {
      next.whenData((user) {
        if (user != null && mounted) {
          context.go('/home');
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('FairShare'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App logo/icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),

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
              const SizedBox(height: 16),

              // Feature highlights
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildFeatureItem(
                        icon: Icons.offline_bolt,
                        title: 'Works Offline',
                        subtitle: 'Track expenses without internet',
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(
                        icon: Icons.group,
                        title: 'Share with Friends',
                        subtitle: 'Easy group expense management',
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(
                        icon: Icons.calculate,
                        title: 'Smart Balancing',
                        subtitle: 'Minimal transactions to settle up',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Sign in with Google button
              FilledButton.icon(
                onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                icon:
                    _isSigningIn
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.login),
                label: Text(
                  _isSigningIn ? 'Signing in...' : 'Sign in with Google',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
              const SizedBox(height: 32),

              // Terms and privacy text
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy.\n\nInternet connection required for initial setup.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
