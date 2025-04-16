import 'dart:math';
import 'dart:ui' as ui;
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final DataService _dataService = DataService();
  final User? _user = FirebaseAuth.instance.currentUser;
  late Future<List<AccountBalance>> _balancesFuture;
  late Future<List<Transaction>> _transactionsFuture;
  int _currentPage = 0;
  static bool _hasLoadedData = false;
  bool _showBalances = true;
  bool _isLoading = false;

  final Map<String, bool> _expandedSections = {
    'Checking': false,
    'Card Balance': false,
    'Net Cash': false,
    'Investments': false,
  };

  // Financial wellness score data
  final double _financialWellnessScore = 78;
  final List<WellnessMetric> _wellnessMetrics = [
    WellnessMetric(
      name: 'Spending',
      score: 65,
      description: 'Your spending is 10% higher than recommended.',
    ),
    WellnessMetric(
      name: 'Savings',
      score: 82,
      description: 'Your saving rate is on track for your goals.',
    ),
    WellnessMetric(
      name: 'Debt',
      score: 75,
      description: 'Credit utilization is within good range.',
    ),
    WellnessMetric(
      name: 'Investments',
      score: 90,
      description: 'Your investment strategy is working well.',
    ),
  ];

  // Budget summary data
  final List<BudgetCategory> _budgetCategories = [
    BudgetCategory(
      name: 'Housing',
      spent: 1500,
      budget: 1600,
      color: Colors.blue,
    ),
    BudgetCategory(
      name: 'Food',
      spent: 720,
      budget: 650,
      color: Colors.red,
    ),
    BudgetCategory(
      name: 'Transportation',
      spent: 320,
      budget: 400,
      color: Colors.green,
    ),
    BudgetCategory(
      name: 'Entertainment',
      spent: 280,
      budget: 300,
      color: Colors.purple,
    ),
    BudgetCategory(
      name: 'Utilities',
      spent: 180,
      budget: 200,
      color: Colors.orange,
    ),
  ];

  // Cash flow data
  final Map<String, double> _monthlyCashFlow = {
    'Income': 5800,
    'Expenses': 4200,
    'Savings': 1600,
  };

  // Insights and recommendations
  final List<FinancialInsight> _insights = [
    FinancialInsight(
      title: 'You\'re spending too much on dining out',
      description: 'Try reducing your restaurant visits by 20% to save an additional \$150 monthly.',
      action: 'View Details',
      actionColor: Colors.amber,
      icon: Icons.restaurant,
    ),
    FinancialInsight(
      title: 'Your emergency fund is below target',
      description: 'You currently have 2 months of expenses saved. Aim for 3-6 months.',
      action: 'Build Emergency Fund',
      actionColor: Colors.red,
      icon: Icons.warning_amber,
    ),
    FinancialInsight(
      title: 'Great job saving this month!',
      description: 'You saved 15% more this month than your average.',
      action: 'View Savings',
      actionColor: Colors.green,
      icon: Icons.savings,
    ),
  ];

  // Spending trend data
  final List<SpendingTrend> _spendingTrends = [
    SpendingTrend(
      category: 'Groceries',
      currentSpend: 450,
      previousSpend: 420,
      trend: 7.1,
    ),
    SpendingTrend(
      category: 'Dining Out',
      currentSpend: 380,
      previousSpend: 320,
      trend: 18.8,
    ),
    SpendingTrend(
      category: 'Shopping',
      currentSpend: 320,
      previousSpend: 350,
      trend: -8.6,
    ),
    SpendingTrend(
      category: 'Entertainment',
      currentSpend: 180,
      previousSpend: 190,
      trend: -5.3,
    ),
  ];

  // Mock credit score history data
  final List<CreditScoreData> _creditScoreHistory = [
    CreditScoreData(DateTime(2023, 10), 723),
    CreditScoreData(DateTime(2023, 11), 728),
    CreditScoreData(DateTime(2023, 12), 732),
    CreditScoreData(DateTime(2024, 1), 735),
    CreditScoreData(DateTime(2024, 2), 738),
    CreditScoreData(DateTime(2024, 3), 741),
    CreditScoreData(DateTime(2024, 4), 745),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (!_hasLoadedData) {
      setState(() {
        _balancesFuture = Future.value([]);
        _transactionsFuture = Future.value([]);
      });
    } else {
      _loadData();
    }
  }

  void _loadData() {
    setState(() {
      _isLoading = true;
    });

    setState(() {
      _balancesFuture = _dataService.getAccountBalances();
      _transactionsFuture = _dataService.getTransactions();
      _hasLoadedData = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _refreshData() {
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildWelcomeBanner() {
    final currentHour = DateTime.now().hour;
    String greeting;

    if (currentHour < 12) {
      greeting = "Good Morning, ${_user?.displayName ?? 'User'}!";
    } else if (currentHour < 17) {
      greeting = "Good Afternoon, ${_user?.displayName ?? 'User'}!";
    } else {
      greeting = "Good Evening, ${_user?.displayName ?? 'User'}!";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B3A55), Color(0xFF3D5377)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          DateFormat('EEEE, MMM d').format(DateTime.now()),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5BA73),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _showBalances ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _showBalances = !_showBalances;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Total Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<AccountBalance>>(
              future: _balancesFuture,
              builder: (context, snapshot) {
                double totalBalance = 0;
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final latestBalance = snapshot.data!.last;
                  totalBalance = latestBalance.checking +
                      latestBalance.creditCardBalance +
                      55435.62; // Adding investments
                }

                return Text(
                  _showBalances
                      ? '\$${NumberFormat('#,##0.00').format(totalBalance)}'
                      : '••••••',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionButton(
                  icon: Icons.add_circle_outline,
                  label: 'Add Money',
                  onTap: () {},
                ),
                _buildQuickActionButton(
                  icon: Icons.money,
                  label: 'Send Money',
                  onTap: () {},
                ),
                _buildQuickActionButton(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Link Account',
                  onTap: _handleAddAccount,
                ),
                _buildQuickActionButton(
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialWellnessScore() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Financial Wellness',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3A55),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getWellnessScoreColor(_financialWellnessScore).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getWellnessScoreColor(_financialWellnessScore).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$_financialWellnessScore',
                        style: TextStyle(
                          color: _getWellnessScoreColor(_financialWellnessScore),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '/100',
                        style: TextStyle(
                          color: _getWellnessScoreColor(_financialWellnessScore).withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                      border: Border.all(
                        color: _getWellnessScoreColor(metric.score).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              metric.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              metric.score.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getWellnessScoreColor(metric.score),
                              ),
                            ),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getWellnessScoreColor(metric.score),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Text(
                            metric.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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

  Color _getWellnessScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.amber;
    return Colors.red;
  }

  Widget _buildBudgetSummary() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Budget',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3A55),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B3A55).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'April 2025',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2B3A55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _budgetCategories.length,
              itemBuilder: (context, index) {
                final category = _budgetCategories[index];
                final progress = category.spent / category.budget;
                final isOverBudget = category.spent > category.budget;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '\$${category.spent.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isOverBudget ? Colors.red : Colors.black87,
                                    fontSize: 15,
                                  ),
                                ),
                                TextSpan(
                                  text: ' / \$${category.budget.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            height: 8,
                            width: MediaQuery.of(context).size.width * 0.9 * min(progress, 1.0),
                            decoration: BoxDecoration(
                              color: isOverBudget ? Colors.red : category.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      if (isOverBudget) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Over budget by \$${(category.spent - category.budget).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            Center(
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: Color(0xFF2B3A55),
                ),
                label: const Text(
                  'Add Budget Category',
                  style: TextStyle(color: Color(0xFF2B3A55)),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowCard() {
    final total = _monthlyCashFlow['Income']!;
    final expenses = _monthlyCashFlow['Expenses']!;
    final savings = _monthlyCashFlow['Savings']!;
    final expensesPercentage = expenses / total * 100;
    final savingsPercentage = savings / total * 100;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Cash Flow',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: expensesPercentage,
                            title: '${expensesPercentage.toStringAsFixed(0)}%',
                            color: Colors.red.shade400,
                            radius: 70,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          PieChartSectionData(
                            value: savingsPercentage,
                            title: '${savingsPercentage.toStringAsFixed(0)}%',
                            color: Colors.green.shade400,
                            radius: 70,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCashFlowLegendItem(
                        label: 'Income',
                        amount: total,
                        color: const Color(0xFF2B3A55),
                      ),
                      const SizedBox(height: 16),
                      _buildCashFlowLegendItem(
                        label: 'Expenses',
                        amount: expenses,
                        color: Colors.red.shade400,
                        percentage: expensesPercentage,
                      ),
                      const SizedBox(height: 16),
                      _buildCashFlowLegendItem(
                        label: 'Savings',
                        amount: savings,
                        color: Colors.green.shade400,
                        percentage: savingsPercentage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You\'re saving ${savingsPercentage.toStringAsFixed(0)}% of your income. Financial experts recommend saving at least 20% of your income.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
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

  Widget _buildCashFlowLegendItem({
    required String label,
    required double amount,
    required Color color,
    double? percentage,
  }) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Text(
                    '\$${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (percentage != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${percentage.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsights() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFFE5BA73),
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Smart Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3A55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _insights.length,
              itemBuilder: (context, index) {
                final insight = _insights[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: insight.actionColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: insight.actionColor.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            insight.icon,
                            color: insight.actionColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              insight.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        insight.description,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: insight.actionColor,
                            side: BorderSide(color: insight.actionColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: Text(insight.action),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingTrends() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending Trends',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _spendingTrends.length,
              itemBuilder: (context, index) {
                final trend = _spendingTrends[index];
                final isIncreasing = trend.trend > 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(trend.category).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            _getCategoryIcon(trend.category),
                            color: _getCategoryColor(trend.category),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trend.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                children: [
                                  TextSpan(
                                    text: '\$${trend.currentSpend.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' this month',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isIncreasing
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isIncreasing
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isIncreasing ? Colors.red : Colors.green,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${trend.trend.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: isIncreasing ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
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
                onPressed: () {},
                child: const Text(
                  'View All Categories',
                  style: TextStyle(
                    color: Color(0xFF2B3A55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Groceries':
        return Colors.green;
      case 'Dining Out':
        return Colors.orange;
      case 'Shopping':
        return Colors.purple;
      case 'Entertainment':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Groceries':
        return Icons.shopping_basket;
      case 'Dining Out':
        return Icons.restaurant;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Entertainment':
        return Icons.movie;
      default:
        return Icons.category;
    }
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo_cropped.png',
          height: 120,
          width: 120,
        ),
        const SizedBox(height: 20),
        const Text(
          'It seems like you have no accounts connected!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2B3A55),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Connect an account now to get started.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _handleAddAccount,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Connect Account'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE5BA73),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreditScoreCard() {
    final latestScore = _creditScoreHistory.last.score;
    final prevScore = _creditScoreHistory[_creditScoreHistory.length - 2].score;
    final difference = latestScore - prevScore;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Credit Score',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3A55),
                  ),
                ),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2B3A55),
                    side: const BorderSide(color: Color(0xFF2B3A55)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: const Text('Check for Free'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  latestScore.toString(),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3A55),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: difference >= 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        difference >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: difference >= 0 ? Colors.green : Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${difference.abs()} points',
                        style: TextStyle(
                          color: difference >= 0 ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildCreditScoreLabel(latestScore),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Poor',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Fair',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Good',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Very Good',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Excellent',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.orange,
                        Colors.yellow,
                        Colors.lightGreen,
                        Colors.green,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: (latestScore - 300) / 550 * MediaQuery.of(context).size.width * 0.8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2B3A55),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '300',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '850',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _creditScoreHistory.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MMM').format(_creditScoreHistory[value.toInt()].date),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                ),
                              ),
                            );
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
                      spots: _creditScoreHistory
                          .asMap()
                          .entries
                          .map((entry) => FlSpot(entry.key.toDouble(), entry.value.score.toDouble()))
                          .toList(),
                      isCurved: true,
                      color: const Color(0xFF2B3A55),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFF2B3A55),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF2B3A55).withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditScoreLabel(int score) {
    String label;
    Color color;

    if (score >= 800) {
      label = 'Excellent';
      color = Colors.green;
    } else if (score >= 740) {
      label = 'Very Good';
      color = Colors.lightGreen;
    } else if (score >= 670) {
      label = 'Good';
      color = Colors.yellow.shade700;
    } else if (score >= 580) {
      label = 'Fair';
      color = Colors.orange;
    } else {
      label = 'Poor';
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildAccountItemCard(
    String title,
    String amount,
    IconData icon, {
    Color? amountColor,
    bool expandable = true,
    bool showPlaceholder = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: expandable
                  ? () {
                      setState(() {
                        _expandedSections[title] = !_expandedSections[title]!;
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B3A55).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF2B3A55),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          showPlaceholder
                              ? Container(
                                  width: 80,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                )
                              : Text(
                                  _showBalances ? amount : '••••••',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: amountColor,
                                  ),
                                ),
                        ],
                      ),
                    ),
                    if (expandable)
                      Icon(
                        _expandedSections[title]!
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                  ],
                ),
              ),
            ),
            if (expandable && _expandedSections[title]!)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: _buildExpandedSection(title),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSection(String title) {
    switch (title) {
      case 'Checking':
        return FutureBuilder<List<CheckingAccount>>(
          future: _dataService.getCheckingAccounts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: Color(0xFFE5BA73),
                  ),
                ),
              );
            }
            return Column(
              children: snapshot.data!
                  .map((account) => _buildAccountSubItem(
                        name: account.name,
                        subtitle: '${account.bankName} - ${account.type}',
                        amount: '\$${account.balance.toStringAsFixed(2)}',
                      ))
                  .toList(),
            );
          },
        );

      case 'Card Balance':
        return FutureBuilder<List<CreditCard>>(
          future: _dataService.getCreditCards(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: Color(0xFFE5BA73),
                  ),
                ),
              );
            }
            return Column(
              children: snapshot.data!.map((card) => _buildCreditCardItem(card)).toList(),
            );
          },
        );

      case 'Investments':
        return Column(
          children: [
            _buildInvestmentItem(
              name: '401(k) Account',
              subtitle: 'Plaid Target Retirement 2055',
              amount: '\$45,000.00',
              returnRate: 8.5,
            ),
            _buildInvestmentItem(
              name: 'Certificate of Deposit',
              subtitle: '1-Year CD @ 4.5% APY',
              amount: '\$10,435.62',
              returnRate: 4.5,
              showCDDetails: true,
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildAccountSubItem({
    required String name,
    required String subtitle,
    required String amount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _showBalances ? amount : '••••••',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardItem(CreditCard card) {
    final utilization = card.balance / card.creditLimit;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2B3A55),
            const Color(0xFF2B3A55).withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Image.asset(
                'assets/images/just_logo.png',
                height: 30,
                width: 30,
                color: Colors.white.withOpacity(0.9),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '**** **** **** ${card.lastFour}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Balance',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _showBalances ? '\$${card.balance.toStringAsFixed(2)}' : '••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Available Credit',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _showBalances
                        ? '\$${(card.creditLimit - card.balance).toStringAsFixed(2)}'
                        : '••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Credit Used',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                height: 6,
                width: MediaQuery.of(context).size.width * 0.7 * utilization,
                decoration: BoxDecoration(
                  color: utilization > 0.7 ? Colors.red[400] : Colors.green[400],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(utilization * 100).toStringAsFixed(1)}% used',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                'Limit: \$${card.creditLimit.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'APR: ${card.apr}%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Due: ${DateFormat('MMM dd').format(DateTime.now().add(const Duration(days: 15)))}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentItem({
    required String name,
    required String subtitle,
    required String amount,
    required double returnRate,
    bool showCDDetails = false,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2B3A55),
                ),
              ),
              Text(
                _showBalances ? amount : '••••••',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      color: Colors.green,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$returnRate% return',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3A55).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  name == '401(k) Account' ? 'Retirement' : 'Fixed Income',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2B3A55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (showCDDetails) ...[
            const SizedBox(height: 20),
            const Text(
              'Certificate Details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInvestmentDetailItem(
                  label: 'Initial Investment',
                  value: '\$10,000.00',
                ),
                _buildInvestmentDetailItem(
                  label: 'Earnings',
                  value: '+\$435.62',
                  valueColor: Colors.green,
                ),
                _buildInvestmentDetailItem(
                  label: 'Maturity Date',
                  value: 'Jun 15, 2025',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2B3A55).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF2B3A55).withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF2B3A55),
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Early withdrawal may result in penalties. Consider laddering CDs for better liquidity.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvestmentDetailItem({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyAccountItem(String title) {
    IconData icon;
    switch (title) {
      case 'Checking':
        icon = Icons.home_outlined;
        break;
      case 'Card Balance':
        icon = Icons.credit_card_outlined;
        break;
      case 'Net Cash':
        icon = Icons.attach_money_outlined;
        break;
      default:
        icon = Icons.account_balance_outlined;
    }

    return _buildAccountItemCard(
      title,
      'N/A',
      icon,
      showPlaceholder: true,
      expandable: false,
    );
  }

  Future<void> _handleAddAccount() async {
    final linkToken = await PlaidIntegrationService.createLinkToken();

    if (linkToken != null) {
      print('Link Token: $linkToken');

      LinkTokenConfiguration configuration = LinkTokenConfiguration(
        token: linkToken,
      );

      PlaidLink.create(configuration: configuration);

      PlaidLink.open();

      final publicToken = linkToken;

      final accessToken = await PlaidIntegrationService.exchangePublicToken(publicToken);

      if (accessToken != null) {
        print('Access Token: $accessToken');

        await PlaidIntegrationService.fetchTransactions(accessToken);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder(
      future: Future.wait([_balancesFuture, _transactionsFuture]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!_hasLoadedData) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                _buildWelcomeBanner(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE5BA73),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              const Text(
                                'ACCOUNTS',
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildEmptyAccountItem('Checking'),
                              _buildEmptyAccountItem('Card Balance'),
                              _buildEmptyAccountItem('Net Cash'),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'ACTIONS',
                                    style: TextStyle(
                                      fontSize: 13,
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.refresh, color: Color(0xFF2B3A55)),
                                        onPressed: _loadData,
                                      ),
                                      TextButton(
                                        onPressed: _handleAddAccount,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          foregroundColor: const Color(0xFF2B3A55),
                                        ),
                                        child: const Text(
                                          'Add Account',
                                          style: TextStyle(
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 80),
                              _buildEmptyState(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        }

        if (_isLoading) {
          return Scaffold(
            body: Column(
              children: [
                _buildWelcomeBanner(),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE5BA73),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final balances = snapshot.data![0] as List<AccountBalance>;
        final transactions = snapshot.data![1] as List<Transaction>;

        if (balances.isEmpty) {
          return Scaffold(
            body: Column(
              children: [
                _buildWelcomeBanner(),
                Expanded(
                  child: Center(
                    child: Text(
                      'No account data available',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final latestBalance = balances.last;

        return Scaffold(
          backgroundColor: Colors.white,
          body: RefreshIndicator(
            color: const Color(0xFFE5BA73),
            onRefresh: () async {
              _refreshData();
              await Future.delayed(const Duration(milliseconds: 1500));
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildWelcomeBanner(),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildFinancialWellnessScore(),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ACCOUNTS',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Color(0xFF2B3A55)),
                                onPressed: _refreshData,
                              ),
                              TextButton(
                                onPressed: _handleAddAccount,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: const Color(0xFF2B3A55),
                                ),
                                child: const Text(
                                  'Add Account',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildAccountItemCard(
                        'Checking',
                        '\$${latestBalance.checking.toStringAsFixed(2)}',
                        Icons.account_balance_outlined,
                      ),
                      _buildAccountItemCard(
                        'Card Balance',
                        '-\$${latestBalance.creditCardBalance.abs().toStringAsFixed(2)}',
                        Icons.credit_card_outlined,
                        amountColor: Colors.red,
                      ),
                      _buildAccountItemCard(
                        'Net Cash',
                        '\$${(latestBalance.checking + latestBalance.creditCardBalance).toStringAsFixed(2)}',
                        Icons.attach_money_outlined,
                        amountColor: Colors.green,
                        expandable: false,
                      ),
                      _buildAccountItemCard(
                        'Investments',
                        '\$${55435.62.toStringAsFixed(2)}',
                        Icons.show_chart_outlined,
                      ),
                      const SizedBox(height: 24),
                      _buildCreditScoreCard(),
                      const SizedBox(height: 24),
                      _buildBudgetSummary(),
                      const SizedBox(height: 24),
                      _buildCashFlowCard(),
                      const SizedBox(height: 24),
                      _buildSpendingTrends(),
                      const SizedBox(height: 24),
                      _buildInsights(),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            backgroundColor: const Color(0xFFE5BA73),
            child: const Icon(Icons.insights, color: Colors.white),
          ),
        );
      },
    );
  }
}

class WellnessMetric {
  final String name;
  final double score;
  final String description;

  WellnessMetric({
    required this.name,
    required this.score,
    required this.description,
  });
}

class BudgetCategory {
  final String name;
  final double spent;
  final double budget;
  final Color color;

  BudgetCategory({
    required this.name,
    required this.spent,
    required this.budget,
    required this.color,
  });
}

class FinancialInsight {
  final String title;
  final String description;
  final String action;
  final Color actionColor;
  final IconData icon;

  FinancialInsight({
    required this.title,
    required this.description,
    required this.action,
    required this.actionColor,
    required this.icon,
  });
}

class SpendingTrend {
  final String category;
  final double currentSpend;
  final double previousSpend;
  final double trend;

  SpendingTrend({
    required this.category,
    required this.currentSpend,
    required this.previousSpend,
    required this.trend,
  });
}

class CreditScoreData {
  final DateTime date;
  final int score;

  CreditScoreData(this.date, this.score);
}