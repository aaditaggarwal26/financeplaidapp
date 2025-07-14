import 'package:finsight/exports/transaction_exports.dart';
import 'package:finsight/screens/add_transactions_screen.dart';
import 'package:finsight/screens/transaction_detail_screen.dart';
import 'package:finsight/screens/receipt_scanner_screen.dart';
import 'package:finsight/services/plaid_service.dart';
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
  List<Transaction> allTransactions = [];
  List<Transaction> filteredTransactions = [];
  bool isLoading = true;
  bool _hasPlaidConnection = false;
  Map<String, int> _transactionCounts = {};

  final TextEditingController _searchController = TextEditingController();
  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());

  String selectedCategory = 'All';
  String selectedTransactionType = 'All';
  bool isSearchMenuOpen = false;
  DateTimeRange? selectedDateRange;

  final ScrollController _monthScrollController = ScrollController();
  final PlaidService _plaidService = PlaidService();
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _monthScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData({bool forceRefresh = false}) async {
    print('=== TransactionScreen: _initializeData called ===');
    print('forceRefresh: $forceRefresh');
    
    if (!mounted) return;
    
    setState(() { 
      isLoading = true; 
    });

    try {
      // Clear cache if forcing refresh
      if (forceRefresh) {
        DataService.clearTransactionCache();
      }

      // Check Plaid connection status
      _hasPlaidConnection = await _plaidService.hasPlaidConnection();
      print('TransactionScreen: Plaid connection status: $_hasPlaidConnection');

      // Load transactions using DataService with proper context
      final transactions = await _dataService.getTransactions(
        context: context,
        forceRefresh: forceRefresh,
      );

      // Get transaction counts
      final transactionCounts = await _dataService.getTransactionCounts(
        context: context,
      );

      print('TransactionScreen: Loaded ${transactions.length} transactions');
      print('TransactionScreen: Transaction counts: $transactionCounts');

      if (mounted) {
        setState(() {
          allTransactions = transactions;
          _transactionCounts = transactionCounts;
          _filterTransactions();
          isLoading = false;
        });
      }
    } catch (e) {
      print('TransactionScreen: Error initializing transaction data: $e');
      if (mounted) {
        setState(() { 
          isLoading = false; 
        });
        
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _initializeData(forceRefresh: true),
            ),
          ),
        );
      }
    }
  }

  void _filterTransactions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredTransactions = allTransactions.where((transaction) {
        final matchesSearch = query.isEmpty ||
            transaction.displayName.toLowerCase().contains(query) ||
            transaction.category.toLowerCase().contains(query);

        final matchesCategory = selectedCategory == 'All' || transaction.category == selectedCategory;
        final matchesType = selectedTransactionType == 'All' || transaction.transactionType == selectedTransactionType;
        final matchesDateRange = selectedDateRange == null ||
            (transaction.date.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
             transaction.date.isBefore(selectedDateRange!.end.add(const Duration(days: 1))));
        final matchesMonth = DateFormat('MMMM yyyy').format(transaction.date) == selectedMonth;

        return matchesSearch && matchesCategory && matchesType && matchesDateRange && matchesMonth;
      }).toList();
    });
  }

  List<String> _getAvailableMonths() {
    if (allTransactions.isEmpty) return [DateFormat('MMMM yyyy').format(DateTime.now())];
    final months = allTransactions.map((t) => DateFormat('MMMM yyyy').format(t.date)).toSet().toList();
    months.sort((a, b) => DateFormat('MMMM yyyy').parse(b).compareTo(DateFormat('MMMM yyyy').parse(a)));
    return months;
  }

  void _filterByMonth(String month) {
    if (mounted) {
      setState(() {
        selectedMonth = month;
        _filterTransactions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF2B3A55), 
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE5BA73))
        )
      );
    }

    if (allTransactions.isEmpty) {
      return _buildEmptyState();
    }
    
    final groupedTransactions = <String, List<Transaction>>{};
    for (var transaction in filteredTransactions) {
      final dateKey = DateFormat('MMMM d, yyyy').format(transaction.date);
      groupedTransactions.putIfAbsent(dateKey, () => []).add(transaction);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2B3A55),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildMonthSelector(),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _initializeData(forceRefresh: true),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24))
                  ),
                  child: filteredTransactions.isEmpty
                      ? _buildFilteredEmptyState()
                      : _buildTransactionList(groupedTransactions),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Transactions', 
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 24, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                  if (_hasPlaidConnection) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2), 
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: const Text(
                        'LIVE', 
                        style: TextStyle(
                          color: Colors.green, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white), 
                    onPressed: _handleDownload, 
                    tooltip: 'Download Transactions'
                  ),
                  IconButton(
                    icon: const Icon(Icons.document_scanner, color: Colors.white), 
                    onPressed: _handleScanReceipt, 
                    tooltip: 'Scan Receipt'
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.white), 
                    onPressed: _handleAddTransaction, 
                    tooltip: 'Add Transaction'
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
              borderRadius: BorderRadius.circular(12)
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (query) => _filterTransactions(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                hintStyle: const TextStyle(color: Colors.white70),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune, color: Colors.white70), 
                  onPressed: _showFilterMenu
                ),
              ),
            ),
          ),
          if (selectedCategory != 'All' || selectedTransactionType != 'All' || selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0), 
              child: _buildFilterChips()
            ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    final months = _getAvailableMonths();
    if (months.isEmpty) return const SizedBox(height: 40);
    return SizedBox(
      height: 40,
      child: ListView.builder(
        controller: _monthScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final month = months[index];
          final isSelected = month == selectedMonth;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                month, 
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF2B3A55), 
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                )
              ),
              selected: isSelected,
              selectedColor: const Color(0xFFE5BA73),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), 
                side: BorderSide(
                  color: isSelected ? const Color(0xFF2B3A55) : Colors.grey.shade300
                )
              ),
              onSelected: (selected) { 
                if (selected) _filterByMonth(month); 
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(Map<String, List<Transaction>> groupedTransactions) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final date = groupedTransactions.keys.elementAt(index);
        final dayTransactions = groupedTransactions[date]!;
        final totalSpend = dayTransactions
            .where((t) => t.transactionType == 'Debit')
            .fold(0.0, (sum, t) => sum + t.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date, 
                    style: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: Color(0xFF2B3A55)
                    )
                  ),
                  if (totalSpend > 0) 
                    Text(
                      '\$${totalSpend.toStringAsFixed(2)} total spend', 
                      style: const TextStyle(
                        fontSize: 14, 
                        color: Colors.grey
                      )
                    ),
                ],
              ),
            ),
            ...dayTransactions.map((transaction) => ListTile(
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => TransactionDetailScreen(
                      transaction: transaction, 
                      onDelete: transaction.isPersonal ? () {
                        if (mounted) {
                          setState(() {
                            allTransactions.remove(transaction);
                            _filterTransactions();
                          });
                        }
                      } : null
                    )
                  )
                ).then((_) => _initializeData());
              },
              leading: Container(
                width: 48, 
                height: 48,
                decoration: BoxDecoration(
                  color: _getCategoryColor(transaction.category).withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(12)
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (transaction.effectiveLogo != null)
                    ? Image.network(
                        transaction.effectiveLogo!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          _getCategoryIcon(transaction.category), 
                          color: _getCategoryColor(transaction.category), 
                          size: 24
                        ),
                      )
                    : Icon(
                        _getCategoryIcon(transaction.category), 
                        color: _getCategoryColor(transaction.category), 
                        size: 24
                      ),
                ),
              ),
              title: Text(
                transaction.displayName, 
                style: const TextStyle(
                  fontWeight: FontWeight.w500, 
                  color: Color(0xFF2B3A55)
                ), 
                overflow: TextOverflow.ellipsis
              ),
              subtitle: Text(
                transaction.category, 
                style: TextStyle(
                  color: Colors.grey[600], 
                  fontSize: 12
                )
              ),
              trailing: Text(
                transaction.formattedAmount,
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 15, 
                  color: transaction.transactionType == 'Credit' 
                      ? Colors.green 
                      : const Color(0xFF2B3A55)
                ),
              ),
            )),
          ],
        );
      },
    );
  }

  Widget _buildFilteredEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            allTransactions.isEmpty 
                ? 'No transactions available' 
                : 'No transactions found for current filters', 
            style: const TextStyle(
              color: Colors.grey, 
              fontSize: 16
            )
          ),
          if (allTransactions.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _resetFilters, 
              child: const Text('Clear Filters')
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: const Color(0xFF2B3A55),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24))
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 24),
                      const Text(
                        'No Transactions Found', 
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFF2B3A55)
                        )
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connect your bank account, scan receipts,\nor add transactions manually', 
                        textAlign: TextAlign.center, 
                        style: TextStyle(
                          fontSize: 16, 
                          color: Colors.grey
                        )
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 16, 
                        runSpacing: 16, 
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _handleConnectAccount, 
                            icon: const Icon(Icons.account_balance), 
                            label: const Text('Connect Account'), 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5BA73), 
                              foregroundColor: Colors.white, 
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                            )
                          ),
                          ElevatedButton.icon(
                            onPressed: _handleScanReceipt, 
                            icon: const Icon(Icons.document_scanner), 
                            label: const Text('Scan Receipt'), 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2B3A55), 
                              foregroundColor: Colors.white, 
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                            )
                          ),
                          ElevatedButton.icon(
                            onPressed: _handleAddTransaction, 
                            icon: const Icon(Icons.add), 
                            label: const Text('Add Manually'), 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[600], 
                              foregroundColor: Colors.white, 
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                            )
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetFilters() {
    if (!mounted) return;
    setState(() {
      selectedCategory = 'All';
      selectedTransactionType = 'All';
      selectedDateRange = null;
      _searchController.clear();
      _filterTransactions();
    });
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xFF2B3A55), 
            onPrimary: Colors.white, 
            onSurface: Colors.black
          )
        ), 
        child: child!
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        selectedDateRange = picked;
        _filterTransactions();
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
            onDeleted: () => setState(() { 
              selectedCategory = 'All'; 
              _filterTransactions(); 
            })
          ),
        if (selectedTransactionType != 'All') 
          Chip(
            label: Text(selectedTransactionType), 
            onDeleted: () => setState(() { 
              selectedTransactionType = 'All'; 
              _filterTransactions(); 
            })
          ),
        if (selectedDateRange != null) 
          Chip(
            label: Text(
              '${DateFormat('MMM d').format(selectedDateRange!.start)} - ${DateFormat('MMM d').format(selectedDateRange!.end)}'
            ), 
            onDeleted: () => setState(() { 
              selectedDateRange = null; 
              _filterTransactions(); 
            })
          ),
      ],
    );
  }

  void _showFilterMenu() {
    final categories = ['All', ...getCategoryIcons().keys.toList()];
    final transactionTypes = ['All', 'Credit', 'Debit'];
    
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
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
                  fontWeight: FontWeight.bold
                )
              ),
              const SizedBox(height: 20),
              const Text('Category'), 
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, 
                children: categories.map((category) => ChoiceChip(
                  label: Text(category), 
                  selected: selectedCategory == category, 
                  onSelected: (selected) => setModalState(() => 
                    selectedCategory = selected ? category : 'All'
                  )
                )).toList()
              ),
              const SizedBox(height: 16),
              const Text('Transaction Type'), 
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, 
                children: transactionTypes.map((type) => ChoiceChip(
                  label: Text(type), 
                  selected: selectedTransactionType == type, 
                  onSelected: (selected) => setModalState(() => 
                    selectedTransactionType = selected ? type : 'All'
                  )
                )).toList()
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async { 
                  await _showDateRangePicker(); 
                  if (mounted) Navigator.pop(context); 
                }, 
                child: const Text('Select Date Range')
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () { 
                  _resetFilters(); 
                  Navigator.pop(context); 
                }, 
                child: const Text('Reset All Filters')
              ),
            ],
          ),
        ),
      ),
    ).then((_) => _filterTransactions());
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
      'Subscriptions': Icons.subscriptions, 
      'Miscellaneous': Icons.more_horiz
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
      'Subscriptions': const Color(0xFFFF6B6B), 
      'Miscellaneous': const Color(0xFF95A5A6)
    };
    return colors[category] ?? Colors.grey;
  }
  
  IconData _getCategoryIcon(String category) {
    return getCategoryIcons()[category] ?? Icons.category;
  }

  void _handleDownload() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating report...'), 
            duration: Duration(seconds: 2)
          )
        );
      }
      
      final exporter = TransactionExport(filteredTransactions);
      await exporter.generateAndDownloadReport();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report generated successfully!'), 
            duration: Duration(seconds: 2)
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: ${e.toString()}'), 
            duration: const Duration(seconds: 3), 
            backgroundColor: Colors.red
          )
        );
      }
    }
  }

  void _handleAddTransaction() {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          onAdd: (Transaction transaction) async {
            try {
              await _dataService.appendTransaction(transaction);
              if (mounted) {
                _initializeData(forceRefresh: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction added successfully'), 
                    duration: Duration(seconds: 2)
                  )
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error adding transaction: $e'), 
                    backgroundColor: Colors.red, 
                    duration: const Duration(seconds: 3)
                  )
                );
              }
            }
          }
        )
      )
    );
  }

  void _handleScanReceipt() {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => const ReceiptScannerScreen()
      )
    ).then((_) => _initializeData(forceRefresh: true));
  }

  Future<void> _handleConnectAccount() async {
    try {
      final linkToken = await _plaidService.createLinkToken();
      if (linkToken != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please use the dashboard to connect your account'), 
            backgroundColor: Colors.blue
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'), 
            backgroundColor: Colors.red
          )
        );
      }
    }
  }
}