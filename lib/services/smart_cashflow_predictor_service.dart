import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/services/data_service.dart';
import 'package:finsight/services/subscription_detective_service.dart';
import 'package:intl/intl.dart';

class SmartCashFlowPredictorService {
  static final SmartCashFlowPredictorService _instance = SmartCashFlowPredictorService._internal();
  factory SmartCashFlowPredictorService() => _instance;
  SmartCashFlowPredictorService._internal();

  final DataService _dataService = DataService();
  final SubscriptionDetectiveService _subscriptionService = SubscriptionDetectiveService();
  
  // Cache for predictions
  static CashFlowPrediction? _cachedPrediction;
  static DateTime? _lastPrediction;
  static const Duration _cacheExpiry = Duration(hours: 3);

  Future<CashFlowPrediction> predictCashFlow({
    BuildContext? context,
    int daysAhead = 30,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid() && _cachedPrediction != null) {
      return _cachedPrediction!;
    }

    try {
      // Get historical transaction data
      final transactions = await _dataService.getTransactions(context: context);
      final balances = await _dataService.getAccountBalances(context: context);
      final subscriptionAnalysis = await _subscriptionService.analyzeSubscriptions(context: context);

      // Calculate current financial state
      final currentBalance = balances.isNotEmpty ? 
        balances.last.checking + balances.last.savings : 0.0;

      // Generate predictions
      final dailyPredictions = await _generateDailyPredictions(
        transactions: transactions,
        subscriptions: subscriptionAnalysis.detectedSubscriptions,
        startingBalance: currentBalance,
        daysAhead: daysAhead,
      );

      // Analyze patterns and generate insights
      final insights = _generateCashFlowInsights(dailyPredictions, transactions);
      
      // Detect potential issues
      final alerts = _detectCashFlowAlerts(dailyPredictions);
      
      // Generate recommendations
      final recommendations = _generateSmartRecommendations(
        dailyPredictions, 
        transactions, 
        subscriptionAnalysis.detectedSubscriptions
      );

      final prediction = CashFlowPrediction(
        currentBalance: currentBalance,
        dailyPredictions: dailyPredictions,
        insights: insights,
        alerts: alerts,
        recommendations: recommendations,
        confidence: _calculateConfidence(transactions),
        generatedAt: DateTime.now(),
      );

      // Cache the result
      _cachedPrediction = prediction;
      _lastPrediction = DateTime.now();

      return prediction;
    } catch (e) {
      print('Error predicting cash flow: $e');
      rethrow;
    }
  }

  Future<List<DailyCashFlowPrediction>> _generateDailyPredictions({
    required List<Transaction> transactions,
    required List<DetectedSubscription> subscriptions,
    required double startingBalance,
    required int daysAhead,
  }) async {
    final predictions = <DailyCashFlowPrediction>[];
    final now = DateTime.now();
    double runningBalance = startingBalance;

    // Analyze historical patterns
    final incomePattern = _analyzeIncomePattern(transactions);
    final expensePatterns = _analyzeExpensePatterns(transactions);
    final seasonalFactors = _calculateSeasonalFactors(transactions);

    for (int day = 0; day < daysAhead; day++) {
      final targetDate = now.add(Duration(days: day));
      
      // Predict income for this day
      final predictedIncome = _predictDayIncome(
        targetDate, 
        incomePattern, 
        seasonalFactors
      );
      
      // Predict expenses for this day
      final predictedExpenses = _predictDayExpenses(
        targetDate, 
        expensePatterns, 
        subscriptions,
        seasonalFactors
      );
      
      // Calculate net change and new balance
      final netChange = predictedIncome - predictedExpenses;
      runningBalance += netChange;
      
      // Calculate confidence based on historical data consistency
      final confidence = _calculateDayConfidence(targetDate, transactions);
      
      predictions.add(DailyCashFlowPrediction(
        date: targetDate,
        startingBalance: runningBalance - netChange,
        predictedIncome: predictedIncome,
        predictedExpenses: predictedExpenses,
        netChange: netChange,
        endingBalance: runningBalance,
        confidence: confidence,
        expenseBreakdown: _getExpenseBreakdown(targetDate, expensePatterns, subscriptions),
        incomeBreakdown: _getIncomeBreakdown(targetDate, incomePattern),
      ));
    }

    return predictions;
  }

