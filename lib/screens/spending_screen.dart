// This screen displays spending and income data with visualizations like bar and pie charts.
import 'package:finsight/exports/spending_export.dart';
import 'package:finsight/models/monthly_spending.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/screens/sankey_graph.dart';
import 'package:finsight/services/data_service.dart';
import 'package:finsight/services/plaid_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// Main widget for the Spending screen, showing monthly financial data.
class SpendingScreen extends StatefulWidget {
  const SpendingScreen({Key? key}) : super(key: key);

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

// State class managing data loading, UI updates, and user interactions.
class _SpendingScreenState extends State<SpendingScreen> {
  // Toggle to include bills in the spending breakdown.
  bool includeBills = true;
  // List of monthly spending data.
  List<MonthlySpending> monthlySpending = [];
  // Flag to show loading state.
  bool isLoading = true;
  // Index of the currently selected month.
  int selectedMonthIndex = 0;
  // Starting index for the display window of months in the bar chart.
  int displayStartIndex = 0;
  // Flag to indicate if Plaid data is being used instead of static data.
  bool _usingPlaidData = false;
  // Service for fetching Plaid transactions.
  final PlaidService _plaidService = PlaidService();
  // Service for handling static data.
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    // Load static data when the screen initializes.
    loadStaticData();
  }

