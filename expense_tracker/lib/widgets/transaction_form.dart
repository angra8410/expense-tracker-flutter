import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';

class TransactionForm extends StatefulWidget {
  final Transaction? transaction; // null for new transaction, non-null for editing
  final Function(Transaction) onSubmit;

  const TransactionForm({
    super.key,
    this.transaction,
    required this.onSubmit,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  late DateTime _selectedDate;
  late TransactionType _selectedType;

  // Expense description options
  final List<String> expenseDescriptions = [
    'Metro',
    'Mercado',
    'Arriendo',
    'Tc y Prestamos',
    'Restaurante',
    'Cine',
    'Helados',
    'Lobitos',
    'Streaming, Wom y Tigo',	
    'Other'
  ];
  String? _selectedExpenseDescription;
  final _otherExpenseDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with existing transaction data if editing
    if (widget.transaction != null) {
      _descriptionController.text = widget.transaction!.description;
      _amountController.text = widget.transaction!.amount.toString();
      _selectedDate = widget.transaction!.date;
      _selectedType = widget.transaction!.type;
      if (_selectedType == TransactionType.expense && expenseDescriptions.contains(widget.transaction!.description)) {
        _selectedExpenseDescription = widget.transaction!.description;
      } else if (_selectedType == TransactionType.expense) {
        _selectedExpenseDescription = 'Other';
        _otherExpenseDescriptionController.text = widget.transaction!.description;
      }
    } else {
      _selectedDate = DateTime.now();
      _selectedType = TransactionType.expense;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _otherExpenseDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      String description;
      if (_selectedType == TransactionType.expense) {
        if (_selectedExpenseDescription == 'Other') {
          description = _otherExpenseDescriptionController.text;
        } else {
          description = _selectedExpenseDescription ?? '';
        }
      } else {
        description = _descriptionController.text;
      }

      final transaction = Transaction(
        id: widget.transaction?.id ?? DateTime.now().toString(),
        amount: double.parse(_amountController.text),
        description: description,
        date: _selectedDate,
        type: _selectedType,
        categoryId: 'default', // TODO: Implement categories
        accountId: 'default', // TODO: Implement accounts
      );

      widget.onSubmit(transaction);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpense = _selectedType == TransactionType.expense;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Type selector
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.remove_circle_outline),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.add_circle_outline),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<TransactionType> selected) {
                  setState(() {
                    _selectedType = selected.first;
                    // Reset description fields when switching type
                    if (_selectedType == TransactionType.expense) {
                      _descriptionController.text = '';
                    } else {
                      _selectedExpenseDescription = null;
                      _otherExpenseDescriptionController.text = '';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              // Amount input
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
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
              const SizedBox(height: 16),
              // Description input (dropdown for expense, text for income)
              if (isExpense) ...[
                DropdownButtonFormField<String>(
                  value: _selectedExpenseDescription,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  items: expenseDescriptions.map((desc) {
                    return DropdownMenuItem<String>(
                      value: desc,
                      child: Text(desc),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedExpenseDescription = value;
                      if (value != 'Other') {
                        _otherExpenseDescriptionController.text = '';
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a description';
                    }
                    if (value == 'Other' && _otherExpenseDescriptionController.text.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                if (_selectedExpenseDescription == 'Other') ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _otherExpenseDescriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Other Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_selectedExpenseDescription == 'Other' &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                ],
              ] else ...[
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              // Date picker
              OutlinedButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  'Date: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 24),
              // Submit button
              FilledButton(
                onPressed: _submitForm,
                child: Text(
                  widget.transaction == null ? 'Add Transaction' : 'Save Changes',
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}