  IncomePattern _analyzeIncomePattern(List<Transaction> transactions) {
    final incomeTransactions = transactions
        .where((t) => t.transactionType.toLowerCase() == 'credit')
        .where((t) => t.amount > 100) // Filter out small credits
        .toList();

    if (incomeTransactions.isEmpty) {
      return IncomePattern(
        averageAmount: 0,
        frequency: 30,
        dayOfMonth: 1,
        confidence: 0.1,
        isRegular: false,
      );
    }

    // Group by month to find patterns
    final monthlyIncome = <String, double>{};
    for (final transaction in incomeTransactions) {
      final monthKey = DateFormat('yyyy-MM').format(transaction.date);
      monthlyIncome[monthKey] = (monthlyIncome[monthKey] ?? 0) + transaction.amount;
    }

    final amounts = monthlyIncome.values.toList();
    final averageIncome = amounts.fold(0.0, (sum, amount) => sum + amount) / amounts.length;
    
    // Find most common day of month for income
    final incomeDays = incomeTransactions.map((t) => t.date.day).toList();
    final dayFrequency = <int, int>{};
    for (final day in incomeDays) {
      dayFrequency[day] = (dayFrequency[day] ?? 0) + 1;
    }
    
    final mostCommonDay = dayFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Calculate consistency
    final variance = amounts.map((amount) => pow(amount - averageIncome, 2)).fold(0.0, (sum, v) => sum + v) / amounts.length;
    final standardDeviation = sqrt(variance);
    final coefficientOfVariation = standardDeviation / averageIncome;
    
    return IncomePattern(
      averageAmount: averageIncome,
      frequency: 30, // Assume monthly for now
      dayOfMonth: mostCommonDay,
      confidence: 1.0 - min(coefficientOfVariation, 1.0),
      isRegular: coefficientOfVariation < 0.3,
    );
  }

  Map<String, ExpensePattern> _analyzeExpensePatterns(List<Transaction> transactions) {
    final expenseTransactions = transactions
        .where((t) => t.transactionType.toLowerCase() == 'debit')
        .toList();

    final patterns = <String, ExpensePattern>{};
    
    // Group by category
    final categorizedExpenses = <String, List<Transaction>>{};
    for (final transaction in expenseTransactions) {
      categorizedExpenses.putIfAbsent(transaction.category, () => []).add(transaction);
    }

    for (final entry in categorizedExpenses.entries) {
      final category = entry.key;
      final categoryTransactions = entry.value;
      
      if (categoryTransactions.length < 3) continue;

      // Calculate daily average
      final totalAmount = categoryTransactions.fold(0.0, (sum, t) => sum + t.amount);
      final daysCovered = DateTime.now().difference(categoryTransactions.first.date).inDays;
      final dailyAverage = daysCovered > 0 ? totalAmount / daysCovered : 0;

      // Find spending patterns by day of week
      final dayOfWeekSpending = <int, double>{};
      for (final transaction in categoryTransactions) {
        final dayOfWeek = transaction.date.weekday;
        dayOfWeekSpending[dayOfWeek] = (dayOfWeekSpending[dayOfWeek] ?? 0) + transaction.amount;
      }

      // Find spending patterns by day of month
      final dayOfMonthSpending = <int, double>{};
      for (final transaction in categoryTransactions) {
        final dayOfMonth = transaction.date.day;
        dayOfMonthSpending[dayOfMonth] = (dayOfMonthSpending[dayOfMonth] ?? 0) + transaction.amount;
      }

      patterns[category] = ExpensePattern(
        category: category,
        dailyAverage: dailyAverage.toDouble(),
        weeklyPattern: _normalizeWeeklyPattern(dayOfWeekSpending),
        monthlyPattern: _normalizeMonthlyPattern(dayOfMonthSpending),
        volatility: _calculateVolatility(categoryTransactions),
        confidence: _calculatePatternConfidence(categoryTransactions),
      );
    }

    return patterns;
  }

  Map<int, double> _normalizeWeeklyPattern(Map<int, double> dayOfWeekSpending) {
    final total = dayOfWeekSpending.values.fold(0.0, (sum, amount) => sum + amount);
    if (total == 0) return {};
    
    return dayOfWeekSpending.map((day, amount) => MapEntry(day, amount / total));
  }

