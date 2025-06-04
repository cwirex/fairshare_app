import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../shared/theme/app_theme.dart';

// State provider for bottom navigation
final currentIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentIndexProvider);
    final logger = ref.watch(appLoggerProvider);
    final appTheme = ref.watch(appThemeProvider.notifier);

    // List of tab widgets
    final tabs = [
      const ExpensesTab(),
      const BalancesTab(),
      const GroupsTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FairShare'),
        actions: [
          // Theme toggle button
          IconButton(
            onPressed: () {
              appTheme.toggleTheme();
              logger.i('Theme toggled');
            },
            icon: Icon(
              Theme.of(context).brightness == Brightness.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            tooltip: 'Toggle theme',
          ),
          // Profile button
          IconButton(
            onPressed: () {
              logger.i('Profile button pressed');
              context.go('/profile');
            },
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: IndexedStack(index: currentIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(currentIndexProvider.notifier).state = index;
          logger.d('Tab changed to index: $index');
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
      floatingActionButton:
          currentIndex ==
                  0 // Show FAB only on Expenses tab
              ? FloatingActionButton.extended(
                onPressed: () {
                  logger.i('Add expense button pressed');
                  context.go('/expenses/create');
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
              )
              : null,
    );
  }
}

// Tab widgets
class ExpensesTab extends ConsumerWidget {
  const ExpensesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No expenses yet'),
          SizedBox(height: 8),
          Text('Tap the + button to add your first expense'),
        ],
      ),
    );
  }
}

class BalancesTab extends ConsumerWidget {
  const BalancesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.balance, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('All settled up!'),
          SizedBox(height: 8),
          Text('Add some expenses to see balances'),
        ],
      ),
    );
  }
}

class GroupsTab extends ConsumerWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.watch(appLoggerProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No groups yet'),
          const SizedBox(height: 8),
          const Text('Create or join a group to start sharing expenses'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              logger.i('Create group button pressed');
              // TODO: Navigate to create group screen
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              logger.i('Join group button pressed');
              // TODO: Navigate to join group screen
            },
            icon: const Icon(Icons.group_add),
            label: const Text('Join Group'),
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.watch(appLoggerProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 16),
          const Text('Guest User'),
          const SizedBox(height: 8),
          const Text('Sign in to save your data'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              logger.i('Sign in button pressed from profile');
              context.go('/auth');
            },
            icon: const Icon(Icons.login),
            label: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
