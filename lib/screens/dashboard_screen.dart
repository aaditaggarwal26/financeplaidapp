import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finsight/models/account_balance.dart';
import 'package:finsight/models/checking_account.dart';
import 'package:finsight/models/credit_card.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/services/data_service.dart';
import 'package:finsight/services/plaid_service.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:finsight/screens/spending_screen.dart';
import 'dart:async';

// Main widget for the financial dashboard
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// State class managing dashboard logic and UI
class _DashboardScreenState extends State<DashboardScreen> with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final DataService _dataService = DataService();
  final PlaidService _plaidService = PlaidService();
  final User? _user = FirebaseAuth.instance.currentUser;
  late Future<List<AccountBalance>> _balancesFuture;
  late Future<List<Transaction>> _transactionsFuture;
  late Future<List<Map<String, dynamic>>> _plaidAccountsFuture;
  int _currentPage = 0;
  static bool _hasLoadedData = false;
  bool _showBalances = true;
  bool _isLoading = false;
  bool _usePlaidData = false;
  List<Map<String, dynamic>> _plaidAccounts = [];

  // Plaid Link stream subscriptions
  late final StreamSubscription<LinkSuccess>? _successSubscription;
  late final StreamSubscription<LinkExit>? _exitSubscription;

  // Tracks expanded account sections
  final Map<String, bool> _expandedSections = {
    'Checking': false,
    'Card Balance': false,
    'Net Cash': false,
    'Investments': false,
  };

  // Financial wellness data
  final double _financialWellnessScore = 78;
  final List<WellnessMetric> _wellnessMetrics = [
    WellnessMetric(name: 'Spending', score: 65, description: 'Your spending is 10% higher than recommended.'),
    WellnessMetric(name: 'Savings', score: 82, description: 'Your saving rate is on track for your goals.'),
    WellnessMetric(name: 'Debt', score: 75, description: 'Credit utilization is within good range.'),
    WellnessMetric(name: 'Investments', score: 90, description: 'Your investment strategy is working well.'),
  ];

  // Budget categories data
  List<BudgetCategory> _budgetCategories = [
    BudgetCategory(name: 'Housing', spent: 1500, budget: 1600, color: Colors.blue),
    BudgetCategory(name: 'Food', spent: 720, budget: 650, color: Colors.red),
    BudgetCategory(name: 'Transportation', spent: 320, budget: 400, color: Colors.green),
    BudgetCategory(name: 'Entertainment', spent: 280, budget: 300, color: Colors.purple),
    BudgetCategory(name: 'Utilities', spent: 180, budget: 200, color: Colors.orange),
  ];

  // Monthly cash flow data
  final Map<String, double> _monthlyCashFlow = {
    'Income': 5800,
    'Expenses': 4200,
    'Savings': 1600,
  };

  // Spending trends data
  final List<SpendingTrend> _spendingTrends = [
    SpendingTrend(category: 'Groceries', currentSpend: 450, previousSpend: 420, trend: 7.1),
    SpendingTrend(category: 'Dining Out', currentSpend: 380, previousSpend: 320, trend: 18.8),
    SpendingTrend(category: 'Shopping', currentSpend: 320, previousSpend: 350, trend: -8.6),
    SpendingTrend(category: 'Entertainment', currentSpend: 180, previousSpend: 190, trend: -5.3),
  ];

  // Credit score history data
  final List<CreditScoreData> _creditScoreHistory = [
    CreditScoreData(DateTime(2023, 10), 723),
    CreditScoreData(DateTime(2023, 11), 728),
    CreditScoreData(DateTime(2023, 12), 732),
    CreditScoreData(DateTime(2024, 1), 735),
    CreditScoreData(DateTime(2024, 2), 738),
    CreditScoreData(DateTime(2024, 3), 741),
    CreditScoreData(DateTime(2024, 4), 745),
  ];

  // Text controllers for dialogs
  final TextEditingController _categoryNameController = TextEditingController();
  final TextEditingController _budgetAmountController = TextEditingController();

  // State for dashboard customization
  final Map<String, bool> _widgetVisibility = {
    'Financial Wellness': true,
    'Monthly Budget': true,
    'Cash Flow': true,
    'Spending Trends': true,
    'Credit Score': true,
    'Smart Insights': true,
    'Bill Reminders': false,
    'Investment Performance': false,
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkPlaidConnection();
    _initPlaidListeners();
  }

  // Initializes Plaid Link event listeners
  void _initPlaidListeners() {
    _successSubscription = PlaidLink.onSuccess.listen((LinkSuccess success) async {
      print('Plaid success: ${success.publicToken}');
      final result = await _plaidService.exchangePublicToken(success.publicToken);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _usePlaidData = result;
        });
        if (result) {
          _loadPlaidData();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account connected successfully!'), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to connect account'), backgroundColor: Colors.red));
        }
      }
    });

    _exitSubscription = PlaidLink.onExit.listen((LinkExit exit) {
      if (exit.error != null) {
        print('Plaid error: ${exit.error?.displayMessage}');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${exit.error?.displayMessage ?? 'Connection failed'}'), backgroundColor: Colors.red));
        }
      } else {
        print('Plaid link closed without error');
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  // Checks for existing Plaid connection
  Future<void> _checkPlaidConnection() async {
    final hasConnection = await _plaidService.hasPlaidConnection();
    if (hasConnection && mounted) {
      setState(() => _usePlaidData = true);
      _loadPlaidData();
    }
  }

  // Initializes data loading
  void _initializeData() {
    if (!_hasLoadedData) {
      setState(() {
        _balancesFuture = Future.value([]);
        _transactionsFuture = Future.value([]);
        _plaidAccountsFuture = Future.value([]);
      });
    } else {
      _loadData();
    }
  }

  // Loads data from DataService
  void _loadData() {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _usePlaidData = false;
    });
    setState(() {
      _balancesFuture = _dataService.getAccountBalances();
      _transactionsFuture = _dataService.getTransactions();
      _hasLoadedData = true;
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // Loads data from Plaid
  void _loadPlaidData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final accounts = await _plaidService.getAccounts(context);
      final transactions = await _plaidService.fetchTransactions(context: context, startDate: DateTime.now().subtract(const Duration(days: 30)), endDate: DateTime.now());
      if (!mounted) return;
      setState(() {
        _plaidAccounts = accounts;
        _transactionsFuture = Future.value(transactions);
        _usePlaidData = true;
        final checkingBalance = _getTotalBalanceByType(accounts, 'depository');
        final creditCardBalance = _getTotalBalanceByType(accounts, 'credit') * -1;
        final investmentBalance = _getTotalBalanceByType(accounts, 'investment');
        final synthBalance = AccountBalance(
          date: DateTime.now(),
          checking: checkingBalance,
          creditCardBalance: creditCardBalance,
          savings: 0,
          investmentAccount: investmentBalance,
          netWorth: checkingBalance + creditCardBalance + investmentBalance,
        );
        _balancesFuture = Future.value([synthBalance]);
        _hasLoadedData = true;
      });
    } catch (e) {
      print('Error loading Plaid data: $e');
      if (mounted) _loadData();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Calculates total balance by account type
  double _getTotalBalanceByType(List<Map<String, dynamic>> accounts, String type) {
    double total = 0;
    for (var account in accounts) {
      if (account['type'] == type) total += (account['balance']['current'] ?? 0).toDouble();
    }
    return total;
  }

  // Refreshes dashboard data
  void _refreshData() {
    if (_usePlaidData) _loadPlaidData();
    else _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _categoryNameController.dispose();
    _budgetAmountController.dispose();
    _successSubscription?.cancel();
    _exitSubscription?.cancel();
    super.dispose();
  }

  // Builds the welcome banner with greeting and quick actions
  Widget _buildWelcomeBanner() {
    final currentHour = DateTime.now().hour;
    String greeting = currentHour < 12 ? "Good Morning" : currentHour < 17 ? "Good Afternoon" : "Good Evening";
    greeting += ", ${_user?.displayName ?? 'User'}!";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2B3A55), Color(0xFF3D5377)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(0),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(DateFormat('EEEE, MMM d').format(DateTime.now()), style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFE5BA73), borderRadius: BorderRadius.circular(12)),
                          child: Text('Premium', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                  child: IconButton(
                    icon: Icon(_showBalances ? Icons.visibility : Icons.visibility_off, color: Colors.white),
                    onPressed: () => setState(() => _showBalances = !_showBalances),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(children: [
              const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(width: 8),
              Icon(Icons.info_outline, size: 14, color: Colors.white.withOpacity(0.6)),
            ]),
            const SizedBox(height: 8),
            FutureBuilder<List<AccountBalance>>(
              future: _balancesFuture,
              builder: (context, snapshot) {
                double totalBalance = 0;
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final latestBalance = snapshot.data!.last;
                  totalBalance = latestBalance.checking + latestBalance.creditCardBalance + latestBalance.investmentAccount + latestBalance.savings;
                }
                return Text(
                  _showBalances ? '\$${NumberFormat('#,##0.00').format(totalBalance)}' : '••••••',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionButton(icon: Icons.receipt_long, label: 'Receipt Scan', onTap: _showReceiptScanner),
                _buildQuickActionButton(icon: Icons.flag_outlined, label: 'Set Goals', onTap: _showGoalsDialog),
                _buildQuickActionButton(icon: Icons.account_balance_wallet_outlined, label: 'Link Account', onTap: _handleAddAccount),
                _buildQuickActionButton(icon: Icons.pie_chart_outline, label: 'Customize', onTap: _showDashboardCustomizer),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Creates a quick action button with updated colors
  Widget _buildQuickActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFE5BA73), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF2B3A55), size: 22),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  // Dialog for adding money
  void _showAddMoneyDialog() {
    final TextEditingController amountController = TextEditingController();
    List<String> accounts = _usePlaidData && _plaidAccounts.isNotEmpty
        ? _plaidAccounts.where((account) => account['type'] == 'depository').map((account) => '${account['name']} (${account['mask'] ?? '****'})').toList()
        : ['Checking Account'];
    String selectedAccount = accounts.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Money'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: selectedAccount,
                isExpanded: true,
                items: accounts.map((account) => DropdownMenuItem<String>(value: account, child: Text(account))).toList(),
                onChanged: (value) => setState(() => selectedAccount = value!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\$$amount added to $selectedAccount'), backgroundColor: Colors.green));
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog for sending money
  void _showSendMoneyDialog() {
    final TextEditingController recipientController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    List<String> accounts = _usePlaidData && _plaidAccounts.isNotEmpty
        ? _plaidAccounts.where((account) => account['type'] == 'depository').map((account) => '${account['name']} (${account['mask'] ?? '****'})').toList()
        : ['Checking Account'];
    String selectedAccount = accounts.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Send Money'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: recipientController, decoration: const InputDecoration(labelText: 'Recipient')),
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: selectedAccount,
                isExpanded: true,
                items: accounts.map((account) => DropdownMenuItem<String>(value: account, child: Text(account))).toList(),
                onChanged: (value) => setState(() => selectedAccount = value!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0 && recipientController.text.isNotEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('\$$amount sent from $selectedAccount to ${recipientController.text}'), backgroundColor: Colors.green));
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog for analytics or Plaid prompt
  void _showAnalyticsDialog() {
    if (_usePlaidData) {
      Navigator.pushNamed(context, '/analytics');
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connect for Better Analytics'),
          content: const Text('Connect your accounts with Plaid to get personalized analytics based on your real financial data.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
            TextButton(onPressed: () { Navigator.pop(context); _handleAddAccount(); }, child: const Text('Connect Now')),
          ],
        ),
      );
    }
  }

  // Financial wellness section
  Widget _buildFinancialWellnessScore() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Financial Wellness', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B3A55))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getWellnessScoreColor(_financialWellnessScore).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getWellnessScoreColor(_financialWellnessScore).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Text('$_financialWellnessScore', style: TextStyle(color: _getWellnessScoreColor(_financialWellnessScore), fontWeight: FontWeight.bold)),
                      Text('/100', style: TextStyle(color: _getWellnessScoreColor(_financialWellnessScore).withOpacity(0.7), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _wellnessMetrics.length,
                itemBuilder: (context, index) {
                  final metric = _wellnessMetrics[index];
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getWellnessScoreColor(metric.score).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getWellnessScoreColor(metric.score).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: Text(metric.name, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[800]), overflow: TextOverflow.ellipsis)),
                            Text(metric.score.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: _getWellnessScoreColor(metric.score))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 6,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: metric.score / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(_getWellnessScoreColor(metric.score)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(child: Text(metric.description, style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Color logic for wellness scores
  Color _getWellnessScoreColor(double score) => score >= 80 ? Colors.green : score >= 60 ? Colors.amber : Colors.red;

  // Monthly budget section
  Widget _buildBudgetSummary() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Monthly Budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B3A55))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF2B3A55).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(DateFormat('MMMM yyyy').format(DateTime.now()), style: const TextStyle(fontSize: 12, color: Color(0xFF2B3A55), fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _budgetCategories.length,
              itemBuilder: (context, index) {
                final category = _budgetCategories[index];
                final progress = category.spent / category.budget;
                final isOverBudget = category.spent > category.budget;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: '\$${category.spent.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: isOverBudget ? Colors.red : Colors.black87, fontSize: 15)),
                                TextSpan(text: ' / \$${category.budget.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(height: 8, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                          Container(
                            height: 8,
                            width: MediaQuery.of(context).size.width * 0.8 * min(progress, 1.0),
                            decoration: BoxDecoration(color: isOverBudget ? Colors.red : category.color, borderRadius: BorderRadius.circular(4)),
                          ),
                        ],
                      ),
                      if (isOverBudget) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text('Over budget by \$${(category.spent - category.budget).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                        ]),
                      ],
                    ],
                  ),
                );
              },
            ),
            Center(
              child: TextButton.icon(
                onPressed: _addBudgetCategory,
                icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF2B3A55)),
                label: const Text('Add Budget Category', style: TextStyle(color: Color(0xFF2B3A55))),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Adds a new budget category
  void _addBudgetCategory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Budget Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _categoryNameController, decoration: const InputDecoration(labelText: 'Category Name')),
            TextField(controller: _budgetAmountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Budget Amount')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final name = _categoryNameController.text;
              final amount = double.tryParse(_budgetAmountController.text) ?? 0;
              if (name.isNotEmpty && amount > 0) {
                setState(() {
                  _budgetCategories.add(BudgetCategory(
                    name: name,
                    spent: 0,
                    budget: amount,
                    color: Colors.primaries[_budgetCategories.length % Colors.primaries.length],
                  ));
                });
                _categoryNameController.clear();
                _budgetAmountController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Monthly cash flow section
  Widget _buildCashFlowCard() {
    final total = _monthlyCashFlow['Income']!;
    final expenses = _monthlyCashFlow['Expenses']!;
    final savings = _monthlyCashFlow['Savings']!;
    final expensesPercentage = expenses / total * 100;
    final savingsPercentage = savings / total * 100;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Cash Flow', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B3A55))),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 400) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 180,
                        width: constraints.maxWidth * 0.55,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(value: expensesPercentage, title: '${expensesPercentage.toStringAsFixed(0)}%', color: Colors.red.shade400, radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              PieChartSectionData(value: savingsPercentage, title: '${savingsPercentage.toStringAsFixed(0)}%', color: Colors.green.shade400, radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCashFlowLegendItem(label: 'Income', amount: total, color: const Color(0xFF2B3A55)),
                            const SizedBox(height: 16),
                            _buildCashFlowLegendItem(label: 'Expenses', amount: expenses, color: Colors.red.shade400, percentage: expensesPercentage),
                            const SizedBox(height: 16),
                            _buildCashFlowLegendItem(label: 'Savings', amount: savings, color: Colors.green.shade400, percentage: savingsPercentage),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(value: expensesPercentage, title: '${expensesPercentage.toStringAsFixed(0)}%', color: Colors.red.shade400, radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              PieChartSectionData(value: savingsPercentage, title: '${savingsPercentage.toStringAsFixed(0)}%', color: Colors.green.shade400, radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCashFlowLegendItem(label: 'Income', amount: total, color: const Color(0xFF2B3A55)),
                          const SizedBox(height: 16),
                          _buildCashFlowLegendItem(label: 'Expenses', amount: expenses, color: Colors.red.shade400, percentage: expensesPercentage),
                          const SizedBox(height: 16),
                          _buildCashFlowLegendItem(label: 'Savings', amount: savings, color: Colors.green.shade400, percentage: savingsPercentage),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('You\'re saving ${savingsPercentage.toStringAsFixed(0)}% of your income. Financial experts recommend saving at least 20%.', style: TextStyle(color: Colors.blue.shade700, fontSize: 13))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cash flow legend item
  Widget _buildCashFlowLegendItem({required String label, required double amount, required Color color, double? percentage}) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Flexible(child: Text('\$${amount.toStringAsFixed(0)}'.fixInterpolation(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  if (percentage != null) ...[const SizedBox(width: 4), Text('(${percentage.toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: Colors.grey[600]))],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Smart insights section
  Widget _buildInsights() {
    return FutureBuilder<List<FinancialInsight>>(
      future: _fetchAIInsights(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('Error loading insights'));
        final insights = snapshot.data ?? [];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.lightbulb_outline, color: Color(0xFFE5BA73), size: 22),
                  SizedBox(width: 8),
                  Text('Smart Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B3A55))),
                ]),
                const SizedBox(height: 4),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: insights.length,
                  itemBuilder: (context, index) {
                    final insight = insights[index];
                    final isLast = index == insights.length - 1;
                    return Container(
                      margin: EdgeInsets.only(bottom: isLast ? 0 : 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: insight.actionColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: insight.actionColor.withOpacity(0.2))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(insight.icon, color: insight.actionColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(insight.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          ]),
                          const SizedBox(height: 8),
                          Text(insight.description, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Fetches mock insights
  Future<List<FinancialInsight>> _fetchAIInsights() async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      FinancialInsight(title: 'High Dining Expenses', description: 'You spent 20% more on dining this month. Consider cooking at home.', action: 'View Details', actionColor: Colors.amber, icon: Icons.restaurant),
      FinancialInsight(title: 'Savings Opportunity', description: 'Increase savings by 5% to meet your goals faster.', action: 'Adjust Savings', actionColor: Colors.green, icon: Icons.savings),
      FinancialInsight(title: 'Subscription Review', description: 'You have unused subscriptions costing \$30/month.', action: 'Review', actionColor: Colors.blue, icon: Icons.subscriptions),
    ];
  }

  // Spending trends section
  Widget _buildSpendingTrends() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Spending Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B3A55))),
            const SizedBox(height: 6),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _spendingTrends.length,
              itemBuilder: (context, index) {
                final trend = _spendingTrends[index];
                final isLast = index == _spendingTrends.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: _getCategoryColor(trend.category).withOpacity(0.1), shape: BoxShape.circle),
                        child: Center(child: Icon(_getCategoryIcon(trend.category), color: _getCategoryColor(trend.category), size: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trend.category, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                children: [
                                  TextSpan(text: '\$${trend.currentSpend.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: ' this month', style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: trend.trend > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(trend.trend > 0 ? Icons.arrow_upward : Icons.arrow_downward, color: trend.trend > 0 ? Colors.red : Colors.green, size: 14),
                            const SizedBox(width: 4),
                            Text('${trend.trend.abs().toStringAsFixed(1)}%', style: TextStyle(color: trend.trend > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SpendingScreen())),
                child: const Text('View All Categories', style: TextStyle(color: Color(0xFF2B3A55), fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Category color mapping
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Groceries': return Colors.green;
      case 'Dining Out': return Colors.orange;
      case 'Shopping': return Colors.purple;
      case 'Entertainment': return Colors.blue;
      default: return Colors.grey;
    }
  }

  // Category icon mapping
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Groceries': return Icons.shopping_basket;
      case 'Dining Out': return Icons.restaurant;
      case 'Shopping': return Icons.shopping_bag;
      case 'Entertainment': return Icons.movie;
      default: return Icons.category;
    }
  }

  // Empty state UI
  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/images/logo_cropped.png', height: 120, width: 120),
        const SizedBox(height: 20),
        const Text('It seems like you have no accounts connected!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF2B3A55))),
        const SizedBox(height: 8),
        const Text('Connect an account now to get started.', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _handleAddAccount,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Connect Account'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5BA73), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ],
    );
  }

  // Fetches Plaid credit score
  Future<int?> _getPlaidCreditScore() async {
    if (_usePlaidData && _plaidAccounts.isNotEmpty) {
      try {
        return 720 + (DateTime.now().millisecond % 80);
      } catch (e) {
        print('Error getting credit score: $e');
      }
    }
    return null;
  }

  // Credit score section
  Widget _buildCreditScoreCard() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<int?>(
          future: _getPlaidCreditScore(),
          builder: (context, snapshot) {
            final score = snapshot.data ?? _creditScoreHistory.last.score;
            final prevScore = _creditScoreHistory[_creditScoreHistory.length - 2].score;
            final difference = score - prevScore;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Credit Score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B3A55))),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(score.toString(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF2B3A55))),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: difference >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(difference >= 0 ? Icons.arrow_upward : Icons.arrow_downward, color: difference >= 0 ? Colors.green : Colors.red, size: 14),
                          const SizedBox(width: 4),
                          Text('${difference.abs()} points', style: TextStyle(color: difference >= 0 ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _buildCreditScoreLabel(score),
                  ],
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['Poor', 'Fair', 'Good', 'Very Good', 'Excellent'].map((label) => Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))).toList()),
                const SizedBox(height: 5),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    return Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: const LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.lightGreen, Colors.green])),
                        ),
                        Positioned(
                          left: ((score - 300) / 550 * barWidth).clamp(0, barWidth - 12),
                          child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF2B3A55), width: 3))),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 5),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['300', '850'].map((label) => Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))).toList()),
                const SizedBox(height: 24),
                SizedBox(
                  height: 120,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < _creditScoreHistory.length) {
                                return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat('MMM').format(_creditScoreHistory[value.toInt()].date), style: TextStyle(color: Colors.grey[600], fontSize: 10)));
                              }
                              return const SizedBox();
                            },
                            reservedSize: 30,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (_creditScoreHistory.length - 1).toDouble(),
                      minY: _creditScoreHistory.map((e) => e.score).reduce(min).toDouble() - 10,
                      maxY: _creditScoreHistory.map((e) => e.score).reduce(max).toDouble() + 10,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _creditScoreHistory.asMap().entries.map((entry) => FlSpot(entry.key.toDouble(), entry.value.score.toDouble())).toList(),
                          isCurved: true,
                          color: const Color(0xFF2B3A55),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: const Color(0xFF2B3A55), strokeWidth: 2, strokeColor: Colors.white)),
                          belowBarData: BarAreaData(show: true, color: const Color(0xFF2B3A55).withOpacity(0.1)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Credit score label
  Widget _buildCreditScoreLabel(int score) {
    String label;
    Color color;
    if (score >= 800) { label = 'Excellent'; color = Colors.green; }
    else if (score >= 740) { label = 'Very Good'; color = Colors.lightGreen; }
    else if (score >= 670) { label = 'Good'; color = Colors.yellow.shade700; }
    else if (score >= 580) { label = 'Fair'; color = Colors.orange; }
    else { label = 'Poor'; color = Colors.red; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  // Formats balance values
  String _getFormattedValue(String rawValue, dynamic latestBalance) {
    if (rawValue.contains(r'${') && rawValue.contains('}')) {
      if (rawValue.contains('latestBalance.checking')) return '\$${latestBalance.checking.toStringAsFixed(2)}';
      else if (rawValue.contains('creditCardBalance')) return '-\$${latestBalance.creditCardBalance.abs().toStringAsFixed(2)}';
      else if (rawValue.contains('checking + latestBalance.creditCardBalance')) return '\$${(latestBalance.checking + latestBalance.creditCardBalance).toStringAsFixed(2)}';
      else if (rawValue.contains('investmentAccount')) return '\$${latestBalance.investmentAccount.toStringAsFixed(2)}';
    }
    return rawValue;
  }

  // Account item card
  Widget _buildAccountItemCard(String title, String amount, IconData icon, {Color? amountColor, bool expandable = true, bool showPlaceholder = false, required AccountBalance latestBalance}) {
    final displayAmount = _showBalances ? _getFormattedValue(amount, latestBalance) : '••••••';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
        color: Colors.white,
        child: Column(
          children: [
            InkWell(
              onTap: expandable ? () => setState(() => _expandedSections[title] = !_expandedSections[title]!) : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF2B3A55).withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: const Color(0xFF2B3A55), size: 24)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          showPlaceholder
                              ? Container(width: 80, height: 20, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))
                              : Text(displayAmount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: amountColor)),
                        ],
                      ),
                    ),
                    if (expandable) Icon(_expandedSections[title]! ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            if (expandable && _expandedSections[title]!) Container(width: double.infinity, decoration: BoxDecoration(color: Colors.grey[50], borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))), child: _buildExpandedSection(title)),
          ],
        ),
      ),
    );
  }

  // Expanded section for accounts
  Widget _buildExpandedSection(String title) {
    if (_usePlaidData && (title == 'Checking' || title == 'Card Balance' || title == 'Investments')) return _buildPlaidExpandedSection(title);
    switch (title) {
      case 'Checking':
        return FutureBuilder<List<CheckingAccount>>(
          future: _dataService.getCheckingAccounts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFE5BA73))));
            return Column(children: snapshot.data!.map((account) => _buildAccountSubItem(name: account.name, subtitle: '${account.bankName} - ${account.type}', amount: '\$${account.balance.toStringAsFixed(2)}')).toList());
          },
        );
      case 'Card Balance':
        return FutureBuilder<List<CreditCard>>(
          future: _dataService.getCreditCards(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFE5BA73))));
            return Column(children: snapshot.data!.map((card) => _buildCreditCardItem(card)).toList());
          },
        );
      case 'Investments':
        return Column(
          children: [
            _buildInvestmentItem(name: '401(k) Account', subtitle: 'Plaid Target Retirement 2055', amount: '\$45,000.00', returnRate: 8.5, showGraph: true),
            _buildInvestmentItem(name: 'Certificate of Deposit', subtitle: '1-Year CD @ 4.5% APY', amount: '\$10,435.62', returnRate: 4.5, showCDDetails: true),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  // Plaid expanded section
  Widget _buildPlaidExpandedSection(String title) {
    if (_plaidAccounts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No Plaid accounts available')));
    List<Map<String, dynamic>> filteredAccounts = [];
    if (title == 'Checking') filteredAccounts = _plaidAccounts.where((account) => account['type'] == 'depository' || (account['subtype'] != null && ['checking', 'savings'].contains(account['subtype'].toString().toLowerCase()))).toList();
    else if (title == 'Card Balance') filteredAccounts = _plaidAccounts.where((account) => account['type'] == 'credit' || (account['subtype'] != null && ['credit', 'credit card'].contains(account['subtype'].toString().toLowerCase()))).toList();
    else if (title == 'Investments') filteredAccounts = _plaidAccounts.where((account) => account['type'] == 'investment' || (account['subtype'] != null && ['investment', '401k', 'ira', 'retirement'].contains(account['subtype'].toString().toLowerCase()))).toList();
    if (filteredAccounts.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('No ${title.toLowerCase()} accounts connected')));
    if (title == 'Card Balance') {
      return Column(
        children: filteredAccounts.map((account) {
          final card = CreditCard(
            name: account['name'] ?? 'Credit Card',
            lastFour: account['mask'] ?? '****',
            balance: (account['balance']['current'] ?? 0).toDouble(),
            creditLimit: (account['balance']['limit'] ?? 1000).toDouble(),
            apr: 19.99,
            bankName: account['institution'] ?? 'Bank',
          );
          return _buildCreditCardItem(card);
        }).toList(),
      );
    } else if (title == 'Investments') {
      return Column(
        children: filteredAccounts.map((account) {
          final balance = (account['balance']['current'] ?? 0).toDouble();
          return _buildInvestmentItem(
            name: account['name'] ?? 'Investment Account',
            subtitle: account['subtype'] != null ? '${account['subtype'].toString().toUpperCase()} - ${account['mask'] ?? '****'}' : 'Investment Account',
            amount: '\$${balance.toStringAsFixed(2)}',
            returnRate: 6.5,
            showGraph: (account['subtype']?.toString().toLowerCase() == '401k'),
          );
        }).toList(),
      );
    } else {
      return Column(
        children: filteredAccounts.map((account) {
          final balance = (account['balance']['available'] ?? account['balance']['current'] ?? 0).toDouble();
          return _buildAccountSubItem(name: account['name'] ?? 'Account', subtitle: '${account['subtype'] ?? 'Checking'} - ${account['mask'] ?? '****'}', amount: '\$${balance.toStringAsFixed(2)}');
        }).toList(),
      );
    }
  }

  // Account sub-item
  Widget _buildAccountSubItem({required String name, required String subtitle, required String amount}) {
    final fixedAmount = amount.fixInterpolation();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          Text(_showBalances ? fixedAmount : '••••••', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Credit card item
  Widget _buildCreditCardItem(CreditCard card) {
    final utilization = card.creditLimit > 0 ? card.balance / card.creditLimit : 0.0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF2B3A55), const Color(0xFF2B3A55).withOpacity(0.8)]),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(card.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
              Image.asset('assets/images/just_logo.png', height: 30, width: 30, color: Colors.white.withOpacity(0.9)),
            ],
          ),
          const SizedBox(height: 8),
          Text('**** **** **** ${card.lastFour}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, letterSpacing: 2)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Current Balance', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 4),
                Text(_showBalances ? '\$${card.balance.toStringAsFixed(2)}' : '••••••', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Available Credit', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 4),
                Text(_showBalances ? '\$${(card.creditLimit - card.balance).toStringAsFixed(2)}' : '••••••', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
          const SizedBox(height: 20),
          Text('Credit Used', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              return Stack(
                children: [
                  Container(height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(3))),
                  Container(height: 6, width: (maxWidth * utilization).clamp(0, maxWidth), decoration: BoxDecoration(color: utilization > 0.7 ? Colors.red[400] : Colors.green[400], borderRadius: BorderRadius.circular(3))),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(utilization * 100).toStringAsFixed(1)}% used'.fixInterpolation(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              Text('Limit: \$${card.creditLimit.toStringAsFixed(0)}'.fixInterpolation(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text('APR: ${card.apr}%', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12))),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text('Due: ${DateFormat('MMM dd').format(DateTime.now().add(const Duration(days: 15)))}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Investment item
  Widget _buildInvestmentItem({required String name, required String subtitle, required String amount, required double returnRate, bool showCDDetails = false, bool showGraph = false}) {
    final currentBalance = double.tryParse(amount.replaceAll('\$', '').replaceAll(',', '')) ?? 0.0;
    final List<FlSpot> growthData = [];
    if (showGraph && currentBalance > 0) {
      final annualReturn = returnRate / 100;
      final monthlyReturn = annualReturn / 12;
      final initialBalance = currentBalance / (1 + annualReturn);
      for (int month = 0; month <= 12; month++) growthData.add(FlSpot(month.toDouble(), initialBalance * (1 + monthlyReturn * month)));
    }
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2B3A55)), overflow: TextOverflow.ellipsis)),
            Text(_showBalances ? amount : '••••••', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.arrow_upward, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  Text('$returnRate% return', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF2B3A55).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(name.contains('401') ? 'Retirement' : 'Fixed Income', style: const TextStyle(fontSize: 12, color: Color(0xFF2B3A55), fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          if (showGraph && growthData.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Growth Over Last 12 Months', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2B3A55))),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 12,
                  minY: growthData.first.y * 0.95,
                  maxY: growthData.last.y * 1.05,
                  lineBarsData: [LineChartBarData(spots: growthData, isCurved: true, color: Colors.green, barWidth: 2, isStrokeCapRound: true, dotData: FlDotData(show: false), belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)))],
                ),
              ),
            ),
          ],
          if (showCDDetails) ...[
            const SizedBox(height: 20),
            const Text('Certificate Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2B3A55))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildInvestmentDetailItem(label: 'Initial Investment', value: '\$10,000.00')),
              Expanded(child: _buildInvestmentDetailItem(label: 'Earnings', value: '+\$435.62', valueColor: Colors.green)),
              Expanded(child: _buildInvestmentDetailItem(label: 'Maturity Date', value: 'Jun 15, 2025')),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 12,
                  minY: 10000,
                  maxY: 10450,
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [FlSpot(0, 10000), FlSpot(1, 10038), FlSpot(2, 10076), FlSpot(3, 10114), FlSpot(4, 10152), FlSpot(5, 10191), FlSpot(6, 10229), FlSpot(7, 10267), FlSpot(8, 10306), FlSpot(9, 10344), FlSpot(10, 10382), FlSpot(11, 10414), FlSpot(12, 10435)],
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF2B3A55).withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF2B3A55).withOpacity(0.1))),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Color(0xFF2B3A55), size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text('Early withdrawal may result in penalties. Consider laddering CDs for better liquidity.', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // Investment detail item
  Widget _buildInvestmentDetailItem({required String label, required String value, Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor ?? Colors.black), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  // Empty account item
  Widget _buildEmptyAccountItem(String title) {
    IconData icon;
    switch (title) {
      case 'Checking': icon = Icons.home_outlined; break;
      case 'Card Balance': icon = Icons.credit_card_outlined; break;
      case 'Net Cash': icon = Icons.attach_money_outlined; break;
      default: icon = Icons.account_balance_outlined;
    }
    return _buildAccountItemCard(title, 'N/A', icon, showPlaceholder: true, expandable: false, latestBalance: AccountBalance(date: DateTime.now(), checking: 0, creditCardBalance: 0, savings: 0, investmentAccount: 0, netWorth: 0));
  }

  // Adds a new account via Plaid
  Future<void> _handleAddAccount() async {
    setState(() => _isLoading = true);
    try {
      final linkToken = await _plaidService.createLinkToken();
      if (linkToken == null) {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create link token'), backgroundColor: Colors.red));
        return;
      }
      LinkTokenConfiguration configuration = LinkTokenConfiguration(token: linkToken);
      await PlaidLink.create(configuration: configuration);
      await PlaidLink.open();
    } catch (e) {
      print('Error opening Plaid Link: $e');
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // Receipt scanner feature with updated colors and transaction addition
  void _showReceiptScanner() {
    if (!_usePlaidData) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Connect to Plaid First', style: TextStyle(color: Color(0xFF2B3A55))),
          content: const Text('To use receipt scanning, please connect your accounts to track transactions automatically', style: TextStyle(color: Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF2B3A55))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleAddAccount();
              },
              child: const Text('Connect Now', style: TextStyle(color: Color(0xFFE5BA73))),
            ),
          ],
        ),
      );
      return;
    }

    // Simulate receipt scanning
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Color(0xFFE5BA73)),
            SizedBox(height: 16),
            Text('Scanning receipt...', style: TextStyle(color: Color(0xFF2B3A55))),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close the progress dialog

      // Simulate adding a transaction
      final mockTransaction = Transaction(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        amount: -25.0, // Example amount
        description: 'Receipt Scan - Groceries',
        category: 'Groceries', account: '', transactionType: '',
      );
      setState(() {
        _transactionsFuture = _transactionsFuture.then((transactions) {
          transactions.add(mockTransaction);
          return transactions;
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt scanned and transaction added!'), backgroundColor: Colors.green));
    });
  }

  // Goals dialog with updated colors
  void _showGoalsDialog() {
    final TextEditingController goalNameController = TextEditingController();
    final TextEditingController goalAmountController = TextEditingController();
    final TextEditingController targetDateController = TextEditingController();
    final List<String> goalTypes = ['Savings', 'Debt Payoff', 'Emergency Fund', 'Vacation', 'Home Purchase', 'Education', 'Retirement', 'Other'];
    String selectedGoalType = goalTypes.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Set Financial Goal', style: TextStyle(color: Color(0xFF2B3A55))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: goalNameController,
                  decoration: const InputDecoration(labelText: 'Goal Name', labelStyle: TextStyle(color: Color(0xFF2B3A55))),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: selectedGoalType,
                  isExpanded: true,
                  hint: const Text('Select Goal Type'),
                  items: goalTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (value) => setState(() => selectedGoalType = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: goalAmountController,
                  decoration: const InputDecoration(labelText: 'Target Amount', prefixText: '\$', labelStyle: TextStyle(color: Color(0xFF2B3A55))),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: targetDateController,
                  decoration: const InputDecoration(labelText: 'Target Date', hintText: 'MM/DD/YYYY', labelStyle: TextStyle(color: Color(0xFF2B3A55))),
                  keyboardType: TextInputType.datetime,
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                    );
                    if (picked != null) targetDateController.text = DateFormat('MM/dd/yyyy').format(picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF2B3A55)))),
            TextButton(
              onPressed: () {
                final name = goalNameController.text;
                final amount = double.tryParse(goalAmountController.text) ?? 0;
                if (name.isNotEmpty && amount > 0) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Goal "$name" created successfully!'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name and valid amount'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Create Goal', style: TextStyle(color: Color(0xFFE5BA73))),
            ),
          ],
        ),
      ),
    );
  }

  // Dashboard customizer with updated colors and functionality
  void _showDashboardCustomizer() {
    final List<String> availableWidgets = _widgetVisibility.keys.toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Customize Dashboard', style: TextStyle(color: Color(0xFF2B3A55))),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select which widgets to show on your dashboard:', style: TextStyle(fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableWidgets.length,
                    itemBuilder: (context, index) {
                      final widgetName = availableWidgets[index];
                      return CheckboxListTile(
                        title: Text(widgetName, style: const TextStyle(color: Color(0xFF2B3A55))),
                        value: _widgetVisibility[widgetName],
                        onChanged: (value) => setState(() => _widgetVisibility[widgetName] = value!),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF2B3A55)))),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dashboard layout updated!'), backgroundColor: Colors.green));
                // Update the UI by triggering a rebuild
                setState(() {});
              },
              child: const Text('Save Layout', style: TextStyle(color: Color(0xFFE5BA73))),
            ),
          ],
        ),
      ),
    );
  }

  // Main build method with conditional widget rendering
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder(
        future: Future.wait([_balancesFuture, _transactionsFuture]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (!_hasLoadedData || _isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE5BA73)));
          }
          if (!snapshot.hasData) return const Center(child: Text('No data available'));

          final balances = snapshot.data![0] as List<AccountBalance>;
          final transactions = snapshot.data![1] as List<Transaction>;
          final latestBalance = balances.last;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildWelcomeBanner()),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_widgetVisibility['Financial Wellness']!) _buildFinancialWellnessScore(),
                    if (_widgetVisibility['Monthly Budget']!) _buildBudgetSummary(),
                    if (_widgetVisibility['Cash Flow']!) _buildCashFlowCard(),
                    if (_widgetVisibility['Spending Trends']!) _buildSpendingTrends(),
                    if (_widgetVisibility['Credit Score']!) _buildCreditScoreCard(),
                    if (_widgetVisibility['Smart Insights']!) _buildInsights(),
                    // Add other widgets conditionally based on _widgetVisibility
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Supporting data classes
class WellnessMetric {
  final String name;
  final double score;
  final String description;
  WellnessMetric({required this.name, required this.score, required this.description});
}

class BudgetCategory {
  final String name;
  double spent;
  final double budget;
  final Color color;
  BudgetCategory({required this.name, required this.spent, required this.budget, required this.color});
}

class FinancialInsight {
  final String title;
  final String description;
  final String action;
  final Color actionColor;
  final IconData icon;
  FinancialInsight({required this.title, required this.description, required this.action, required this.actionColor, required this.icon});
}

class SpendingTrend {
  final String category;
  final double currentSpend;
  final double previousSpend;
  final double trend;
  SpendingTrend({required this.category, required this.currentSpend, required this.previousSpend, required this.trend});
}

class CreditScoreData {
  final DateTime date;
  final int score;
  CreditScoreData(this.date, this.score);
}

// String interpolation fix
extension StringInterpolationFix on String {
  String fixInterpolation() => contains(r'${') && contains('}') ? replaceAllMapped(RegExp(r'\$\{([^}]*)\}'), (match) => match.group(1) ?? '') : this;
}