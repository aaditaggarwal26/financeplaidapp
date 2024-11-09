import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/services/data_service.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({Key? key}) : super(key: key);

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  List<Transaction> transactions = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Transaction> filteredTransactions = [];

  String selectedCategory = 'All';
  String selectedTransactionType = 'All';
  bool isSearchMenuOpen = false;
  DateTimeRange? selectedDateRange;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final dataService = DataService();
    final loadedTransactions = await dataService.getTransactions();
    setState(() {
      transactions = loadedTransactions;
      filteredTransactions = loadedTransactions;
      isLoading = false;
    });
  }

  void _filterTransactions(String query) {
    setState(() {
      filteredTransactions = transactions.where((transaction) {
        final matchesSearch = query.isEmpty ||
            transaction.description
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            transaction.category.toLowerCase().contains(query.toLowerCase()) ||
            transaction.amount.toString().contains(query) ||
            DateFormat('MMMM d, yyyy')
                .format(transaction.date)
                .toLowerCase()
                .contains(query.toLowerCase());

        final matchesCategory = selectedCategory == 'All' ||
            transaction.category == selectedCategory;

        final matchesType = selectedTransactionType == 'All' ||
            transaction.transactionType == selectedTransactionType;

        final matchesDateRange = selectedDateRange == null ||
            (transaction.date.isAfter(selectedDateRange!.start
                    .subtract(const Duration(days: 1))) &&
                transaction.date.isBefore(
                    selectedDateRange!.end.add(const Duration(days: 1))));

        return matchesSearch &&
            matchesCategory &&
            matchesType &&
            matchesDateRange;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      selectedCategory = 'All';
      selectedTransactionType = 'All';
      selectedDateRange = null;
      _searchController.clear();
      filteredTransactions = transactions;
    });
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
        _filterTransactions(_searchController.text);
      });
    }
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        if (selectedCategory != 'All')
          Chip(
            label: Text(selectedCategory),
            onDeleted: () {
              setState(() {
                selectedCategory = 'All';
                _filterTransactions(_searchController.text);
              });
            },
          ),
        if (selectedTransactionType != 'All')
          Chip(
            label: Text(selectedTransactionType),
            onDeleted: () {
              setState(() {
                selectedTransactionType = 'All';
                _filterTransactions(_searchController.text);
              });
            },
          ),
        if (selectedDateRange != null)
          Chip(
            label: Text(
              '${DateFormat('MMM d').format(selectedDateRange!.start)} - '
              '${DateFormat('MMM d').format(selectedDateRange!.end)}',
            ),
            onDeleted: () {
              setState(() {
                selectedDateRange = null;
                _filterTransactions(_searchController.text);
              });
            },
          ),
      ],
    );
  }

  void _showFilterMenu() {
    final categories = ['All', ...getCategoryIcons().keys.toList()];
    final transactionTypes = ['All', 'Credit', 'Debit'];

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Transactions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text('Category'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: categories
                    .map((category) => ChoiceChip(
                          backgroundColor: Colors.white,
                          selectedColor: Color(0xFFE5BA73),
                          label: Text(category),
                          selected: selectedCategory == category,
                          onSelected: (selected) {
                            setModalState(() {
                              setState(() {
                                selectedCategory = selected ? category : 'All';
                                _filterTransactions(_searchController.text);
                              });
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text('Transaction Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: transactionTypes
                    .map((type) => ChoiceChip(
                          backgroundColor: Colors.white,
                          selectedColor: Color(0xFFE5BA73),
                          label: Text(type),
                          selected: selectedTransactionType == type,
                          onSelected: (selected) {
                            setModalState(() {
                              setState(() {
                                selectedTransactionType =
                                    selected ? type : 'All';
                                _filterTransactions(_searchController.text);
                              });
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                onPressed: () async {
                  await _showDateRangePicker();
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Select Date Range',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _resetFilters();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2B3A55),
                ),
                child: const Text(
                  'Reset All Filters',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, IconData> getCategoryIcons() {
    return {
      'Groceries': Icons.shopping_cart,
      'Utilities': Icons.power,
      'Rent': Icons.home,
      'Transportation': Icons.directions_car,
      'Entertainment': Icons.sports_esports,
      'Dining Out': Icons.restaurant,
      'Shopping': Icons.shopping_bag,
      'Healthcare': Icons.local_hospital,
      'Insurance': Icons.security,
      'Miscellaneous': Icons.more_horiz,
    };
  }

  Color _getCategoryColor(String category) {
    final colors = {
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
    return colors[category] ?? Colors.grey;
  }

  void _handleDownload() {
    //actually implement the logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading transactions...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleAddTransaction() {
    //actually implement the logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Add Transaction'),
        content:
            const Text('This is a placeholder for adding a new transaction.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final groupedTransactions = <String, List<Transaction>>{};
    for (var transaction in filteredTransactions) {
      final monthKey = DateFormat('MMMM').format(transaction.date);
      if (!groupedTransactions.containsKey(monthKey)) {
        groupedTransactions[monthKey] = [];
      }
      groupedTransactions[monthKey]!.add(transaction);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2B3A55),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transactions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.download, color: Colors.white),
                            onPressed: _handleDownload,
                            tooltip: 'Download Transactions',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.white),
                            onPressed: _handleAddTransaction,
                            tooltip: 'Add Transaction',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterTransactions,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white70),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.tune, color: Colors.white70),
                          onPressed: _showFilterMenu,
                        ),
                      ),
                    ),
                  ),
                  if (selectedCategory != 'All' ||
                      selectedTransactionType != 'All' ||
                      selectedDateRange != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _buildFilterChips(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: filteredTransactions.isEmpty
                    ? const Center(
                        child: Text(
                          'No transactions found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: groupedTransactions.length,
                        itemBuilder: (context, index) {
                          final month =
                              groupedTransactions.keys.elementAt(index);
                          final monthTransactions = groupedTransactions[month]!;
                          final totalSpend = monthTransactions
                              .where((t) => t.transactionType == 'Debit')
                              .fold(0.0, (sum, t) => sum + t.amount);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      month,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2B3A55),
                                      ),
                                    ),
                                    Text(
                                      '\$${totalSpend.toStringAsFixed(2)} total spend',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...monthTransactions.map((transaction) =>
                                  ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(
                                                transaction.category)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        getCategoryIcons()[
                                                transaction.category] ??
                                            Icons.category,
                                        color: _getCategoryColor(
                                            transaction.category),
                                        size: 24,
                                      ),
                                    ),
                                    title: Text(
                                      transaction.description,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2B3A55),
                                      ),
                                    ),
                                    subtitle: Text(
                                      DateFormat('MMMM d')
                                          .format(transaction.date),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: Text(
                                      transaction.transactionType == 'Credit'
                                          ? '+\$${transaction.amount.toStringAsFixed(2)}'
                                          : '\$${transaction.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: transaction.transactionType ==
                                                'Credit'
                                            ? Colors.green
                                            : const Color(0xFF2B3A55),
                                      ),
                                    ),
                                  )),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
