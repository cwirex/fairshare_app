import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fairshare_app/shared/routes/routes.dart';

class ProfileTab extends ConsumerWidget {
  final dynamic user;

  const ProfileTab({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // User avatar
            CircleAvatar(
              radius: 50,
              backgroundImage:
                  user?.avatarUrl?.isNotEmpty == true
                      ? NetworkImage(user!.avatarUrl!)
                      : null,
              child:
                  user?.avatarUrl?.isEmpty != false
                      ? Text(
                        user?.initials ?? '?',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      )
                      : null,
            ),
            const SizedBox(height: 16),

            // User name
            Text(
              user?.displayName ?? 'Guest User',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),

            // User email
            Text(
              user?.email ?? 'guest@fairshare.app',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Profile action button
            FilledButton.icon(
              onPressed: () => context.go(Routes.profile),
              icon: const Icon(Icons.settings),
              label: const Text('Manage Profile'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick stats card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStatRow(
                      icon: Icons.receipt_long,
                      label: 'Total Expenses',
                      value: '0',
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      icon: Icons.group,
                      label: 'Groups Joined',
                      value: '0',
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      icon: Icons.balance,
                      label: 'Active Balances',
                      value: '0',
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

extension UserExtension on dynamic {
  String get initials {
    if (this == null) return '?';

    final displayName = this.displayName as String? ?? '';
    final words = displayName.split(' ');

    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();

    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}