  Map<int, double> _normalizeMonthlyPattern(Map<int, double> dayOfMonthSpending) {
    final total = dayOfMonthSpending.values.fold(0.0, (sum, amount) => sum + amount);
    if (total == 0) return {};
    
    return dayOfMonthSpending.map((day, amount) => MapEntry(day, amount / total));
  }

  double _calculateVolatility(List<Transaction> transactions) {
    if (transactions.length < 2) return 1.0;
    
    final amounts = transactions.map((t) => t.amount).toList();
    final average = amounts.fold(0.0, (sum, amount) => sum + amount) / amounts.length;
    final variance = amounts.map((amount) => pow(amount - average, 2)).fold(0.0, (sum, v) => sum + v) / amounts.length;
    
    return sqrt(variance) / average;
  }

  double _calculatePatternConfidence(List<Transaction> transactions) {
    // Higher confidence for more transactions and lower volatility
    final transactionCount = transactions.length;
    final volatility = _calculateVolatility(transactions);
    
    final countFactor = min(transactionCount / 20.0, 1.0);
    final volatilityFactor = max(0.1, 1.0 - volatility);
    
    return countFactor * volatilityFactor;
  }

  Map<String, double> _calculateSeasonalFactors(List<Transaction> transactions) {
    final monthlySpending = <int, double>{};
    
    for (final transaction in transactions) {
      if (transaction.transactionType.toLowerCase() == 'debit') {
        final month = transaction.date.month;
        monthlySpending[month] = (monthlySpending[month] ?? 0) + transaction.amount;
      }
    }

    if (monthlySpending.isEmpty) return {};

    final averageSpending = monthlySpending.values.fold(0.0, (sum, amount) => sum + amount) / monthlySpending.length;
    
    return monthlySpending.map((month, amount) => 
      MapEntry(month.toString(), amount / averageSpending)
    );
  }

  double _predictDayIncome(DateTime date, IncomePattern pattern, Map<String, double> seasonalFactors) {
    if (!pattern.isRegular) return 0;

    // Check if this is a typical payday
    if (date.day == pattern.dayOfMonth || 
        (date.day >= pattern.dayOfMonth - 2 && date.day <= pattern.dayOfMonth + 2)) {
      
      final seasonalFactor = seasonalFactors[date.month.toString()] ?? 1.0;
      return pattern.averageAmount * seasonalFactor * pattern.confidence;
    }

    return 0;
  }

  double _predictDayExpenses(
    DateTime date, 
    Map<String, ExpensePattern> patterns,
    List<DetectedSubscription> subscriptions,
    Map<String, double> seasonalFactors,
  ) {
    double totalExpenses = 0;

    // Add subscription expenses
    for (final subscription in subscriptions) {
      if (_isSubscriptionDue(date, subscription)) {
        totalExpenses += subscription.monthlyAmount;
      }
    }

    // Add pattern-based expenses
    for (final pattern in patterns.values) {
      final dayOfWeek = date.weekday;
      final dayOfMonth = date.day;
      
      final weeklyFactor = pattern.weeklyPattern[dayOfWeek] ?? (1.0 / 7);
      final monthlyFactor = pattern.monthlyPattern[dayOfMonth] ?? (1.0 / 30);
      final seasonalFactor = seasonalFactors[date.month.toString()] ?? 1.0;
      
      // Use the higher of weekly or monthly factor for better prediction
      final combinedFactor = max(weeklyFactor * 7, monthlyFactor * 30);
      
      totalExpenses += pattern.dailyAverage * combinedFactor * seasonalFactor * pattern.confidence;
    }

    return totalExpenses;
  }

  bool _isSubscriptionDue(DateTime date, DetectedSubscription subscription) {
    final daysSinceLastCharge = date.difference(subscription.lastCharge).inDays;
    final expectedDays = subscription.frequency;
    
    // Allow for some variance in subscription timing
    return daysSinceLastCharge >= expectedDays - 2 && daysSinceLastCharge <= expectedDays + 2;
  }

  double _calculateDayConfidence(DateTime date, List<Transaction> transactions) {
    final daysFromNow = date.difference(DateTime.now()).inDays;
    
    // Confidence decreases with time
    final timeFactor = max(0.1, 1.0 - (daysFromNow / 30.0));
    
    // Confidence increases with more historical data
    final dataFactor = min(1.0, transactions.length / 100.0);
    
    return timeFactor * dataFactor;
  }

