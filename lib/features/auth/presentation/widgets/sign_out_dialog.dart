// lib/features/auth/presentation/widgets/sign_out_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
// import '../providers/sync_status_providers.dart'; // TODO: Uncomment when sync providers are ready

/// Main entry point for sign-out flow with risk assessment
class SignOutDialog extends ConsumerStatefulWidget {
  const SignOutDialog({super.key});

  @override
  ConsumerState<SignOutDialog> createState() => _SignOutDialogState();
}

class _SignOutDialogState extends ConsumerState<SignOutDialog> with LoggerMixin {
  bool _isCheckingRisk = false;
  SignOutRisk? _riskLevel;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSignOutRisk();
  }

  Future<void> _checkSignOutRisk() async {
    setState(() {
      _isCheckingRisk = true;
      _errorMessage = null;
    });

    final authNotifier = ref.read(authNotifierProvider.notifier);

    log.i('Checking sign-out risk assessment...');

    final result = await authNotifier.checkSignOutRisk();

    if (mounted) {
      result.fold(
        (risk) {
          log.i('Risk assessment complete: $risk');
          setState(() {
            _isCheckingRisk = false;
            _riskLevel = risk;
          });
        },
        (error) {
          log.e('Risk assessment failed', error);
          setState(() {
            _isCheckingRisk = false;
            _errorMessage = error.toString();
          });
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingRisk) {
      return _buildLoadingDialog(context);
    }

    if (_errorMessage != null) {
      return _buildErrorDialog(context);
    }

    switch (_riskLevel) {
      case SignOutRisk.safe:
        return SafeSignOutDialog();
      case SignOutRisk.dataLoss:
        return DataLossWarningDialog();
      case SignOutRisk.offline:
        // Note: We no longer check connectivity, but keeping this case for completeness
        return OfflineWarningDialog();
      case null:
        return _buildErrorDialog(context);
    }
  }

  Widget _buildLoadingDialog(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Checking sync status...',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDialog(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
      title: const Text('Cannot Sign Out'),
      content: Text(
        _errorMessage ?? 'Unable to check sync status. Please try again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _checkSignOutRisk, child: const Text('Retry')),
      ],
    );
  }
}

/// Safe sign-out dialog - all data synced
class SafeSignOutDialog extends ConsumerWidget {
  const SafeSignOutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        Icons.check_circle,
        color: theme.colorScheme.primary,
        size: 32,
      ),
      title: const Text('Sign Out Safely'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'All your data is backed up to the cloud.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You can sign back in anytime to access your expenses and groups.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _performSignOut(context, ref),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
          ),
          child: const Text('Sign Out'),
        ),
      ],
    );
  }
}

/// Pending sync warning dialog - unsynced data exists (but preserved)
class DataLossWarningDialog extends ConsumerWidget {
  const DataLossWarningDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.cloud_sync, color: theme.colorScheme.primary, size: 32),
      title: const Text('Pending Sync Operations'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You have data that hasn\'t synced to the cloud yet.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your data is safely stored on this device',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'When you sign back in, everything will sync automatically. No data will be lost.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Would you like to sync now, or sign out and sync later?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: () {
            // TODO: Implement sync attempt
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sync not implemented yet')),
            );
          },
          child: const Text('Sync Now'),
        ),
        FilledButton(
          onPressed: () => _performSignOut(context, ref),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
          ),
          child: const Text('Sign Out Anyway'),
        ),
      ],
    );
  }
}

/// Offline warning dialog - no internet connection (but signing out is safe)
class OfflineWarningDialog extends ConsumerWidget {
  const OfflineWarningDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.cloud_off, color: theme.colorScheme.primary, size: 32),
      title: const Text('Sign Out Offline'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You\'re currently offline, but signing out is safe.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your data is preserved',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'All your data is safely stored on this device. When you sign back in with an internet connection, everything will sync automatically.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _performSignOut(context, ref),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
          ),
          child: const Text('Sign Out'),
        ),
      ],
    );
  }
}

/// Helper class for sign-out operations with logging
class _SignOutHelper with LoggerMixin {
  /// Perform the actual sign-out with loading state
  Future<void> performSignOut(BuildContext context, WidgetRef ref) async {
    final authNotifier = ref.read(authNotifierProvider.notifier);

    // Close the dialog first
    Navigator.of(context).pop();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SignOutProgressDialog(),
    );

    log.w('Performing sign-out...');

    final result = await authNotifier.signOut();

    // Close loading dialog
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    result.fold(
      (_) {
        log.i('Sign-out completed successfully');
        if (context.mounted) {
          context.go('/auth');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed out successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      (error) {
        log.e('Sign-out failed', error);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign-out failed: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
}

final _signOutHelper = _SignOutHelper();

/// Perform the actual sign-out with loading state
Future<void> _performSignOut(BuildContext context, WidgetRef ref) async {
  await _signOutHelper.performSignOut(context, ref);
}

/// Loading dialog shown during sign-out process
class SignOutProgressDialog extends StatelessWidget {
  const SignOutProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Signing out...',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