  // Navigate to the Sankey diagram screen for the selected month.
  void _showSankeyDiagram() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SankeyDiagramScreen(
          monthlySpending: monthlySpending[selectedMonthIndex],
        ),
      ),
    );
  }

  // Load static spending data from the DataService.
  Future<void> loadStaticData() async {
    setState(() {
      isLoading = true;
      _usingPlaidData = false;
    });

    final spendingService = DataService();
    final spending = await spendingService.getMonthlySpending();
    
    // Update state only if the widget is still mounted.
    if (mounted) {
      setState(() {
        monthlySpending = spending;
        selectedMonthIndex = spending.length - 1;
        displayStartIndex = (spending.length > 9) ? spending.length - 9 : 0;
        isLoading = false;
      });
    }
  }

  // Load transaction data from Plaid, falling back to static data if necessary.
  Future<void> loadPlaidData() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      _usingPlaidData = true;
    });

    try {
      // Check if there's an active Plaid connection.
      final hasConnection = await _plaidService.hasPlaidConnection();
      if (!hasConnection) {
        await loadStaticData();
        return;
      }

      // Fetch transactions for the past year.
      final now = DateTime.now();
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
      
      final transactions = await _plaidService.fetchTransactions(
        context: context,
        startDate: oneYearAgo,
        endDate: now,
      );

      // Convert transactions into monthly spending data.
      final processedData = processTransactions(transactions);
      
      if (mounted) {
        setState(() {
          monthlySpending = processedData;
          selectedMonthIndex = processedData.length - 1;
          displayStartIndex = (processedData.length > 9) ? processedData.length - 9 : 0;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading Plaid data: $e');
      // Fall back to static data if Plaid fails.
      await loadStaticData();
    }
  }

  // Process raw transactions into monthly spending data by category.
  List<MonthlySpending> processTransactions(List<Transaction> transactions) {
    // Group transactions by month (YYYY-MM format).
    final Map<String, List<Transaction>> transactionsByMonth = {};
    
    for (final transaction in transactions) {
      final monthKey = DateFormat('yyyy-MM').format(transaction.date);
      if (!transactionsByMonth.containsKey(monthKey)) {
        transactionsByMonth[monthKey] = [];
      }
      transactionsByMonth[monthKey]!.add(transaction);
    }

    // Create MonthlySpending objects for each month.
    final List<MonthlySpending> result = [];
    
    transactionsByMonth.forEach((key, txList) {
      final date = DateFormat('yyyy-MM').parse(key);
      
      // Track spending by category and total income/expenses.
      final Map<String, double> categoryBreakdown = {};
      double totalExpenses = 0;
      double totalIncome = 0;
      
      for (final tx in txList) {
        if (tx.transactionType.toLowerCase() == 'expense' || 
            tx.amount > 0) { // Positive amounts are treated as expenses.
          if (!categoryBreakdown.containsKey(tx.category)) {
            categoryBreakdown[tx.category] = 0;
          }
          categoryBreakdown[tx.category] = categoryBreakdown[tx.category]! + tx.amount;
          totalExpenses += tx.amount;
        } else {
          totalIncome += tx.amount.abs();
        }
      }

      // Create a MonthlySpending object with categorized data.
      final monthlySpend = MonthlySpending(
        date: date,
        groceries: categoryBreakdown['Groceries'] ?? 0,
        utilities: categoryBreakdown['Utilities'] ?? 0,
        rent: categoryBreakdown['Rent'] ?? 0,
        transportation: categoryBreakdown['Transportation'] ?? 0,
        entertainment: categoryBreakdown['Entertainment'] ?? 0,
        diningOut: categoryBreakdown['Dining Out'] ?? 0,
        shopping: categoryBreakdown['Shopping'] ?? 0,
        healthcare: categoryBreakdown['Healthcare'] ?? 0,
        insurance: categoryBreakdown['Insurance'] ?? 0,
        miscellaneous: categoryBreakdown['Miscellaneous'] ?? 0,
        earnings: totalIncome,
      );
      
      result.add(monthlySpend);
    });

    // Sort months chronologically.
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  // Adjust the display window for the bar chart to keep the selected month in view.
  void _updateDisplayWindow() {
    if (monthlySpending.length <= 9) {
      displayStartIndex = 0;
      return;
    }

    if (selectedMonthIndex < displayStartIndex) {
      displayStartIndex = selectedMonthIndex;
    } else if (selectedMonthIndex >= displayStartIndex + 9) {
      displayStartIndex = selectedMonthIndex - 8;
    }
  }

  // Toggle between Plaid and static data on refresh.
  Future<void> _handleRefresh() async {
    if (_usingPlaidData) {
      await loadStaticData();
    } else {
      await loadPlaidData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while data is being fetched.
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Display a message if no spending data is available.
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
                    const Text(
                      'Spending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
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
                    child: const Center(
                      child: Text('No spending data available.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Get data for the currently selected month.
    final currentMonth = monthlySpending[selectedMonthIndex];
    final breakdown = currentMonth.categoryBreakdown;
    final totalSpend = currentMonth.totalSpent;

    // Main UI with bar chart, pie chart, and category breakdown.
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
                  const Text(
                    'Spending',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      // Button to view the Sankey diagram.
                      IconButton(
                        icon: const Icon(Icons.waterfall_chart,
                            color: Colors.white),
                        tooltip: 'Money Flow',
                        onPressed: () => _showSankeyDiagram(),
                      ),
                      // Button to export a spending report.
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: () async {
                          try {
                            await SpendingReportGenerator.generateReport(
                                monthlySpending, context);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Report generated successfully')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Error generating report: ${e.toString()}')),
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
            // Month selector with navigation buttons.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.white, size: 20),
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
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: selectedMonthIndex > 0
                          ? () => setState(() {
                                selectedMonthIndex--;
                                _updateDisplayWindow();
                              })
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: selectedMonthIndex < monthlySpending.length - 1
                          ? () => setState(() {
                                selectedMonthIndex++;
                                _updateDisplayWindow();
                              })
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
                      // Bar chart showing spending and income over months.
                      Container(
                        height: 200, // Increased height to accommodate legend
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Legend for the bar chart.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLegendItem(
                                    'Spending', const Color(0xFF2B3A55)),
                                const SizedBox(width: 24),
                                _buildLegendItem(
                                    'Income', const Color(0xFFE5BA73)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: monthlySpending
                                          .map((s) => s.income ?? 0)
                                          .reduce((a, b) => a > b ? a : b) *
                                      1.2,
                                  barTouchData: BarTouchData(
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipItem:
                                          (group, groupIndex, rod, rodIndex) {
                                        String label =
                                            rod.color == const Color(0xFF2B3A55)
                                                ? 'Spent'
                                                : 'Earned';
                                        double value =
                                            monthlySpending[group.x.toInt()]
                                                .totalSpent;
                                        if (rod.color ==
                                            const Color(0xFFE5BA73)) {
                                          value = monthlySpending[group.x.toInt()]
                                                  .income ??
                                              0;
                                        }
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
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            '\$${(value / 1000).toStringAsFixed(1)}k',
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
                                          final actualIndex =
                                              value.toInt() + displayStartIndex;
                                          if (actualIndex >=
                                              monthlySpending.length) {
                                            return const SizedBox.shrink();
                                          }
                                          return Text(
                                            DateFormat('MMM').format(
                                                monthlySpending[actualIndex]
                                                    .date),
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
                                    horizontalInterval: 1000,
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
                                          entry.key < displayStartIndex + 9 &&
                                          entry.key < monthlySpending.length)
                                      .map((entry) {
                                    final double width = 8;
                                    final double gap = 4;
                                    return BarChartGroupData(
                                      x: entry.key - displayStartIndex,
                                      groupVertically: false,
                                      barRods: [
                                        BarChartRodData(
                                          toY: entry.value.totalSpent,
                                          color: entry.key == selectedMonthIndex
                                              ? const Color(0xFF2B3A55)
                                              : const Color(0xFF2B3A55)
                                                  .withOpacity(0.3),
                                          width: width,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        BarChartRodData(
                                          toY: entry.value.income ?? 0,
                                          color: entry.key == selectedMonthIndex
                                              ? const Color(0xFFE5BA73)
                                              : const Color(0xFFE5BA73)
                                                  .withOpacity(0.3),
                                          width: width,
                                          borderRadius: BorderRadius.circular(2),
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
                      // Category breakdown with a pie chart and list.
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'BREAKDOWN',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 240,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Pie chart showing spending by category.
                                  PieChart(
                                    PieChartData(
                                      sections: breakdown.entries
                                          .map((e) => PieChartSectionData(
                                                value: e.value,
                                                color: _getCategoryColor(e.key),
                                                radius: 20,
                                                showTitle: false,
                                              ))
                                          .toList(),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 100,
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
                                        NumberFormat.currency(symbol: '\$')
                                            .format(totalSpend),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2B3A55),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // List of categories with amounts and percentages.
                            ...breakdown.entries
                                .where((e) => !includeBills
                                    ? !['Utilities', 'Rent', 'Insurance']
                                        .contains(e.key)
                                    : true)
                                .map(
                                  (entry) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(entry.key)
                                            .withOpacity(0.1),
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
                                      NumberFormat.currency(symbol: '\$')
                                          .format(entry.value),
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

  // Builds a legend item for the bar chart.
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

  // Returns a color for each spending category.
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

  // Returns an icon for each spending category.
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
      'Miscellaneous': Icons.more_horiz,
    };
    return icons[category] ?? Icons.category;
  }
}