  Map<String, double> _getExpenseBreakdown(
    DateTime date, 
    Map<String, ExpensePattern> patterns,
    List<DetectedSubscription> subscriptions,
  ) {
    final breakdown = <String, double>{};

    // Add subscription expenses
    for (final subscription in subscriptions) {
      if (_isSubscriptionDue(date, subscription)) {
        breakdown['Subscriptions'] = (breakdown['Subscriptions'] ?? 0) + subscription.monthlyAmount;
      }
    }

    // Add pattern-based expenses
    for (final pattern in patterns.values) {
      final dayOfWeek = date.weekday;
      final weeklyFactor = pattern.weeklyPattern[dayOfWeek] ?? (1.0 / 7);
      final amount = pattern.dailyAverage * weeklyFactor * 7 * pattern.confidence;
      
      if (amount > 0.1) { // Only include significant amounts
        breakdown[pattern.category] = amount;
      }
    }

    return breakdown;
  }

  List<IncomeSource> _getIncomeBreakdown(DateTime date, IncomePattern pattern) {
    if (!pattern.isRegular) return [];

    if (date.day == pattern.dayOfMonth) {
      return [
        IncomeSource(
          source: 'Salary/Wages',
          amount: pattern.averageAmount,
          confidence: pattern.confidence,
        ),
      ];
    }

    return [];
  }

  List<CashFlowInsight> _generateCashFlowInsights(
    List<DailyCashFlowPrediction> predictions, 
    List<Transaction> transactions,
  ) {
    final insights = <CashFlowInsight>[];

    // Analyze balance trends
    final lowestBalance = predictions.map((p) => p.endingBalance).reduce(min);
    final highestBalance = predictions.map((p) => p.endingBalance).reduce(max);
    
    if (lowestBalance < 0) {
      insights.add(CashFlowInsight(
        type: CashFlowInsightType.warning,
        title: 'Potential Overdraft Risk',
        description: 'Your balance may go negative around ${DateFormat('MMM d').format(predictions.firstWhere((p) => p.endingBalance < 0).date)}',
        severity: InsightSeverity.high,
        actionable: true,
        suggestedAction: 'Consider postponing non-essential expenses or transferring funds',
      ));
    }

    // Check for large upcoming expenses
    final largeExpenseDays = predictions.where((p) => p.predictedExpenses > 500).toList();
    if (largeExpenseDays.isNotEmpty) {
      insights.add(CashFlowInsight(
        type: CashFlowInsightType.planning,
        title: 'Large Expenses Ahead',
        description: 'You have ${largeExpenseDays.length} days with expenses over \$500',
        severity: InsightSeverity.medium,
        actionable: true,
        suggestedAction: 'Review and optimize your upcoming expenses',
      ));
    }

    // Analyze cash flow volatility
    final balanceChanges = predictions.map((p) => p.netChange.abs()).toList();
    final averageChange = balanceChanges.fold(0.0, (sum, change) => sum + change) / balanceChanges.length;
    final volatileChanges = balanceChanges.where((change) => change > averageChange * 2).length;
    
    if (volatileChanges > predictions.length * 0.3) {
      insights.add(CashFlowInsight(
        type: CashFlowInsightType.optimization,
        title: 'High Cash Flow Volatility',
        description: 'Your daily cash flow varies significantly',
        severity: InsightSeverity.medium,
        actionable: true,
        suggestedAction: 'Consider budgeting tools to smooth out your spending',
      ));
    }

    return insights;
  }

  List<CashFlowAlert> _detectCashFlowAlerts(List<DailyCashFlowPrediction> predictions) {
    final alerts = <CashFlowAlert>[];

    for (int i = 0; i < predictions.length; i++) {
      final prediction = predictions[i];
      
      // Low balance alert
      if (prediction.endingBalance < 100 && prediction.endingBalance > 0) {
        alerts.add(CashFlowAlert(
          type: CashFlowAlertType.lowBalance,
          date: prediction.date,
          title: 'Low Balance Warning',
          description: 'Balance may drop to \$${prediction.endingBalance.toStringAsFixed(2)}',
          severity: AlertSeverity.medium,
          amount: prediction.endingBalance,
        ));
      }
      
      // Overdraft alert
      if (prediction.endingBalance < 0) {
        alerts.add(CashFlowAlert(
          type: CashFlowAlertType.overdraft,
          date: prediction.date,
          title: 'Overdraft Risk',
          description: 'Balance may go negative by \$${prediction.endingBalance.abs().toStringAsFixed(2)}',
          severity: AlertSeverity.high,
          amount: prediction.endingBalance,
        ));
      }
      
      // Large expense alert
      if (prediction.predictedExpenses > 1000) {
        alerts.add(CashFlowAlert(
          type: CashFlowAlertType.largeExpense,
          date: prediction.date,
          title: 'Large Expense Day',
          description: 'Predicted expenses: \$${prediction.predictedExpenses.toStringAsFixed(2)}',
          severity: AlertSeverity.medium,
          amount: prediction.predictedExpenses,
        ));
      }
    }

    return alerts;
  }

