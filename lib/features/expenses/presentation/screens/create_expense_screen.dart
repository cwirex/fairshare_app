import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/logging/app_logger.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  const CreateExpenseScreen({super.key});

  @override
  ConsumerState<CreateExpenseScreen> createState() =>
      _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedCurrency = 'USD';
  String _selectedPayer = 'You';

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logger = ref.watch(appLoggerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        leading: IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.close),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                logger.i(
                  'Expense created: ${_titleController.text} - ${_amountController.text} $_selectedCurrency',
                );
                // TODO: Save expense to database
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Expense created successfully!'),
                  ),
                );
                context.go('/home');
              }
            },
            child: const Text('Save'),
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

            // Paid by field
            DropdownButtonFormField<String>(
              value: _selectedPayer,
              decoration: const InputDecoration(
                labelText: 'Paid by',
                prefixIcon: Icon(Icons.person),
              ),
              items:
                  ['You', 'John Doe', 'Jane Smith'].map((payer) {
                    return DropdownMenuItem(value: payer, child: Text(payer));
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPayer = value ?? 'You';
                });
              },
            ),
            const SizedBox(height: 24),

            // Split options
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Split Options', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Split equally'),
                      value: true,
                      onChanged: (value) {
                        // TODO: Implement split logic
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('Share with everyone in group'),
                      value: true,
                      onChanged: (value) {
                        // TODO: Implement group sharing logic
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Date picker
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(DateTime.now().toString().split(' ')[0]),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  logger.i('Date selected: $date');
                  // TODO: Update date state
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
