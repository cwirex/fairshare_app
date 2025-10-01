import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/groups/presentation/providers/group_providers.dart';
import 'package:fairshare_app/shared/routes/routes.dart';

class GroupsTab extends ConsumerWidget with LoggerMixin {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(userGroupsProvider);

    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return _buildEmptyState(context, theme);
        }
        return _buildGroupList(context, theme, groups);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading groups: $error'),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group,
                size: 64,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No groups yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or join a group to start sharing expenses with friends',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      log.i('Create group button pressed');
                      context.go(Routes.createGroup);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Group'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      log.i('Join group button pressed');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Join group coming soon')),
                      );
                    },
                    icon: const Icon(Icons.group_add),
                    label: const Text('Join Group'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupList(
    BuildContext context,
    ThemeData theme,
    List<dynamic> groups,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(
                Icons.group,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(
              group.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Tap to view details',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              log.i('Group tapped: ${group.displayName}');
              context.go(Routes.groupDetailPath(group.id));
            },
          ),
        );
      },
    );
  }
}