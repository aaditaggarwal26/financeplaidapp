import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:finsight/services/smart_cashflow_predictor_service.dart';

class SmartCashFlowPredictorScreen extends StatefulWidget {
  const SmartCashFlowPredictorScreen({Key? key}) : super(key: key);

  @override
  State<SmartCashFlowPredictorScreen> createState() => _SmartCashFlowPredictorScreenState();
}

class _SmartCashFlowPredictorScreenState extends State<SmartCashFlowPredictorScreen>
    with SingleTickerProviderStateMixin {
  final SmartCashFlowPredictorService _predictorService = SmartCashFlowPredictorService();
  
  late TabController _tabController;
  CashFlowPrediction? _prediction;
  bool _isLoading = true;
  int _selectedDays = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPrediction();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrediction() async {
    setState(() => _isLoading = true);
    
    try {
      final prediction = await _predictorService.predictCashFlow(
        context: context,
        daysAhead: _selectedDays,
        forceRefresh: true,
      );
      setState(() {
        _prediction = prediction;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading cash flow prediction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B3A55),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_isLoading) 
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFE5BA73))))
            else if (_prediction == null)
              const Expanded(child: Center(child: Text('No prediction data available', style: TextStyle(color: Colors.white))))
            else
              Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2B3A55), Color(0xFF3D5377)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trending_up, color: Color(0xFFE5BA73), size: 24),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Cash Flow Predictor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'AI-powered financial forecasting',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadPrediction,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTimeSelector(),
          if (_prediction != null) ...[
            const SizedBox(height: 20),
            _buildPredictionSummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Forecast Period:',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [7, 14, 30, 60].map((days) {
              final isSelected = _selectedDays == days;
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    if (days != _selectedDays) {
                      setState(() => _selectedDays = days);
                      _loadPrediction();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE5BA73) : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE5BA73) : Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${days}d',
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF2B3A55) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSummaryItem(
                'Current Balance',
                '\$${_prediction!.currentBalance.toStringAsFixed(0)}',
                Icons.account_balance_wallet,
                const Color(0xFFE5BA73),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryItem(
                'Lowest Predicted',
                '\$${_prediction!.lowestPredictedBalance.toStringAsFixed(0)}',
                Icons.trending_down,
                _prediction!.lowestPredictedBalance < 0 ? Colors.red : const Color(0xFFE5BA73),
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSummaryItem(
                'Avg Daily Expenses',
                '\$${_prediction!.averageDailyExpenses.toStringAsFixed(0)}',
                Icons.receipt_long,
                const Color(0xFF2B3A55),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryItem(
                'Confidence',
                '${(_prediction!.confidence * 100).toStringAsFixed(0)}%',
                Icons.verified,
                Colors.green,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2B3A55),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFE5BA73),
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Chart'),
                Tab(text: 'Alerts'),
                Tab(text: 'Insights'),
                Tab(text: 'Recommendations'),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChartTab(),
                  _buildAlertsTab(),
                  _buildInsightsTab(),
                  _buildRecommendationsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTab() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBalanceChart(),
            const SizedBox(height: 24),
            _buildCashFlowChart(),
            const SizedBox(height: 24),
            _buildExpenseBreakdownChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Predicted Balance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 500,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: value == 0 ? Colors.red : Colors.grey.withOpacity(0.2),
                        strokeWidth: value == 0 ? 2 : 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${(value / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF2B3A55)),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _selectedDays / 5,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _prediction!.dailyPredictions.length) {
                            final date = _prediction!.dailyPredictions[value.toInt()].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('M/d').format(date),
                                style: const TextStyle(fontSize: 10, color: Color(0xFF2B3A55)),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _prediction!.dailyPredictions.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.endingBalance);
                      }).toList(),
                      isCurved: true,
                      color: const Color(0xFF2B3A55),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF2B3A55).withOpacity(0.1),
                      ),
                    ),
                  ],
                  minY: _prediction!.lowestPredictedBalance - 500,
                  maxY: _prediction!.highestPredictedBalance + 500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowChart() {
    final maxValue = _prediction!.dailyPredictions
        .map((p) => [p.predictedIncome, p.predictedExpenses].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Cash Flow',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (group.x.toInt() >= _prediction!.dailyPredictions.length) return null;
                        final prediction = _prediction!.dailyPredictions[group.x.toInt()];
                        final isIncome = rodIndex == 0;
                        return BarTooltipItem(
                          '${DateFormat('MMM d').format(prediction.date)}\n${isIncome ? 'Income' : 'Expenses'}: \$${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white, fontSize: 12),
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
                          return Text(
                            '\$${(value / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF2B3A55)),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (_selectedDays / 5).floorToDouble(),
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _prediction!.dailyPredictions.length) {
                            final date = _prediction!.dailyPredictions[value.toInt()].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('M/d').format(date),
                                style: const TextStyle(fontSize: 10, color: Color(0xFF2B3A55)),
                              ),
                            );
                          }
                          return const SizedBox();
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
                    horizontalInterval: maxValue / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  barGroups: _prediction!.dailyPredictions.asMap().entries.map((entry) {
                    final prediction = entry.value;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: prediction.predictedIncome,
                          color: Colors.green,
                          width: 8,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        BarChartRodData(
                          toY: prediction.predictedExpenses,
                          color: Colors.red,
                          width: 8,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                      barsSpace: 4,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Income', Colors.green),
                const SizedBox(width: 24),
                _buildLegendItem('Expenses', Colors.red),
              ],
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
          style: const TextStyle(fontSize: 12, color: Color(0xFF2B3A55)),
        ),
      ],
    );
  }

  Widget _buildExpenseBreakdownChart() {
    final totalBreakdown = <String, double>{};
    for (final prediction in _prediction!.dailyPredictions) {
      for (final entry in prediction.expenseBreakdown.entries) {
        totalBreakdown[entry.key] = (totalBreakdown[entry.key] ?? 0) + entry.value;
      }
    }

    if (totalBreakdown.isEmpty || totalBreakdown.values.every((v) => v == 0)) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Expense Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B3A55),
                ),
              ),
              const SizedBox(height: 20),
              Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No expense breakdown available for this period',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: totalBreakdown.entries.map((entry) {
                          final total = totalBreakdown.values.fold(0.0, (sum, value) => sum + value);
                          final percentage = (entry.value / total) * 100;
                          return PieChartSectionData(
                            value: entry.value,
                            title: '${percentage.toStringAsFixed(0)}%',
                            color: _getCategoryColor(entry.key),
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: totalBreakdown.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(entry.key),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2B3A55),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '\$${entry.value.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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

  Widget _buildAlertsTab() {
    return Container(
      color: Colors.white,
      child: _prediction!.alerts.isEmpty
          ? _buildEmptyState('No Alerts', 'Your cash flow looks stable!')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _prediction!.alerts.length,
              itemBuilder: (context, index) {
                return _buildAlertCard(_prediction!.alerts[index]);
              },
            ),
    );
  }

  Widget _buildAlertCard(CashFlowAlert alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getAlertColor(alert.severity).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getAlertIcon(alert.type),
                color: _getAlertColor(alert.severity),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B3A55),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getAlertColor(alert.severity).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${alert.daysFromNow} day${alert.daysFromNow == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 10,
                            color: _getAlertColor(alert.severity),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('EEEE, MMM d').format(alert.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2B3A55),
                      fontWeight: FontWeight.w500,
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

  Widget _buildInsightsTab() {
    return Container(
      color: Colors.white,
      child: _prediction!.insights.isEmpty
          ? _buildEmptyState('No Insights', 'Your spending patterns look normal')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _prediction!.insights.length,
              itemBuilder: (context, index) {
                return _buildInsightCard(_prediction!.insights[index]);
              },
            ),
    );
  }

  Widget _buildInsightCard(CashFlowInsight insight) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getInsightIcon(insight.type),
                  color: _getInsightColor(insight.type),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B3A55),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(insight.severity).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    insight.severity.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getSeverityColor(insight.severity),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              insight.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (insight.actionable && insight.suggestedAction != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _handleInsightAction(insight),
                icon: const Icon(Icons.lightbulb_outline, size: 16),
                label: Text(insight.suggestedAction!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5BA73),
                  foregroundColor: const Color(0xFF2B3A55),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    return Container(
      color: Colors.white,
      child: _prediction!.recommendations.isEmpty
          ? _buildEmptyState('No Recommendations', 'Your financial management looks good!')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _prediction!.recommendations.length,
              itemBuilder: (context, index) {
                return _buildRecommendationCard(_prediction!.recommendations[index]);
              },
            ),
    );
  }

  Widget _buildRecommendationCard(SmartRecommendation recommendation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getRecommendationIcon(recommendation.type),
                  color: _getRecommendationColor(recommendation.type),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B3A55),
                    ),
                  ),
                ),
                if (recommendation.potentialSavings > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Save \$${recommendation.potentialSavings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _getPriorityIcon(recommendation.priority),
                  size: 16,
                  color: _getPriorityColor(recommendation.priority),
                ),
                const SizedBox(width: 4),
                Text(
                  'Priority: ${recommendation.priority.name.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getPriorityColor(recommendation.priority),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Groceries': const Color(0xFFE5BA73),
      'Utilities': const Color(0xFF2B3A55),
      'Rent': const Color(0xFF34495E),
      'Transportation': const Color(0xFF50C878),
      'Entertainment': const Color(0xFFE67E22),
      'Dining Out': const Color(0xFFE74C3C),
      'Shopping': const Color(0xFF9B59B6),
      'Healthcare': const Color(0xFF1ABC9C),
      'Insurance': const Color(0xFF95A5A6),
      'Subscriptions': const Color(0xFFFF6B6B),
      'Miscellaneous': const Color(0xFF7F8C8D),
    };
    return colors[category] ?? const Color(0xFF2B3A55);
  }

  Color _getAlertColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return const Color(0xFF2B3A55);
      case AlertSeverity.medium:
        return const Color(0xFFE5BA73);
      case AlertSeverity.high:
        return Colors.red;
      case AlertSeverity.critical:
        return Colors.red[900]!;
    }
  }

  IconData _getAlertIcon(CashFlowAlertType type) {
    switch (type) {
      case CashFlowAlertType.lowBalance:
        return Icons.warning_amber;
      case CashFlowAlertType.overdraft:
        return Icons.error;
      case CashFlowAlertType.largeExpense:
        return Icons.trending_up;
      case CashFlowAlertType.unusualActivity:
        return Icons.analytics;
    }
  }

  Color _getInsightColor(CashFlowInsightType type) {
    switch (type) {
      case CashFlowInsightType.warning:
        return const Color(0xFFE5BA73);
      case CashFlowInsightType.opportunity:
        return Colors.green;
      case CashFlowInsightType.planning:
        return const Color(0xFF2B3A55);
      case CashFlowInsightType.optimization:
        return const Color(0xFFE5BA73);
    }
  }

  IconData _getInsightIcon(CashFlowInsightType type) {
    switch (type) {
      case CashFlowInsightType.warning:
        return Icons.warning_amber;
      case CashFlowInsightType.opportunity:
        return Icons.lightbulb;
      case CashFlowInsightType.planning:
        return Icons.event_note;
      case CashFlowInsightType.optimization:
        return Icons.tune;
    }
  }

  Color _getSeverityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.low:
        return Colors.green;
      case InsightSeverity.medium:
        return const Color(0xFFE5BA73);
      case InsightSeverity.high:
        return Colors.red;
      case InsightSeverity.critical:
        return Colors.red[900]!;
    }
  }

  Color _getRecommendationColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.timing:
        return const Color(0xFF2B3A55);
      case RecommendationType.savings:
        return Colors.green;
      case RecommendationType.optimization:
        return const Color(0xFFE5BA73);
      case RecommendationType.investment:
        return const Color(0xFFE5BA73);
    }
  }

  IconData _getRecommendationIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.timing:
        return Icons.schedule;
      case RecommendationType.savings:
        return Icons.savings;
      case RecommendationType.optimization:
        return Icons.tune;
      case RecommendationType.investment:
        return Icons.trending_up;
    }
  }

  Color _getPriorityColor(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.low:
        return Colors.green;
      case RecommendationPriority.medium:
        return const Color(0xFFE5BA73);
      case RecommendationPriority.high:
        return Colors.red;
      case RecommendationPriority.urgent:
        return Colors.red[900]!;
    }
  }

  IconData _getPriorityIcon(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.low:
        return Icons.keyboard_arrow_down;
      case RecommendationPriority.medium:
        return Icons.remove;
      case RecommendationPriority.high:
        return Icons.keyboard_arrow_up;
      case RecommendationPriority.urgent:
        return Icons.priority_high;
    }
  }

  void _handleInsightAction(CashFlowInsight insight) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action: ${insight.suggestedAction}'),
        backgroundColor: const Color(0xFF2B3A55),
      ),
    );
  }
}