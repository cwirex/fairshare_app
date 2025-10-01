import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/shared/routes/routes.dart';
import 'package:fairshare_app/shared/theme/app_theme.dart';
import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/home/presentation/widgets/expenses_tab.dart';
import 'package:fairshare_app/features/home/presentation/widgets/balances_tab.dart';
import 'package:fairshare_app/features/home/presentation/widgets/groups_tab.dart';
import 'package:fairshare_app/features/home/presentation/widgets/profile_tab.dart'
    show ProfileTab, UserExtension;

final currentIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget with LoggerMixin {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentIndexProvider);
    final appTheme = ref.watch(appThemeProvider.notifier);
    final currentUser = ref.watch(currentUserProvider);

    final tabs = [
      const ExpensesTab(),
      const BalancesTab(),
      const GroupsTab(),
      ProfileTab(user: currentUser),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FairShare'),
        actions: [
          IconButton(
            onPressed: () {
              appTheme.toggleTheme();
              log.i('Theme toggled');
            },
            icon: Icon(
              Theme.of(context).brightness == Brightness.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            tooltip: 'Toggle theme',
          ),
          IconButton(
            onPressed: () {
              log.i('Profile button pressed');
              context.go(Routes.profile);
            },
            icon: CircleAvatar(
              radius: 16,
              backgroundImage:
                  currentUser?.avatarUrl.isNotEmpty == true
                      ? NetworkImage(currentUser!.avatarUrl)
                      : null,
              child:
                  currentUser?.avatarUrl.isEmpty != false
                      ? Text(
                        currentUser?.initials ?? '?',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      )
                      : null,
            ),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: IndexedStack(index: currentIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(currentIndexProvider.notifier).state = index;
          log.d('Tab changed to index: $index');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.balance_outlined),
            selectedIcon: Icon(Icons.balance),
            label: 'Balances',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(currentIndex, context),
    );
  }

  Widget? _buildFloatingActionButton(int currentIndex, BuildContext context) {
    switch (currentIndex) {
      case 0: // Expenses tab
        return FloatingActionButton.extended(
          onPressed: () {
            log.i('Add expense button pressed');
            context.go(Routes.createExpense);
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Expense'),
        );
      case 2: // Groups tab
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              onPressed: () {
                log.i('Join group button pressed');
                context.go(Routes.joinGroup);
              },
              icon: const Icon(Icons.group_add),
              label: const Text('Join Group'),
              heroTag: 'join_group',
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              onPressed: () {
                log.i('Create group button pressed');
                context.go(Routes.createGroup);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
              heroTag: 'create_group',
            ),
          ],
        );
      default:
        return null;
    }
  }
}