  List<SmartRecommendation> _generateSmartRecommendations(
    List<DailyCashFlowPrediction> predictions,
    List<Transaction> transactions,
    List<DetectedSubscription> subscriptions,
  ) {
    final recommendations = <SmartRecommendation>[];

    // Find optimal timing for large purchases
    final bestDays = predictions
        .where((p) => p.endingBalance > 1000)
        .where((p) => p.predictedExpenses < 200)
        .take(5)
        .toList();

    if (bestDays.isNotEmpty) {
      recommendations.add(SmartRecommendation(
        type: RecommendationType.timing,
        title: 'Optimal Purchase Timing',
        description: 'Best days for large purchases: ${bestDays.map((d) => DateFormat('MMM d').format(d.date)).join(', ')}',
        priority: RecommendationPriority.medium,
        potentialSavings: 0,
        actionable: true,
      ));
    }

    // Recommend emergency fund if balance gets too low
    final lowestBalance = predictions.map((p) => p.endingBalance).reduce(min);
    if (lowestBalance < 500) {
      recommendations.add(SmartRecommendation(
        type: RecommendationType.savings,
        title: 'Build Emergency Fund',
        description: 'Your balance drops below \$500. Consider building a buffer.',
        priority: RecommendationPriority.high,
        potentialSavings: 0,
        actionable: true,
      ));
    }

    // Recommend subscription optimization
    final expensiveSubscriptions = subscriptions
        .where((s) => s.monthlyAmount > 50)
        .where((s) => !s.isLikelyActive)
        .toList();

    if (expensiveSubscriptions.isNotEmpty) {
      final totalSavings = expensiveSubscriptions.fold(0.0, (sum, s) => sum + s.monthlyAmount);
      recommendations.add(SmartRecommendation(
        type: RecommendationType.optimization,
        title: 'Cancel Unused Subscriptions',
        description: 'You could save \$${totalSavings.toStringAsFixed(0)}/month',
        priority: RecommendationPriority.high,
        potentialSavings: totalSavings * 12,
        actionable: true,
      ));
    }

    return recommendations;
  }

  double _calculateConfidence(List<Transaction> transactions) {
    if (transactions.isEmpty) return 0.1;
    
    // Confidence based on data quantity and recency
    final recentTransactions = transactions.where((t) => 
      t.date.isAfter(DateTime.now().subtract(const Duration(days: 90)))
    ).length;
    
    final dataQualityScore = min(1.0, recentTransactions / 50.0);
    final consistencyScore = _calculateDataConsistency(transactions);
    
    return (dataQualityScore + consistencyScore) / 2;
  }

  double _calculateDataConsistency(List<Transaction> transactions) {
    if (transactions.length < 10) return 0.3;
    
    // Analyze consistency of spending patterns
    final monthlySpending = <String, double>{};
    for (final transaction in transactions) {
      if (transaction.transactionType.toLowerCase() == 'debit') {
        final monthKey = DateFormat('yyyy-MM').format(transaction.date);
        monthlySpending[monthKey] = (monthlySpending[monthKey] ?? 0) + transaction.amount;
      }
    }
    
    if (monthlySpending.length < 3) return 0.5;
    
    final amounts = monthlySpending.values.toList();
    final average = amounts.fold(0.0, (sum, amount) => sum + amount) / amounts.length;
    final variance = amounts.map((amount) => pow(amount - average, 2)).fold(0.0, (sum, v) => sum + v) / amounts.length;
    final coefficientOfVariation = sqrt(variance) / average;
    
    return max(0.1, 1.0 - min(1.0, coefficientOfVariation));
  }

  bool _isCacheValid() {
    if (_lastPrediction == null) return false;
    return DateTime.now().difference(_lastPrediction!) < _cacheExpiry;
  }

