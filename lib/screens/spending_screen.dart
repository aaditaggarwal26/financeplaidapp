import 'package:finsight/exports/spending_export.dart';
import 'package:finsight/models/monthly_spending.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/screens/sankey_graph.dart';
import 'package:finsight/services/data_service.dart';
import 'package:finsight/services/plaid_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class SpendingScreen extends StatefulWidget {
  const SpendingScreen({Key? key}) : super(key: key);

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  bool includeBills = true;
  List<MonthlySpending> monthlySpending = [];
  List<Transaction> allTransactions = [];
  bool isLoading = true;
  int selectedMonthIndex = 0;
  int displayStartIndex = 0;
  bool _usePlaidData = false;
  final PlaidService _plaidService = PlaidService();
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    print('=== SpendingScreen: _initializeData called ===');
    
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      // Check for Plaid connection
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      print('SpendingScreen: Plaid connection status: $hasPlaidConnection');
      
      if (hasPlaidConnection) {
        setState(() {
          _usePlaidData = true;
        });
      }

      // Load data using DataService with proper context
      await _loadData();
      
    } catch (e) {
      print('SpendingScreen: Error initializing data: $e');
      // Try to load static data as fallback
      await _loadStaticData();
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    print('=== SpendingScreen: _loadData called ===');
    
    if (!mounted) return;
    
    try {
      // Force refresh to get latest data
      final transactions = await _dataService.getTransactions(
        context: context,
        forceRefresh: true,
      );
      
      final spending = await _dataService.getMonthlySpending(
        context: context,
        forceRefresh: true,
      );

      print('SpendingScreen: Loaded ${transactions.length} transactions, ${spending.length} months of spending');

      if (!mounted) return;

      setState(() {
        allTransactions = transactions;
        monthlySpending = spending;
        
        if (monthlySpending.isNotEmpty) {
          selectedMonthIndex = monthlySpending.length - 1;
          displayStartIndex = (monthlySpending.length > 6) ? monthlySpending.length - 6 : 0;
        }
      });
    } catch (e) {
      print('SpendingScreen: Error loading data: $e');
      rethrow;
    }
  }

  Future<void> _loadStaticData() async {
    print('=== SpendingScreen: _loadStaticData called ===');
    
    if (!mounted) return;
    
    try {
      // Load without context to get static/demo data
      final transactions = await _dataService.getTransactions();
      final spending = await _dataService.getMonthlySpending();
      
      if (!mounted) return;
      
      setState(() {
        allTransactions = transactions;
        monthlySpending = spending;
        _usePlaidData = false;
        
        if (monthlySpending.isNotEmpty) {
          selectedMonthIndex = monthlySpending.length - 1;
          displayStartIndex = (monthlySpending.length > 6) ? monthlySpending.length - 6 : 0;
        }
      });
    } catch (e) {
      print('SpendingScreen: Error loading static data: $e');
      if (mounted) {
        setState(() {
          monthlySpending = [];
          allTransactions = [];
          _usePlaidData = false;
        });
      }
    }
  }

  void _updateDisplayWindow() {
    if (monthlySpending.length <= 6) {
      displayStartIndex = 0;
      return;
    }

    if (selectedMonthIndex < displayStartIndex) {
      displayStartIndex = selectedMonthIndex;
    } else if (selectedMonthIndex >= displayStartIndex + 6) {
      displayStartIndex = selectedMonthIndex - 5;
    }
  }

  Future<void> _handleRefresh() async {
    print('=== SpendingScreen: _handleRefresh called ===');
    if (!mounted) return;
    
    // Clear cache to force fresh data
    DataService.clearCache();
    await _initializeData();
  }

  void _showSankeyDiagram() {
    if (monthlySpending.isNotEmpty && selectedMonthIndex < monthlySpending.length) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SankeyDiagramScreen(
            monthlySpending: monthlySpending[selectedMonthIndex],
          ),
        ),
      );
    }
  }

  Future<void> _handleConnectAccount() async {
    try {
      final linkToken = await _plaidService.createLinkToken();
      if (linkToken != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please use the dashboard to connect your account'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF2B3A55),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE5BA73)),
        ),
      );
    }

    // Check if we have no spending data
    if (monthlySpending.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF2B3A55),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Spending',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_usePlaidData) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _handleRefresh,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _usePlaidData ? Icons.receipt_long_outlined : Icons.account_balance_wallet_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _usePlaidData ? 'No Spending Data Available' : 'No Bank Account Connected',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B3A55),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _usePlaidData 
                                ? 'Make some transactions to see your spending analysis'
                                : 'Connect your bank account to see\nreal spending data and insights',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          if (!_usePlaidData) ...[
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: _handleConnectAccount,
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentMonth = monthlySpending[selectedMonthIndex];
    final breakdown = _getEnhancedCategoryBreakdown(currentMonth);
    final totalSpend = breakdown.values.fold(0.0, (sum, value) => sum + value);
    
    // Calculate max Y for chart based on data
    final maxIncomeOrSpend = monthlySpending
        .map((s) => [s.totalSpent, s.income ?? 0])
        .expand((x) => x)
        .fold(0.0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: const Color(0xFF2B3A55),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Spending',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_usePlaidData) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.waterfall_chart, color: Colors.white),
                        tooltip: 'Money Flow',
                        onPressed: _showSankeyDiagram,
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: () async {
                          try {
                            await SpendingReportGenerator.generateReport(
                                monthlySpending, context);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Report generated successfully')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Error generating report: ${e.toString()}')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMMM yyyy').format(currentMonth.date),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: selectedMonthIndex > 0
                          ? () {
                              if (mounted) {
                                setState(() {
                                  selectedMonthIndex--;
                                  _updateDisplayWindow();
                                });
                              }
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: selectedMonthIndex < monthlySpending.length - 1
                          ? () {
                              if (mounted) {
                                setState(() {
                                  selectedMonthIndex++;
                                  _updateDisplayWindow();
                                });
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Spending and Income Chart - Fixed size and layout
                      Container(
                        height: 280,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLegendItem('Spending', const Color(0xFF2B3A55)),
                                const SizedBox(width: 24),
                                _buildLegendItem('Income', const Color(0xFFE5BA73)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: maxIncomeOrSpend * 1.2,
                                  barTouchData: BarTouchData(
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        final monthData = monthlySpending[group.x.toInt() + displayStartIndex];
                                        String label = rod.color == const Color(0xFF2B3A55) ? 'Spent' : 'Earned';
                                        double value = rod.color == const Color(0xFF2B3A55) 
                                            ? monthData.totalSpent 
                                            : monthData.income ?? 0;
                                        return BarTooltipItem(
                                          '$label:\n${NumberFormat.currency(symbol: '\$').format(value)}',
                                          const TextStyle(color: Colors.black),
                                        );
                                      },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 50,
                                        getTitlesWidget: (value, meta) {
                                          if (value == 0) return const Text('');
                                          return Text(
                                            '\$${(value / 1000).toStringAsFixed(0)}k',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final actualIndex = value.toInt() + displayStartIndex;
                                          if (actualIndex >= monthlySpending.length) {
                                            return const SizedBox.shrink();
                                          }
                                          return Text(
                                            DateFormat('MMM').format(monthlySpending[actualIndex].date),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(),
                                    topTitles: const AxisTitles(),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: maxIncomeOrSpend / 5,
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color: Colors.grey.withOpacity(0.2),
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  barGroups: monthlySpending
                                      .asMap()
                                      .entries
                                      .where((entry) =>
                                          entry.key >= displayStartIndex &&
                                          entry.key < displayStartIndex + 6 &&
                                          entry.key < monthlySpending.length)
                                      .map((entry) {
                                    final double width = 12;
                                    final double gap = 6;
                                    return BarChartGroupData(
                                      x: entry.key - displayStartIndex,
                                      groupVertically: false,
                                      barRods: [
                                        BarChartRodData(
                                          toY: entry.value.totalSpent,
                                          color: entry.key == selectedMonthIndex
                                              ? const Color(0xFF2B3A55)
                                              : const Color(0xFF2B3A55).withOpacity(0.3),
                                          width: width,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        BarChartRodData(
                                          toY: entry.value.income ?? 0,
                                          color: entry.key == selectedMonthIndex
                                              ? const Color(0xFFE5BA73)
                                              : const Color(0xFFE5BA73).withOpacity(0.3),
                                          width: width,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ],
                                      barsSpace: gap,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Category Breakdown
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'BREAKDOWN',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  'Total: ${NumberFormat.currency(symbol: '\$').format(totalSpend)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B3A55),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 240,
                              child: totalSpend > 0 ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      sections: breakdown.entries
                                          .where((e) => e.value > 0)
                                          .map((e) => PieChartSectionData(
                                                value: e.value,
                                                color: _getCategoryColor(e.key),
                                                radius: 25,
                                                showTitle: false,
                                              ))
                                          .toList(),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 80,
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Total spend',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        NumberFormat.currency(symbol: '\$').format(totalSpend),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2B3A55),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ) : const Center(
                                child: Text(
                                  'No spending data for this month',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            // Category List
                            ...breakdown.entries
                                .where((e) => e.value > 0)
                                .where((e) => !includeBills
                                    ? !['Utilities', 'Rent', 'Insurance'].contains(e.key)
                                    : true)
                                .map(
                                  (entry) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(entry.key).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getCategoryIcon(entry.key),
                                        color: _getCategoryColor(entry.key),
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${(entry.value / totalSpend * 100).toStringAsFixed(0)}% of spend',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: Text(
                                      NumberFormat.currency(symbol: '\$').format(entry.value),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2B3A55),
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
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

  Map<String, double> _getEnhancedCategoryBreakdown(MonthlySpending monthlySpending) {
    final breakdown = Map<String, double>.from(monthlySpending.categoryBreakdown);
    
    // If we have Plaid data, include subscriptions separately
    if (_usePlaidData) {
      // Calculate subscriptions from recent transactions for this month
      final monthTransactions = allTransactions.where((t) {
        return t.date.year == monthlySpending.date.year &&
               t.date.month == monthlySpending.date.month &&
               t.category == 'Subscriptions';
      }).toList();
      
      final subscriptionsTotal = monthTransactions.fold(0.0, (sum, t) => sum + t.amount);
      if (subscriptionsTotal > 0) {
        breakdown['Subscriptions'] = subscriptionsTotal;
        // Remove subscriptions from miscellaneous
        breakdown['Miscellaneous'] = (breakdown['Miscellaneous'] ?? 0) - subscriptionsTotal;
        if (breakdown['Miscellaneous']! < 0) breakdown['Miscellaneous'] = 0;
      }
    }
    
    return breakdown;
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
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
      'Miscellaneous': const Color(0xFF95A5A6),
    };
    return colors[category] ?? Colors.grey;
  }

  IconData _getCategoryIcon(String category) {
    final icons = {
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
      'Miscellaneous': Icons.more_horiz,
    };
    return icons[category] ?? Icons.category;
  }
}