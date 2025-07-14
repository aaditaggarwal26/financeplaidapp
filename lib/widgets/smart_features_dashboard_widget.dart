import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finsight/services/subscription_detective_service.dart';
import 'package:finsight/services/smart_cashflow_predictor_service.dart';
import 'package:finsight/screens/subscription_detective_screen.dart';
import 'package:finsight/screens/smart_cashflow_predictor_screen.dart';

class SmartFeaturesDashboardWidget extends StatefulWidget {
  const SmartFeaturesDashboardWidget({Key? key}) : super(key: key);

  @override
  State<SmartFeaturesDashboardWidget> createState() => _SmartFeaturesDashboardWidgetState();
}

class _SmartFeaturesDashboardWidgetState extends State<SmartFeaturesDashboardWidget> {
  final SubscriptionDetectiveService _subscriptionService = SubscriptionDetectiveService();
  final SmartCashFlowPredictorService _cashFlowService = SmartCashFlowPredictorService();
  
  SubscriptionAnalysis? _subscriptionAnalysis;
  CashFlowPrediction? _cashFlowPrediction;
  bool _isLoadingSubscriptions = true;
  bool _isLoadingCashFlow = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSmartFeatures();
  }

  Future<void> _loadSmartFeatures() async {
    print('=== SmartFeaturesDashboard: Loading smart features ===');
    
    // Load subscription analysis
    try {
      final subscriptionAnalysis = await _subscriptionService.analyzeSubscriptions(context: context);
      if (mounted) {
        setState(() {
          _subscriptionAnalysis = subscriptionAnalysis;
          _isLoadingSubscriptions = false;
        });
      }
      print('SmartFeaturesDashboard: Subscription analysis loaded successfully');
    } catch (e) {
      print('SmartFeaturesDashboard: Error loading subscription analysis: $e');
      if (mounted) {
        setState(() => _isLoadingSubscriptions = false);
      }
    }

    // Load cash flow prediction
    try {
      final cashFlowPrediction = await _cashFlowService.predictCashFlow(context: context, daysAhead: 7);
      if (mounted) {
        setState(() {
          _cashFlowPrediction = cashFlowPrediction;
          _isLoadingCashFlow = false;
        });
      }
      print('SmartFeaturesDashboard: Cash flow prediction loaded successfully');
    } catch (e) {
      print('SmartFeaturesDashboard: Error loading cash flow prediction: $e');
      if (mounted) {
        setState(() => _isLoadingCashFlow = false);
      }
    }
  }

  Future<void> _refreshData() async {
    print('=== SmartFeaturesDashboard: Refreshing data ===');
    setState(() {
      _isLoadingSubscriptions = true;
      _isLoadingCashFlow = true;
      _errorMessage = null;
    });
    await _loadSmartFeatures();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFE5BA73), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'AI-POWERED INSIGHTS',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              if (_isLoadingSubscriptions || _isLoadingCashFlow)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE5BA73),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                  onPressed: _refreshData,
                  tooltip: 'Refresh insights',
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildSubscriptionDetectiveCard(),
        const SizedBox(height: 12),
        _buildCashFlowPredictorCard(),
      ],
    );
  }

  Widget _buildSubscriptionDetectiveCard() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SubscriptionDetectiveScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2B3A55).withOpacity(0.05),
                const Color(0xFF2B3A55).withOpacity(0.02),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B3A55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFE5BA73),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subscription Detective',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B3A55),
                          ),
                        ),
                        Text(
                          'AI-powered subscription analysis',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoadingSubscriptions)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFFE5BA73)),
                  ),
                )
              else if (_subscriptionAnalysis != null)
                _buildSubscriptionPreview()
              else
                _buildSubscriptionEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionPreview() {
    final analysis = _subscriptionAnalysis!;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSubscriptionStat(
                'Active Subscriptions',
                '${analysis.activeSubscriptionCount}',
                Icons.subscriptions,
                const Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSubscriptionStat(
                'Monthly Spend',
                '\$${analysis.totalMonthlySpending.toStringAsFixed(0)}',
                Icons.credit_card,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSubscriptionStat(
                'Potential Savings',
                '\$${analysis.potentialSavings.toStringAsFixed(0)}',
                Icons.savings,
                Colors.green,
              ),
            ),
          ],
        ),
        if (analysis.insights.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5BA73).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5BA73).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: const Color(0xFFE5BA73), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    analysis.insights.first.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2B3A55),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubscriptionStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.search, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'Connect accounts to detect subscriptions',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowPredictorCard() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SmartCashFlowPredictorScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2B3A55).withOpacity(0.05),
                const Color(0xFF2B3A55).withOpacity(0.02),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B3A55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: Color(0xFFE5BA73),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cash Flow Predictor',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B3A55),
                          ),
                        ),
                        Text(
                          'Smart financial forecasting',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoadingCashFlow)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFFE5BA73)),
                  ),
                )
              else if (_cashFlowPrediction != null)
                _buildCashFlowPreview()
              else
                _buildCashFlowEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashFlowPreview() {
    final prediction = _cashFlowPrediction!;
    final nextWeekBalance = prediction.dailyPredictions.length >= 7 
        ? prediction.dailyPredictions[6].endingBalance 
        : prediction.currentBalance;
    final balanceChange = nextWeekBalance - prediction.currentBalance;
    final isPositive = balanceChange >= 0;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCashFlowStat(
                'Current Balance',
                '\$${prediction.currentBalance.toStringAsFixed(0)}',
                Icons.account_balance_wallet,
                const Color(0xFF2B3A55),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCashFlowStat(
                '7-Day Outlook',
                '${isPositive ? '+' : ''}\$${balanceChange.toStringAsFixed(0)}',
                isPositive ? Icons.trending_up : Icons.trending_down,
                isPositive ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCashFlowStat(
                'Confidence',
                '${(prediction.confidence * 100).toStringAsFixed(0)}%',
                Icons.verified,
                const Color(0xFFE5BA73),
              ),
            ),
          ],
        ),
        if (prediction.alerts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prediction.alerts.first.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCashFlowStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.trending_up, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'Connect accounts for cash flow predictions',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}