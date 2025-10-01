import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../groups/presentation/providers/group_providers.dart';
import '../providers/expense_providers.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  const CreateExpenseScreen({super.key});

  @override
  ConsumerState<CreateExpenseScreen> createState() =>
      _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen> with LoggerMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedCurrency = 'USD';
  String? _selectedGroupId;
  DateTime? _selectedDate;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final expenseNotifier = ref.read(expenseNotifierProvider.notifier);

    final title = _titleController.text.trim();
    final amount = double.parse(_amountController.text.trim());

    log.i('Creating expense: $title - $amount $_selectedCurrency for group $_selectedGroupId');

    await expenseNotifier.createExpense(
      title: title,
      amount: amount,
      currency: _selectedCurrency,
      groupId: _selectedGroupId,
      expenseDate: _selectedDate,
    );

    if (!mounted) return;

    final state = ref.read(expenseNotifierProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create expense: ${state.error}'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseState = ref.watch(expenseNotifierProvider);
    final isLoading = expenseState.isLoading;
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        leading: IconButton(
          onPressed: isLoading ? null : () => context.go('/home'),
          icon: const Icon(Icons.close),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _saveExpense,
            child: isLoading
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
                  items: groups.map((group) {
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
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
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
