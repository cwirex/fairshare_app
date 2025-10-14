import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../shared/routes/routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../domain/entities/group_entity.dart';
import '../providers/group_providers.dart';
import '../providers/group_statistics_providers.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({required this.groupId, super.key});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with LoggerMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showGroupCodeDialog(
    BuildContext context,
    GroupEntity group,
    ThemeData theme,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.qr_code, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                const Text('Group Code'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Share this code with others to invite them:',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    group.id,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: theme.colorScheme.onPrimaryContainer,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  group.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: group.id));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Group code copied to clipboard'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Code'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(userGroupsProvider);

    return groupsAsync.when(
      data: (groups) {
        final group = groups.firstWhere(
          (g) => g.id == widget.groupId,
          orElse: () => throw Exception('Group not found'),
        );

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go(Routes.home),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.displayName),
                Text(
                  group.defaultCurrency,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share group code',
                onPressed: () => _showGroupCodeDialog(context, group, theme),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  log.i('Group settings tapped');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group settings coming soon')),
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.receipt_long), text: 'Expenses'),
                Tab(icon: Icon(Icons.people), text: 'Members'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _GroupExpensesTab(group: group),
              _GroupMembersTab(group: group),
            ],
          ),
          floatingActionButton:
              _tabController.index == 0
                  ? FloatingActionButton.extended(
                    onPressed: () {
                      log.i('Add expense to group ${group.displayName}');
                      context.go(Routes.createExpense);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense'),
                  )
                  : null,
        );
      },
      loading:
          () => Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(Routes.home),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, stack) => Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(Routes.home),
              ),
              title: const Text('Error'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text('Failed to load group: $error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go(Routes.home),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

// Tab 1: Group Expenses
class _GroupExpensesTab extends ConsumerWidget with LoggerMixin {
  final GroupEntity group;

  const _GroupExpensesTab({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesByGroupProvider(group.id));
    // Use event-driven statistics provider for reactive updates
    final statisticsAsync = ref.watch(groupStatisticsStreamProvider(group.id));

    return expensesAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return _buildEmptyState(context, theme);
        }

        return Column(
          children: [
            // Summary card with event-driven statistics
            statisticsAsync.when(
              data: (stats) => Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Expenses',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${group.defaultCurrency} ${stats.totalAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.expenseCount} expense${stats.expenseCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Expenses list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        child: Icon(
                          Icons.receipt,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      title: Text(
                        expense.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _formatDate(expense.expenseDate),
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: Text(
                        '${expense.currency} ${expense.amount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onTap: () {
                        log.d('Expense tapped: ${expense.id}');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Expense details for ${expense.title}',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text('Failed to load expenses: $error'),
              ],
            ),
          ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No expenses yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first expense to this group',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Tab 2: Group Members
class _GroupMembersTab extends ConsumerWidget with LoggerMixin {
  final GroupEntity group;

  const _GroupMembersTab({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    // For now, we'll show the current user as the only member
    // In the future, this will fetch actual members from the repository
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Add member button
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person_add,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              'Add Members',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            subtitle: const Text('Invite people to this group'),
            trailing: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.primary,
            ),
            onTap: () {
              log.i('Add members tapped');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add members coming soon')),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Members section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            'MEMBERS',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),

        // Current user (owner)
        if (currentUser != null)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    currentUser.avatarUrl.isNotEmpty
                        ? NetworkImage(currentUser.avatarUrl)
                        : null,
                child:
                    currentUser.avatarUrl.isEmpty
                        ? Text(
                          _getInitials(currentUser.displayName),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : null,
              ),
              title: Row(
                children: [
                  Text(
                    currentUser.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'YOU',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                currentUser.email,
                style: theme.textTheme.bodySmall,
              ),
              trailing: Icon(
                Icons.admin_panel_settings,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add more members to split expenses and track balances together.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final words = name.split(' ');
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
