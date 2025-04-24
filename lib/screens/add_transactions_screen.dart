// This screen allows users to add new transactions with details like amount, category, and date.
import 'package:finsight/models/transaction.dart';
import 'package:finsight/widgets/amount_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Main widget for the add transaction screen, requiring a callback to handle the new transaction.
class AddTransactionScreen extends StatefulWidget {
  // Callback function to pass the created transaction back to the parent.
  final Function(Transaction) onAdd;

  const AddTransactionScreen({Key? key, required this.onAdd}) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

// State class managing the form inputs and transaction creation logic.
class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // Form key for validating input fields.
  final _formKey = GlobalKey<FormState>();
  // Selected date for the transaction, defaults to today.
  late DateTime _selectedDate;
  // Controllers for description and amount input fields.
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  // Default category and transaction type for dropdowns.
  String _selectedCategory = 'Groceries';
  String _selectedTransactionType = 'Debit';

  // Map of categories to their respective colors for consistent theming.
  final Map<String, Color> categoryColors = {
    'Groceries': const Color(0xFFE5BA73),
    'Utilities': const Color(0xFF4A90E2),
    'Rent': const Color(0xFF2B3A55),
    'Transportation': const Color(0xFF50C878),
    'Entertainment': const Color(0xFFE67E22),
    'Dining Out': const Color(0xFFE74C3C),
    'Shopping': const Color(0xFF9B59B6),
    'Healthcare': const Color(0xFF1ABC9C),
    'Insurance': const Color(0xFF34495E),
    'Miscellaneous': const Color(0xFF95A5A6),
  };

  // Returns an icon for each category to enhance visual clarity.
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Groceries':
        return Icons.shopping_basket;
      case 'Utilities':
        return Icons.power;
      case 'Rent':
        return Icons.home;
      case 'Transportation':
        return Icons.directions_car;
      case 'Entertainment':
        return Icons.movie;
      case 'Dining Out':
        return Icons.restaurant;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Healthcare':
        return Icons.medical_services;
      case 'Insurance':
        return Icons.security;
      default:
        return Icons.attach_money;
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize the date and text controllers.
    _selectedDate = DateTime.now();
    _descriptionController = TextEditingController();
    _amountController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    // Main scaffold with a form for entering transaction details.
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header section with dynamic background color based on selected category.
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 32,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: categoryColors[_selectedCategory],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  // Top bar with title and close button.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Transaction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Amount input field with validation.
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: AmountInput(
                        controller: _amountController,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          if (double.tryParse(value!) == null) {
                            return 'Invalid amount';
                          }
                          if (double.parse(value) <= 0.0) {
                            return 'Invalid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Dropdown for selecting the transaction category.
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      dropdownColor: categoryColors[_selectedCategory],
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Colors.white),
                      underline: Container(),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: categoryColors.keys.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getCategoryIcon(category),
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(category),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          // Update the selected category and refresh the UI.
                          setState(() => _selectedCategory = newValue);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Form fields section, scrollable for smaller screens.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Card containing description, date, and transaction type inputs.
                  _buildCard([
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildDatePicker(context),
                    const SizedBox(height: 16),
                    _buildTransactionTypePicker(),
                  ]),
                  const SizedBox(height: 32),
                  // Save button to submit the transaction.
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: categoryColors[_selectedCategory],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _saveTransaction,
                    child: const Text(
                      'Save Transaction',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a card widget to group form fields with a shadow effect.
  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  // Build a text input field with validation.
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }

  // Build a date picker field with a formatted display.
  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      onTap: () async {
        // Show a date picker dialog and update the selected date.
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF2B3A55), // Navy color for selected date
                  onPrimary: Colors.white, // White text for selected date
                  surface: Colors.white, // White background
                  onSurface: Color(0xFF2B3A55), // Navy text for calendar
                ),
                dialogBackgroundColor: Colors.white,
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }

  // Build a dropdown for selecting the transaction type (Debit, Credit, Cash).
  Widget _buildTransactionTypePicker() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Transaction Type',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTransactionType,
          isDense: true,
          items: ['Debit', 'Credit', 'Cash'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              // Update the selected transaction type and refresh the UI.
              setState(() => _selectedTransactionType = newValue);
            }
          },
        ),
      ),
    );
  }

  // Validate and save the transaction, passing it to the parent via the callback.
  void _saveTransaction() {
    if (_formKey.currentState?.validate() ?? false) {
      double amount = double.parse(_amountController.text);
      // Make amount negative for credit card transactions to indicate debt.
      if (_selectedTransactionType == 'Credit') {
        amount = -amount;
      }

      // Create a new Transaction object with the form data.
      final transaction = Transaction(
        date: _selectedDate,
        description: _descriptionController.text,
        category: _selectedCategory,
        amount: amount,
        account: _selectedTransactionType == 'Credit' ? 'Credit Card' : 'Cash',
        transactionType: _selectedTransactionType,
        isPersonal: true,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      // Pass the transaction to the parent and close the screen.
      widget.onAdd(transaction);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks.
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}