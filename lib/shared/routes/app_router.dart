import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/expenses/presentation/screens/create_expense_screen.dart';
import '../../features/groups/presentation/screens/create_group_screen.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/groups/presentation/screens/join_group_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import 'routes.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: Routes.auth,
    redirect: (context, state) {
      // Watch auth state for automatic redirects
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final currentRoute = state.uri.toString();

      // If user is authenticated but on auth page, redirect to home
      if (isAuthenticated && currentRoute == Routes.auth) {
        return Routes.home;
      }

      // If user is not authenticated and not on auth page, redirect to auth
      if (!isAuthenticated && Routes.requiresAuth(currentRoute)) {
        return Routes.auth;
      }

      // No redirect needed
      return null;
    },
    routes: [
      // === AUTHENTICATION ===
      GoRoute(
        path: Routes.auth,
        name: 'Auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // === HOME & MAIN NAVIGATION ===
      GoRoute(
        path: Routes.home,
        name: 'Home',
        builder: (context, state) => const HomeScreen(),
      ),

      // === PROFILE ===
      GoRoute(
        path: Routes.profile,
        name: 'Profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // === EXPENSES ===
      GoRoute(
        path: Routes.createExpense,
        name: 'CreateExpense',
        builder: (context, state) => const CreateExpenseScreen(),
      ),

      // === GROUPS ===
      // Note: Specific routes must come before parameterized routes
      GoRoute(
        path: Routes.createGroup,
        name: 'CreateGroup',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: Routes.joinGroup,
        name: 'JoinGroup',
        builder: (context, state) => const JoinGroupScreen(),
      ),
      GoRoute(
        path: Routes.groupDetail,
        name: 'GroupDetail',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return GroupDetailScreen(groupId: groupId);
        },
      ),

      // === FUTURE ROUTES ===
      // These will be implemented in upcoming phases:

      // GoRoute(
      //   path: Routes.expenseDetail,
      //   name: 'ExpenseDetail',
      //   builder: (context, state) {
      //     final expenseId = state.pathParameters['expenseId']!;
      //     return ExpenseDetailScreen(expenseId: expenseId);
      //   },
      // ),
    ],

    // Error handling with route name logging
    errorBuilder: (context, state) {
      final routeName = Routes.getRouteName(state.uri.toString());

      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Page not found'),
              const SizedBox(height: 8),
              Text('Route: $routeName'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
