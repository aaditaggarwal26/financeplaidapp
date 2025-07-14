import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:finsight/services/subscription_detective_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionDetectiveScreen extends StatefulWidget {
  const SubscriptionDetectiveScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionDetectiveScreen> createState() => _SubscriptionDetectiveScreenState();
}

class _SubscriptionDetectiveScreenState extends State<SubscriptionDetectiveScreen>
    with SingleTickerProviderStateMixin {
  final SubscriptionDetectiveService _detectiveService = SubscriptionDetectiveService();
  
  late TabController _tabController;
  SubscriptionAnalysis? _analysis;
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSubscriptionData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() => _isLoading = true);
    
    try {
      final analysis = await _detectiveService.analyzeSubscriptions(context: context);
      setState(() {
        _analysis = analysis;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading subscription data: $e'),
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
            else if (_analysis == null)
              const Expanded(child: Center(child: Text('No subscription data available', style: TextStyle(color: Colors.white))))
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
                        const Icon(Icons.auto_awesome, color: Color(0xFFE5BA73), size: 24),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Subscription Detective',
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
                      'AI-powered subscription analysis',
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
                onPressed: _loadSubscriptionData,
              ),
            ],
          ),
          if (_analysis != null) ...[
            const SizedBox(height: 20),
            _buildSummaryCards(),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(child: _buildSummaryCard(
          'Monthly Spending',
          '\$${_analysis!.totalMonthlySpending.toStringAsFixed(0)}',
          Icons.credit_card,
          Colors.red,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard(
          'Active Subs',
          '${_analysis!.activeSubscriptionCount}',
          Icons.subscriptions,
          const Color(0xFFE5BA73),
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard(
          'Potential Savings',
          '\$${_analysis!.potentialSavings.toStringAsFixed(0)}',
          Icons.savings,
          Colors.green,
        )),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
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
                Tab(text: 'Subscriptions'),
                Tab(text: 'Insights'),
                Tab(text: 'Upcoming'),
                Tab(text: 'Savings'),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSubscriptionsTab(),
                  _buildInsightsTab(),
                  _buildUpcomingTab(),
                  _buildSavingsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsTab() {
    final filteredSubscriptions = _getFilteredSubscriptions();
    
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: filteredSubscriptions.isEmpty
                ? _buildEmptyState('No subscriptions found', 'Connect your accounts to detect subscriptions automatically')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSubscriptions.length,
                    itemBuilder: (context, index) {
                      return _buildSubscriptionCard(filteredSubscriptions[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Entertainment', 'Productivity', 'Health', 'High Confidence'];
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = selected ? filter : 'All';
                });
              },
              selectedColor: const Color(0xFFE5BA73),
              backgroundColor: Colors.grey[100],
              checkmarkColor: const Color(0xFF2B3A55),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF2B3A55) : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        },
      ),
    );
  }

  List<DetectedSubscription> _getFilteredSubscriptions() {
    if (_selectedFilter == 'All') return _analysis!.detectedSubscriptions;
    
    return _analysis!.detectedSubscriptions.where((sub) {
      switch (_selectedFilter) {
        case 'Entertainment':
          return sub.category == SubscriptionCategory.entertainment;
        case 'Productivity':
          return sub.category == SubscriptionCategory.productivity;
        case 'Health':
          return sub.category == SubscriptionCategory.health;
        case 'High Confidence':
          return sub.confidence > 0.8;
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildSubscriptionCard(DetectedSubscription subscription) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showSubscriptionDetails(subscription),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[100],
                    ),
                    child: subscription.logoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              subscription.logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.subscriptions, color: Colors.grey[400]),
                            ),
                          )
                        : Icon(Icons.subscriptions, color: Colors.grey[400]),
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
                                subscription.merchantName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B3A55),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildConfidenceBadge(subscription.confidence),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCategoryDisplayName(subscription.category),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '\$${subscription.monthlyAmount.toStringAsFixed(2)}/month',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B3A55),
                                ),
                              ),
                            ),
                            if (!subscription.isLikelyActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Inactive?',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Flexible(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancellationHelp(subscription),
                      icon: const Icon(Icons.help_outline, size: 14),
                      label: const Text('Cancel Help', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2B3A55),
                        side: const BorderSide(color: Color(0xFF2B3A55)),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAlternatives(subscription),
                      icon: const Icon(Icons.compare_arrows, size: 14),
                      label: const Text('Alternatives', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B3A55),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    Color color;
    String label;
    
    if (confidence >= 0.9) {
      color = Colors.green;
      label = 'High';
    } else if (confidence >= 0.7) {
      color = const Color(0xFFE5BA73);
      label = 'Medium';
    } else {
      color = Colors.red;
      label = 'Low';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInsightsTab() {
    return Container(
      color: Colors.white,
      child: _analysis!.insights.isEmpty
          ? _buildEmptyState('No Insights Available', 'No subscription insights found based on your data')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _analysis!.insights.length,
              itemBuilder: (context, index) {
                return _buildInsightCard(_analysis!.insights[index]);
              },
            ),
    );
  }

  Widget _buildInsightCard(SubscriptionInsight insight) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B3A55),
                        ),
                      ),
                      Text(
                        insight.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (insight.impact > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\$${insight.impact.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (insight.actionable && insight.action != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _handleInsightAction(insight),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5BA73),
                  foregroundColor: const Color(0xFF2B3A55),
                ),
                child: Text(insight.action!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingTab() {
    return Container(
      color: Colors.white,
      child: _analysis!.nextCharges.isEmpty
          ? _buildEmptyState('No upcoming charges', 'All your subscription charges are up to date')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _analysis!.nextCharges.length,
              itemBuilder: (context, index) {
                return _buildUpcomingChargeCard(_analysis!.nextCharges[index]);
              },
            ),
    );
  }

  Widget _buildUpcomingChargeCard(NextCharge charge) {
    final daysUntil = charge.daysUntilCharge;
    final isUrgent = daysUntil <= 3;
    
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
                color: isUrgent ? Colors.red.withOpacity(0.1) : const Color(0xFF2B3A55).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.schedule,
                color: isUrgent ? Colors.red : const Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    charge.merchantName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B3A55),
                    ),
                  ),
                  Text(
                    'Due ${DateFormat('MMM d').format(charge.predictedDate)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${charge.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3A55),
                  ),
                ),
                Text(
                  '$daysUntil day${daysUntil == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isUrgent ? Colors.red : Colors.grey[600],
                    fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsTab() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSavingsOverview(),
            const SizedBox(height: 16),
            _buildSavingsOpportunities(),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsOverview() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Annual Savings Potential',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '\$${_analysis!.potentialSavings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Text(
                    'per year',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSavingsChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsChart() {
    final data = [
      SavingsData('Current', _analysis!.totalAnnualSpending, Colors.red),
      SavingsData('Optimized', _analysis!.totalAnnualSpending - _analysis!.potentialSavings, Colors.green),
    ];

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _analysis!.totalAnnualSpending * 1.1,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    data[value.toInt()].category,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2B3A55)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.amount,
                  color: entry.value.color,
                  width: 40,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSavingsOpportunities() {
    final opportunities = _analysis!.detectedSubscriptions
        .where((sub) => !sub.isLikelyActive || sub.alternativePlans.isNotEmpty)
        .toList();

    if (opportunities.isEmpty) {
      return _buildEmptyState('No savings opportunities', 'All your subscriptions appear to be optimized');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Savings Opportunities',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B3A55),
          ),
        ),
        const SizedBox(height: 12),
        ...opportunities.map((sub) => _buildSavingsOpportunityCard(sub)),
      ],
    );
  }

  Widget _buildSavingsOpportunityCard(DetectedSubscription subscription) {
    final isInactive = !subscription.isLikelyActive;
    final hasAlternatives = subscription.alternativePlans.isNotEmpty;
    
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
                Expanded(
                  child: Text(
                    subscription.merchantName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B3A55),
                    ),
                  ),
                ),
                if (isInactive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Unused',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (isInactive)
              Text(
                'Save \$${subscription.annualAmount.toStringAsFixed(0)}/year by canceling',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (hasAlternatives)
              Text(
                'Consider downgrading to save money',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            const SizedBox(height: 12),
            if (hasAlternatives) ...[
              const Text(
                'Alternative Plans:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2B3A55),
                ),
              ),
              const SizedBox(height: 8),
              ...subscription.alternativePlans.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${plan.name} - \$${plan.price}/month',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (plan.price < subscription.monthlyAmount)
                      Text(
                        'Save \$${((subscription.monthlyAmount - plan.price) * 12).toStringAsFixed(0)}/year',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              )),
            ],
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
              Icons.auto_awesome,
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

  void _showSubscriptionDetails(DetectedSubscription subscription) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (subscription.logoUrl != null)
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.grey[100],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              subscription.logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.subscriptions),
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscription.merchantName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2B3A55),
                              ),
                            ),
                            Text(
                              _getCategoryDisplayName(subscription.category),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('Monthly Amount', '\$${subscription.monthlyAmount.toStringAsFixed(2)}'),
                  _buildDetailRow('Annual Cost', '\$${subscription.annualAmount.toStringAsFixed(2)}'),
                  _buildDetailRow('Frequency', 'Every ${subscription.frequency} days'),
                  _buildDetailRow('Last Charge', DateFormat('MMM d, yyyy').format(subscription.lastCharge)),
                  _buildDetailRow('Next Charge', DateFormat('MMM d, yyyy').format(subscription.nextPredictedCharge)),
                  _buildDetailRow('Confidence', '${(subscription.confidence * 100).toStringAsFixed(0)}%'),
                  _buildDetailRow('Status', subscription.isLikelyActive ? 'Active' : 'Possibly Inactive'),
                  const SizedBox(height: 20),
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B3A55),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...subscription.transactions.take(5).map((transaction) =>
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(transaction.description),
                      subtitle: Text(DateFormat('MMM d, yyyy').format(transaction.date)),
                      trailing: Text(
                        '\$${transaction.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B3A55)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2B3A55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancellationHelp(DetectedSubscription subscription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Cancel ${subscription.merchantName}', style: const TextStyle(color: Color(0xFF2B3A55))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Difficulty: ${_getCancellationDifficultyText(subscription.cancellationDifficulty)}'),
              const SizedBox(height: 16),
              if (subscription.cancellationInstructions != null) ...[
                const Text(
                  'Cancellation Steps:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B3A55)),
                ),
                const SizedBox(height: 8),
                Text(subscription.cancellationInstructions!),
                const SizedBox(height: 16),
              ],
              if (subscription.website != null) ...[
                const Text(
                  'Website:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B3A55)),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _launchURL(subscription.website!),
                  child: Text(
                    subscription.website!,
                    style: const TextStyle(color: Color(0xFF2B3A55), decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Provide real cancellation help
              const Text(
                'General Cancellation Tips:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B3A55)),
              ),
              const SizedBox(height: 8),
              const Text('• Check your email for the original signup confirmation\n• Look for account settings or billing sections\n• Contact customer service if online cancellation isn\'t available\n• Keep records of your cancellation request\n• Monitor your next billing cycle to confirm cancellation'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF2B3A55))),
          ),
          if (subscription.website != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _launchURL(subscription.website!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5BA73),
                foregroundColor: const Color(0xFF2B3A55),
              ),
              child: const Text('Visit Website'),
            ),
        ],
      ),
    );
  }

  void _showAlternatives(DetectedSubscription subscription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('${subscription.merchantName} Alternatives', style: const TextStyle(color: Color(0xFF2B3A55))),
        content: subscription.alternativePlans.isEmpty
            ? const Text('No alternative plans available for this subscription.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: subscription.alternativePlans.map((plan) => ListTile(
                  title: Text(plan.name, style: const TextStyle(color: Color(0xFF2B3A55))),
                  subtitle: Text(plan.features.join(', ')),
                  trailing: Text('\$${plan.price}/month', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B3A55))),
                )).toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF2B3A55))),
          ),
        ],
      ),
    );
  }

  void _handleInsightAction(SubscriptionInsight insight) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Insight Action: ${insight.action}'),
        backgroundColor: const Color(0xFF2B3A55),
      ),
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _getCategoryDisplayName(SubscriptionCategory category) {
    switch (category) {
      case SubscriptionCategory.entertainment:
        return 'Entertainment';
      case SubscriptionCategory.productivity:
        return 'Productivity';
      case SubscriptionCategory.health:
        return 'Health & Fitness';
      case SubscriptionCategory.finance:
        return 'Finance';
      case SubscriptionCategory.shopping:
        return 'Shopping';
      case SubscriptionCategory.news:
        return 'News & Media';
      case SubscriptionCategory.education:
        return 'Education';
      default:
        return 'Other';
    }
  }

  String _getCancellationDifficultyText(CancellationDifficulty difficulty) {
    switch (difficulty) {
      case CancellationDifficulty.easy:
        return 'Easy - Online cancellation available';
      case CancellationDifficulty.medium:
        return 'Medium - May require phone call or chat';
      case CancellationDifficulty.hard:
        return 'Hard - Multiple steps or retention efforts expected';
    }
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.spending:
        return Icons.attach_money;
      case InsightType.savings:
        return Icons.savings;
      case InsightType.waste:
        return Icons.warning;
      case InsightType.alert:
        return Icons.notification_important;
      case InsightType.opportunity:
        return Icons.lightbulb;
    }
  }

  Color _getInsightColor(InsightType type) {
    switch (type) {
      case InsightType.spending:
        return const Color(0xFF2B3A55);
      case InsightType.savings:
        return Colors.green;
      case InsightType.waste:
        return const Color(0xFFE5BA73);
      case InsightType.alert:
        return Colors.red;
      case InsightType.opportunity:
        return const Color(0xFFE5BA73);
    }
  }
}

class SavingsData {
  final String category;
  final double amount;
  final Color color;

  SavingsData(this.category, this.amount, this.color);
}