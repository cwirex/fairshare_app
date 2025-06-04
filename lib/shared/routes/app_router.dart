import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/expenses/presentation/screens/create_expense_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/auth',
    routes: [
      // Auth route
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),

      // Home route with bottom navigation
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),

      // Profile route
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // Create expense route
      GoRoute(
        path: '/expenses/create',
        builder: (context, state) => const CreateExpenseScreen(),
      ),

      // Future routes can be added here:
      // - /groups/create
      // - /groups/:groupId
      // - /expenses/:expenseId
      // - /settings
      // etc.
    ],

    // Error handling
    errorBuilder:
        (context, state) => const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Page not found'),
                SizedBox(height: 8),
                Text('The requested page could not be found.'),
              ],
            ),
          ),
        ),
  );
}
