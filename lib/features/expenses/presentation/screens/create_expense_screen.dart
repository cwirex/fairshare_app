import 'dart:async';

import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/expenses/domain/constants/expense_categories.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/presentation/providers/expense_use_case_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../groups/presentation/providers/group_providers.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  const CreateExpenseScreen({super.key});

  @override
  ConsumerState<CreateExpenseScreen> createState() =>
      _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen>
    with LoggerMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedCurrency = 'USD';
  String? _selectedGroupId;
  DateTime? _selectedDate;
  String _selectedCategory = 'Other';
  bool _isLoading = false;
  bool _isSuggestingCategory = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final title = _titleController.text.trim();
      if (title.isEmpty) return;

      // Only suggest if category is still at default 'Other'
      // This prevents unnecessary API calls when user has already accepted a suggestion
      if (_selectedCategory != 'Other') {
        return;
      }

      setState(() => _isSuggestingCategory = true);

      try {
        final useCase = ref.read(suggestCategoryUseCaseProvider);
        final result = await useCase.call(title);

        if (!mounted) return;

        result.fold(
          (categoryResult) {
            if (categoryResult.category != null &&
                _selectedCategory == 'Other') {
              setState(() {
                _selectedCategory = categoryResult.category!;
              });
            }
          },
          (error) {
            log.w('Category suggestion failed: $error');
          },
        );
      } finally {
        if (mounted) {
          setState(() => _isSuggestingCategory = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        throw Exception('User must be logged in to create expenses');
      }

      final title = _titleController.text.trim();
      final amount = double.parse(_amountController.text.trim());

      log.i(
        'Creating expense: $title - $amount $_selectedCurrency for group $_selectedGroupId',
      );

      // Build expense entity
      final now = DateTime.now();
      final expense = ExpenseEntity(
        id: const Uuid().v4(),
        groupId:
            _selectedGroupId ?? currentUser.id, // Default to personal group
        title: title,
        amount: amount,
        currency: _selectedCurrency,
        paidBy: currentUser.id,
        shareWithEveryone: true,
        category: _selectedCategory,
        expenseDate: _selectedDate ?? now,
        createdAt: now,
        updatedAt: now,
      );

      // Call use case
      final useCase = ref.read(createExpenseUseCaseProvider);
      final result = await useCase(expense);

      if (!mounted) return;

      // Handle result
      result.fold(
        (createdExpense) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/home');
        },
        (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create expense: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        leading: IconButton(
          onPressed: _isLoading ? null : () => context.go('/home'),
          icon: const Icon(Icons.close),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveExpense,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Title field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'What was this expense for?',
                hintText: 'e.g., Dinner, Gas, Hotel...',
                prefixIcon: Icon(Icons.receipt),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Amount and currency row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items:
                        ['USD', 'EUR', 'GBP', 'PLN'].map((currency) {
                          return DropdownMenuItem(
                            value: currency,
                            child: Text(currency),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCurrency = value ?? 'USD';
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Group selector
            groupsAsync.when(
              data: (groups) {
                // Set default to first group (usually Personal) if not set
                if (_selectedGroupId == null && groups.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _selectedGroupId = groups.first.id;
                    });
                  });
                }

                return DropdownButtonFormField<String>(
                  value: _selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: 'Group',
                    prefixIcon: Icon(Icons.group),
                  ),
                  items:
                      groups.map((group) {
                        return DropdownMenuItem(
                          value: group.id,
                          child: Text(group.displayName),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGroupId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a group';
                    }
                    return null;
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Error loading groups: $error'),
            ),
            const SizedBox(height: 24),

            // Category selector with AI suggestion
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: const Icon(Icons.category),
                suffixIcon: _isSuggestingCategory
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : null,
                helperText: _isSuggestingCategory
                    ? 'Getting AI suggestion...'
                    : _selectedCategory != 'Other'
                        ? 'AI Suggested'
                        : null,
              ),
              items: ExpenseCategories.allCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Text(ExpenseCategories.getEmoji(category)),
                      const SizedBox(width: 8),
                      Text(category),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // Date picker
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(
                  _selectedDate?.toString().split(' ')[0] ??
                      DateTime.now().toString().split(' ')[0],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