  Future<void> clearCache() async {
    _cachedPrediction = null;
    _lastPrediction = null;
  }
}

// Data classes
class CashFlowPrediction {
  final double currentBalance;
  final List<DailyCashFlowPrediction> dailyPredictions;
  final List<CashFlowInsight> insights;
  final List<CashFlowAlert> alerts;
  final List<SmartRecommendation> recommendations;
  final double confidence;
  final DateTime generatedAt;

  const CashFlowPrediction({
    required this.currentBalance,
    required this.dailyPredictions,
    required this.insights,
    required this.alerts,
    required this.recommendations,
    required this.confidence,
    required this.generatedAt,
  });

  double get lowestPredictedBalance => 
      dailyPredictions.map((p) => p.endingBalance).reduce(min);
  
  double get highestPredictedBalance => 
      dailyPredictions.map((p) => p.endingBalance).reduce(max);
  
  int get daysUntilLowBalance => 
      dailyPredictions.indexWhere((p) => p.endingBalance < 100);
  
  double get averageDailyExpenses => 
      dailyPredictions.map((p) => p.predictedExpenses).fold(0.0, (sum, exp) => sum + exp) / dailyPredictions.length;
}

class DailyCashFlowPrediction {
  final DateTime date;
  final double startingBalance;
  final double predictedIncome;
  final double predictedExpenses;
  final double netChange;
  final double endingBalance;
  final double confidence;
  final Map<String, double> expenseBreakdown;
  final List<IncomeSource> incomeBreakdown;

  const DailyCashFlowPrediction({
    required this.date,
    required this.startingBalance,
    required this.predictedIncome,
    required this.predictedExpenses,
    required this.netChange,
    required this.endingBalance,
    required this.confidence,
    required this.expenseBreakdown,
    required this.incomeBreakdown,
  });

  bool get isPositiveDay => netChange > 0;
  bool get isHighExpenseDay => predictedExpenses > 200;
  bool get isLowBalanceDay => endingBalance < 100;
}

class IncomePattern {
  final double averageAmount;
  final int frequency; // days between income
  final int dayOfMonth; // typical day of month for income
  final double confidence;
  final bool isRegular;

  const IncomePattern({
    required this.averageAmount,
    required this.frequency,
    required this.dayOfMonth,
    required this.confidence,
    required this.isRegular,
  });
}

class ExpensePattern {
  final String category;
  final double dailyAverage;
  final Map<int, double> weeklyPattern; // day of week -> factor
  final Map<int, double> monthlyPattern; // day of month -> factor
  final double volatility;
  final double confidence;

  const ExpensePattern({
    required this.category,
    required this.dailyAverage,
    required this.weeklyPattern,
    required this.monthlyPattern,
    required this.volatility,
    required this.confidence,
  });
}

class IncomeSource {
  final String source;
  final double amount;
  final double confidence;

  const IncomeSource({
    required this.source,
    required this.amount,
    required this.confidence,
  });
}

class CashFlowInsight {
  final CashFlowInsightType type;
  final String title;
  final String description;
  final InsightSeverity severity;
  final bool actionable;
  final String? suggestedAction;

  const CashFlowInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    this.actionable = false,
    this.suggestedAction,
  });
}

class CashFlowAlert {
  final CashFlowAlertType type;
  final DateTime date;
  final String title;
  final String description;
  final AlertSeverity severity;
  final double amount;

  const CashFlowAlert({
    required this.type,
    required this.date,
    required this.title,
    required this.description,
    required this.severity,
    required this.amount,
  });

  int get daysFromNow => date.difference(DateTime.now()).inDays;
}

class SmartRecommendation {
  final RecommendationType type;
  final String title;
  final String description;
  final RecommendationPriority priority;
  final double potentialSavings;
  final bool actionable;

  const SmartRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.potentialSavings,
    this.actionable = false,
  });
}

// Enums
enum CashFlowInsightType {
  warning,
  opportunity,
  planning,
  optimization,
}

enum InsightSeverity {
  low,
  medium,
  high,
  critical,
}

enum CashFlowAlertType {
  lowBalance,
  overdraft,
  largeExpense,
  unusualActivity,
}

enum AlertSeverity {
  info,
  medium,
  high,
  critical,
}

enum RecommendationType {
  timing,
  savings,
  optimization,
  investment,
}

enum RecommendationPriority {
  low,
  medium,
  high,
  urgent,
}