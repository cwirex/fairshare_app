// lib/features/profile/presentation/screens/profile_screen.dart
import 'package:fairshare_app/features/auth/domain/entities/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../shared/routes/routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/sign_out_dialog.dart';

class ProfileScreen extends ConsumerWidget with LoggerMixin {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    if (currentUser == null) {
      return ErrorWidget.withDetails(
        message: 'No user is currently signed in.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          onPressed: () => context.go(Routes.home),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile header
            _buildProfileHeader(currentUser, theme),
            const SizedBox(height: 32),

            // Profile options
            _buildProfileOptions(context, theme),
            const SizedBox(height: 32),

            // App information
            _buildAppInfo(context, theme),
            const SizedBox(height: 32),

            // Sign out section
            _buildSignOutSection(context, ref, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User currentUser, ThemeData theme) {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 50,
          backgroundImage:
              currentUser.avatarUrl.isNotEmpty == true
                  ? NetworkImage(currentUser.avatarUrl)
                  : null,
          child:
              currentUser.avatarUrl.isEmpty != false
                  ? Text(
                    currentUser.initials ?? '?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  : null,
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          currentUser.displayName ?? 'Guest User',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),

        // Email
        Text(
          currentUser.email ?? 'guest@fairshare.app',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        // Sync status indicator
        ...[
          const SizedBox(height: 8),
          _buildSyncStatusChip(currentUser, theme),
        ],
      ],
    );
  }

  Widget _buildSyncStatusChip(User user, ThemeData theme) {
    final bool isSynced = true; // TODO: Replace with actual sync status

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:
            isSynced
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.cloud_done : Icons.cloud_off,
            size: 16,
            color:
                isSynced
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 4),
          Text(
            isSynced ? 'Synced' : 'Not synced',
            style: theme.textTheme.bodySmall?.copyWith(
              color:
                  isSynced
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOptions(BuildContext context, ThemeData theme) {
    return Card(
      child: Column(
        children: [
          _buildListTile(
            context: context,
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Update your name and preferences',
            onTap: () {
              log.i('Edit profile tapped');
              // TODO: Navigate to edit profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile coming soon')),
              );
            },
          ),
          _buildDivider(theme),
          _buildListTile(
            context: context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage notification preferences',
            onTap: () {
              log.i('Notifications tapped');
              // TODO: Navigate to notifications settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications settings coming soon'),
                ),
              );
            },
          ),
          _buildDivider(theme),
          _buildListTile(
            context: context,
            icon: Icons.security_outlined,
            title: 'Privacy & Security',
            subtitle: 'Data and security settings',
            onTap: () {
              log.i('Privacy & Security tapped');
              // TODO: Navigate to privacy settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy settings coming soon')),
              );
            },
          ),
          _buildDivider(theme),
          _buildListTile(
            context: context,
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: () {
              log.i('Help & Support tapped');
              // TODO: Navigate to help
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & support coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo(BuildContext context, ThemeData theme) {
    return Card(
      child: Column(
        children: [
          _buildListTile(
            context: context,
            icon: Icons.info_outline,
            title: 'About FairShare',
            subtitle: 'Version 1.0.0 (Beta)',
          ),
          _buildDivider(theme),
          _buildListTile(
            context: context,
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
          ),
          _buildDivider(theme),
          _buildListTile(
            context: context,
            icon: Icons.article_outlined,
            title: 'Terms of Service',
            subtitle: 'App usage terms and conditions',
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutSection(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // Sync status warning (if needed)
        // TODO: Show this only when there's unsynced data
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_sync,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Sync Status',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Your data is automatically backed up when online',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Sign out button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showSignOutDialog(context),
            icon: Icon(Icons.logout, color: theme.colorScheme.error),
            label: Text(
              'Sign Out',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: theme.colorScheme.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Sign out help text
        Text(
          'Your data will be safely stored in the cloud',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing:
          onTap != null
              ? Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              )
              : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 1,
      color: theme.colorScheme.outline.withOpacity(0.1),
      indent: 16,
      endIndent: 16,
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const SignOutDialog());
  }
}

/// Extension to add initials method to user if not available
extension UserProfileExtension on dynamic {
  String get initials {
    if (this == null) return '?';

    final displayName = this.displayName as String? ?? '';
    final words = displayName.split(' ');

    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();

    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
