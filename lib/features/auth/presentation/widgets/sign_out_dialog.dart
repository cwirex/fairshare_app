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

/// Data loss warning dialog - unsynced data exists
class DataLossWarningDialog extends ConsumerStatefulWidget {
  const DataLossWarningDialog({super.key});

  @override
  ConsumerState<DataLossWarningDialog> createState() =>
      _DataLossWarningDialogState();
}

class _DataLossWarningDialogState extends ConsumerState<DataLossWarningDialog> {
  bool _showTypeConfirmation = false;
  final _confirmationController = TextEditingController();
  bool _isTypedCorrectly = false;

  @override
  void initState() {
    super.initState();
    _confirmationController.addListener(_onConfirmationTextChanged);
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  void _onConfirmationTextChanged() {
    setState(() {
      _isTypedCorrectly =
          _confirmationController.text.trim().toUpperCase() == 'DELETE';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_showTypeConfirmation) {
      return _buildWarningScreen(theme);
    }

    return _buildTypeConfirmationScreen(theme);
  }

  Widget _buildWarningScreen(ThemeData theme) {
    return AlertDialog(
      icon: Icon(Icons.warning, color: theme.colorScheme.error, size: 32),
      title: Text(
        'WARNING: Data Loss Risk',
        style: TextStyle(color: theme.colorScheme.error),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You have unsynced expenses that will be PERMANENTLY LOST.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt,
                      size: 16,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Unsynced data will be lost',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // TODO: Show actual unsynced item counts when sync providers are integrated
                // const SizedBox(height: 8),
                // ...ref.watch(unsyncedItemDescriptionsProvider).when(
                //   data: (descriptions) => descriptions.map((desc) =>
                //     Padding(
                //       padding: const EdgeInsets.only(bottom: 4),
                //       child: Row(
                //         children: [
                //           Icon(Icons.warning, size: 12, color: theme.colorScheme.onErrorContainer),
                //           const SizedBox(width: 8),
                //           Text(desc, style: theme.textTheme.bodySmall?.copyWith(
                //             color: theme.colorScheme.onErrorContainer,
                //           )),
                //         ],
                //       ),
                //     ),
                //   ).toList(),
                //   loading: () => [const SizedBox()],
                //   error: (_, __) => [const SizedBox()],
                // ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This action cannot be undone.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.error,
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
          child: const Text('Try Sync First'),
        ),
        FilledButton(
          onPressed: () {
            setState(() {
              _showTypeConfirmation = true;
            });
          },
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: const Text('Continue Anyway'),
        ),
      ],
    );
  }

  Widget _buildTypeConfirmationScreen(ThemeData theme) {
    return AlertDialog(
      icon: Icon(Icons.dangerous, color: theme.colorScheme.error, size: 32),
      title: Text(
        'Final Confirmation',
        style: TextStyle(color: theme.colorScheme.error),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This will permanently delete all local data.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text('Type DELETE to confirm:', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmationController,
            decoration: InputDecoration(
              hintText: 'DELETE',
              border: OutlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.error),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 2,
                ),
              ),
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _isTypedCorrectly ? () => _performSignOut(context, ref) : null,
          style: FilledButton.styleFrom(
            backgroundColor:
                _isTypedCorrectly
                    ? theme.colorScheme.error
                    : theme.colorScheme.surfaceContainerHighest,
          ),
          child: const Text('Delete & Sign Out'),
        ),
      ],
    );
  }
}

/// Offline warning dialog - no internet connection
class OfflineWarningDialog extends ConsumerWidget {
  const OfflineWarningDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.wifi_off, color: theme.colorScheme.outline, size: 32),
      title: const Text('No Internet Connection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Internet connection is required to sign out safely.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This ensures your data is properly synced before signing out.',
                    style: theme.textTheme.bodySmall,
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
          onPressed: () {
            Navigator.of(context).pop();
            // TODO: Navigate to connectivity/sync screen
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Check your internet connection and try again',
                ),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const SignOutDialog(),
                    );
                  },
                ),
              ),
            );
          },
          child: const Text('Check Connection'),
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
            'Signing out and clearing data...',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
