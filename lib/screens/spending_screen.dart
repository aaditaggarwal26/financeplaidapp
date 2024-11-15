import 'package:finsight/exports/spending_export.dart';
import 'package:finsight/models/monthly_spending.dart';
import 'package:finsight/services/data_service.dart';
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
  bool isLoading = true;
  int selectedMonthIndex = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final spendingService = DataService();
    final spending = await spendingService.getMonthlySpending();
    setState(() {
      monthlySpending = spending;
      selectedMonthIndex = spending.length - 1;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentMonth = monthlySpending[selectedMonthIndex];
    final breakdown = currentMonth.categoryBreakdown;
    final totalSpend = currentMonth.totalSpent;

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
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: () async {
                      try {
                        await SpendingReportGenerator.generateReport(
                            monthlySpending, context);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Report generated successfully')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
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
            ),
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
                          ? () => setState(() => selectedMonthIndex--)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: selectedMonthIndex < monthlySpending.length - 1
                          ? () => setState(() => selectedMonthIndex++)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      height: 200, // Increased height to accommodate legend
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Legend
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
                                        if (value.toInt() >=
                                            monthlySpending.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return Text(
                                          DateFormat('MMM').format(
                                              monthlySpending[value.toInt()]
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
                                    .map((entry) {
                                  final double width = 8;
                                  final double gap = 4;
                                  return BarChartGroupData(
                                    x: entry.key,
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
          ],
        ),
      ),
    );
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
      'Miscellaneous': Icons.more_horiz,
    };
    return icons[category] ?? Icons.category;
  }
}
