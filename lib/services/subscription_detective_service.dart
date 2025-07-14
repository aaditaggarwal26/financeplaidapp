import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/services/data_service.dart';
import 'package:intl/intl.dart';

class SubscriptionDetectiveService {
  static final SubscriptionDetectiveService _instance = SubscriptionDetectiveService._internal();
  factory SubscriptionDetectiveService() => _instance;
  SubscriptionDetectiveService._internal();

  final DataService _dataService = DataService();
  
  // Cache for detected subscriptions
  static List<DetectedSubscription>? _cachedSubscriptions;
  static DateTime? _lastAnalysis;
  static const Duration _cacheExpiry = Duration(hours: 6);

  // Machine learning patterns for subscription detection
  static const Map<String, SubscriptionPattern> _subscriptionPatterns = {
    'netflix': SubscriptionPattern(
      keywords: ['netflix', 'nflx'],
      amountRange: [8.99, 22.99],
      frequency: 30,
      confidence: 0.95,
    ),
    'spotify': SubscriptionPattern(
      keywords: ['spotify', 'spotify premium'],
      amountRange: [9.99, 16.99],
      frequency: 30,
      confidence: 0.95,
    ),
    'amazon_prime': SubscriptionPattern(
      keywords: ['amazon prime', 'amzn mktp', 'amazon.com'],
      amountRange: [12.99, 139.00],
      frequency: 30,
      confidence: 0.85,
    ),
    'apple': SubscriptionPattern(
      keywords: ['apple.com/bill', 'apple services', 'itunes'],
      amountRange: [0.99, 29.99],
      frequency: 30,
      confidence: 0.90,
    ),
    'google': SubscriptionPattern(
      keywords: ['google', 'youtube premium', 'google one'],
      amountRange: [1.99, 19.99],
      frequency: 30,
      confidence: 0.90,
    ),
    'hulu': SubscriptionPattern(
      keywords: ['hulu', 'hulu.com'],
      amountRange: [5.99, 75.99],
      frequency: 30,
      confidence: 0.95,
    ),
    'disney': SubscriptionPattern(
      keywords: ['disney', 'disney+', 'disneyplus'],
      amountRange: [7.99, 13.99],
      frequency: 30,
      confidence: 0.95,
    ),
    'adobe': SubscriptionPattern(
      keywords: ['adobe', 'creative cloud'],
      amountRange: [9.99, 79.99],
      frequency: 30,
      confidence: 0.95,
    ),
    'microsoft': SubscriptionPattern(
      keywords: ['microsoft', 'office 365', 'microsoft 365'],
      amountRange: [6.99, 21.99],
      frequency: 30,
      confidence: 0.95,
    ),
    'gym': SubscriptionPattern(
      keywords: ['gym', 'fitness', 'planet fitness', 'la fitness', 'equinox'],
      amountRange: [10.00, 200.00],
      frequency: 30,
      confidence: 0.80,
    ),
  };

  Future<SubscriptionAnalysis> analyzeSubscriptions({BuildContext? context, bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid() && _cachedSubscriptions != null) {
      return SubscriptionAnalysis(
        detectedSubscriptions: _cachedSubscriptions!,
        potentialSavings: _calculatePotentialSavings(_cachedSubscriptions!),
        nextCharges: _predictNextCharges(_cachedSubscriptions!),
        insights: _generateInsights(_cachedSubscriptions!),
      );
    }

    try {
      // Get transactions from the last 12 months
      final transactions = await _dataService.getTransactions(context: context);
      final recentTransactions = transactions.where((t) => 
        t.date.isAfter(DateTime.now().subtract(const Duration(days: 365)))
      ).toList();

      // Apply AI detection algorithms
      final detectedSubscriptions = await _detectSubscriptions(recentTransactions);
      
      // Enhance with external data
      final enrichedSubscriptions = await _enrichSubscriptionData(detectedSubscriptions);
      
      // Cache results
      _cachedSubscriptions = enrichedSubscriptions;
      _lastAnalysis = DateTime.now();
      
      return SubscriptionAnalysis(
        detectedSubscriptions: enrichedSubscriptions,
        potentialSavings: _calculatePotentialSavings(enrichedSubscriptions),
        nextCharges: _predictNextCharges(enrichedSubscriptions),
        insights: _generateInsights(enrichedSubscriptions),
      );
    } catch (e) {
      print('Error analyzing subscriptions: $e');
      return SubscriptionAnalysis(
        detectedSubscriptions: [],
        potentialSavings: 0,
        nextCharges: [],
        insights: [],
      );
    }
  }

  Future<List<DetectedSubscription>> _detectSubscriptions(List<Transaction> transactions) async {
    final Map<String, List<Transaction>> groupedTransactions = {};
    
    // Group transactions by merchant/description
    for (final transaction in transactions) {
      final key = _normalizeDescription(transaction.description);
      if (!groupedTransactions.containsKey(key)) {
        groupedTransactions[key] = [];
      }
      groupedTransactions[key]!.add(transaction);
    }

    final List<DetectedSubscription> detected = [];

    for (final entry in groupedTransactions.entries) {
      final merchantKey = entry.key;
      final merchantTransactions = entry.value;

      // Apply various detection algorithms
      final subscription = await _analyzeTransactionGroup(merchantKey, merchantTransactions);
      if (subscription != null) {
        detected.add(subscription);
      }
    }

    return detected..sort((a, b) => b.monthlyAmount.compareTo(a.monthlyAmount));
  }

  Future<DetectedSubscription?> _analyzeTransactionGroup(String merchantKey, List<Transaction> transactions) async {
    if (transactions.length < 2) return null;

    // Sort by date
    transactions.sort((a, b) => a.date.compareTo(b.date));

    // Pattern-based detection
    final patternMatch = _detectByPattern(merchantKey, transactions);
    if (patternMatch != null) return patternMatch;

    // Frequency analysis
    final frequencyMatch = _detectByFrequency(merchantKey, transactions);
    if (frequencyMatch != null) return frequencyMatch;

    // Amount consistency analysis
    final consistencyMatch = _detectByConsistency(merchantKey, transactions);
    if (consistencyMatch != null) return consistencyMatch;

    return null;
  }

  DetectedSubscription? _detectByPattern(String merchantKey, List<Transaction> transactions) {
    for (final entry in _subscriptionPatterns.entries) {
      final pattern = entry.value;
      
      // Check if merchant matches known patterns
      final matchesKeyword = pattern.keywords.any((keyword) => 
        merchantKey.toLowerCase().contains(keyword.toLowerCase())
      );
      
      if (!matchesKeyword) continue;

      // Verify amount range
      final averageAmount = transactions.map((t) => t.amount).reduce((a, b) => a + b) / transactions.length;
      if (averageAmount < pattern.amountRange[0] || averageAmount > pattern.amountRange[1]) {
        continue;
      }

      // Verify frequency
      if (!_isRecurringFrequency(transactions, pattern.frequency)) continue;

      return DetectedSubscription(
        merchantName: transactions.first.merchantName ?? transactions.first.description,
        description: transactions.first.description,
        monthlyAmount: averageAmount,
        frequency: _calculateFrequency(transactions),
        lastCharge: transactions.last.date,
        nextPredictedCharge: _predictNextCharge(transactions),
        confidence: pattern.confidence,
        category: _categorizeSubscription(entry.key),
        transactions: transactions,
        cancellationDifficulty: _assessCancellationDifficulty(entry.key),
        website: transactions.first.merchantWebsite,
        logoUrl: transactions.first.merchantLogoUrl,
      );
    }
    return null;
  }

  DetectedSubscription? _detectByFrequency(String merchantKey, List<Transaction> transactions) {
    if (transactions.length < 3) return null;

    final intervals = <int>[];
    for (int i = 1; i < transactions.length; i++) {
      final daysDiff = transactions[i].date.difference(transactions[i-1].date).inDays;
      intervals.add(daysDiff);
    }

    // Check for consistent intervals
    final averageInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals.map((interval) => pow(interval - averageInterval, 2)).reduce((a, b) => a + b) / intervals.length;
    final standardDeviation = sqrt(variance);

    // If standard deviation is low, it's likely recurring
    if (standardDeviation < 5 && averageInterval >= 25 && averageInterval <= 35) {
      final averageAmount = transactions.map((t) => t.amount).reduce((a, b) => a + b) / transactions.length;
      
      return DetectedSubscription(
        merchantName: transactions.first.merchantName ?? transactions.first.description,
        description: transactions.first.description,
        monthlyAmount: averageAmount,
        frequency: averageInterval.round(),
        lastCharge: transactions.last.date,
        nextPredictedCharge: transactions.last.date.add(Duration(days: averageInterval.round())),
        confidence: 0.75 - (standardDeviation * 0.1),
        category: SubscriptionCategory.unknown,
        transactions: transactions,
        cancellationDifficulty: CancellationDifficulty.medium,
        website: transactions.first.merchantWebsite,
        logoUrl: transactions.first.merchantLogoUrl,
      );
    }

    return null;
  }

  DetectedSubscription? _detectByConsistency(String merchantKey, List<Transaction> transactions) {
    if (transactions.length < 3) return null;

    // Check amount consistency
    final amounts = transactions.map((t) => t.amount).toList();
    final averageAmount = amounts.reduce((a, b) => a + b) / amounts.length;
    final amountVariance = amounts.map((amount) => pow(amount - averageAmount, 2)).reduce((a, b) => a + b) / amounts.length;
    
    // If amounts are very consistent (low variance)
    if (amountVariance < 1.0) {
      final daysSinceFirst = DateTime.now().difference(transactions.first.date).inDays;
      final expectedCharges = (daysSinceFirst / 30).round();
      
      // If we have at least 75% of expected charges
      if (transactions.length >= expectedCharges * 0.75) {
        return DetectedSubscription(
          merchantName: transactions.first.merchantName ?? transactions.first.description,
          description: transactions.first.description,
          monthlyAmount: averageAmount,
          frequency: 30,
          lastCharge: transactions.last.date,
          nextPredictedCharge: transactions.last.date.add(const Duration(days: 30)),
          confidence: 0.70,
          category: SubscriptionCategory.unknown,
          transactions: transactions,
          cancellationDifficulty: CancellationDifficulty.medium,
          website: transactions.first.merchantWebsite,
          logoUrl: transactions.first.merchantLogoUrl,
        );
      }
    }

    return null;
  }

  Future<List<DetectedSubscription>> _enrichSubscriptionData(List<DetectedSubscription> subscriptions) async {
    final enriched = <DetectedSubscription>[];
    
    for (final subscription in subscriptions) {
      try {
        // Get additional data from subscription database API
        final enrichmentData = await _getSubscriptionEnrichmentData(subscription.merchantName);
        
        enriched.add(DetectedSubscription(
          merchantName: subscription.merchantName,
          description: subscription.description,
          monthlyAmount: subscription.monthlyAmount,
          frequency: subscription.frequency,
          lastCharge: subscription.lastCharge,
          nextPredictedCharge: subscription.nextPredictedCharge,
          confidence: subscription.confidence,
          category: enrichmentData?.category ?? subscription.category,
          transactions: subscription.transactions,
          cancellationDifficulty: enrichmentData?.cancellationDifficulty ?? subscription.cancellationDifficulty,
          website: enrichmentData?.website ?? subscription.website,
          logoUrl: enrichmentData?.logoUrl ?? subscription.logoUrl,
          cancellationInstructions: enrichmentData?.cancellationInstructions,
          alternativePlans: enrichmentData?.alternativePlans ?? [],
          priceHistory: enrichmentData?.priceHistory ?? [],
        ));
      } catch (e) {
        enriched.add(subscription);
      }
    }
    
    return enriched;
  }

  Future<SubscriptionEnrichmentData?> _getSubscriptionEnrichmentData(String merchantName) async {
    // This would typically call a real API, but for demo we'll simulate
    await Future.delayed(const Duration(milliseconds: 100));
    
    final mockData = {
      'Netflix': SubscriptionEnrichmentData(
        category: SubscriptionCategory.entertainment,
        cancellationDifficulty: CancellationDifficulty.easy,
        website: 'netflix.com',
        cancellationInstructions: 'Go to Account Settings > Membership & Billing > Cancel Membership',
        alternativePlans: [
          AlternativePlan(name: 'Basic', price: 8.99, features: ['1 screen', 'SD quality']),
          AlternativePlan(name: 'Standard', price: 13.99, features: ['2 screens', 'HD quality']),
        ],
        priceHistory: [
          PricePoint(date: DateTime.now().subtract(const Duration(days: 365)), price: 12.99),
          PricePoint(date: DateTime.now().subtract(const Duration(days: 180)), price: 13.99),
        ],
      ),
      'Spotify': SubscriptionEnrichmentData(
        category: SubscriptionCategory.entertainment,
        cancellationDifficulty: CancellationDifficulty.easy,
        website: 'spotify.com',
        cancellationInstructions: 'Go to Account Settings > Subscription > Cancel Premium',
        alternativePlans: [
          AlternativePlan(name: 'Free', price: 0, features: ['Ads', 'Shuffle only']),
          AlternativePlan(name: 'Premium', price: 9.99, features: ['No ads', 'Download music']),
        ],
      ),
    };

    return mockData[merchantName];
  }

  double _calculatePotentialSavings(List<DetectedSubscription> subscriptions) {
    double totalSavings = 0;
    
    for (final subscription in subscriptions) {
      // Calculate potential savings based on various factors
      if (subscription.confidence < 0.5) continue;
      
      // Check if user might not be using the service
      final daysSinceLastCharge = DateTime.now().difference(subscription.lastCharge).inDays;
      final frequencyScore = daysSinceLastCharge / subscription.frequency;
      
      if (frequencyScore > 1.5) {
        // Might be forgotten subscription
        totalSavings += subscription.monthlyAmount * 12;
      } else if (subscription.alternativePlans.isNotEmpty) {
        // Could downgrade
        final cheapestPlan = subscription.alternativePlans.reduce((a, b) => a.price < b.price ? a : b);
        totalSavings += (subscription.monthlyAmount - cheapestPlan.price) * 12;
      }
    }
    
    return totalSavings;
  }

  List<NextCharge> _predictNextCharges(List<DetectedSubscription> subscriptions) {
    final nextCharges = <NextCharge>[];
    
    for (final subscription in subscriptions) {
      if (subscription.nextPredictedCharge.isAfter(DateTime.now())) {
        nextCharges.add(NextCharge(
          merchantName: subscription.merchantName,
          amount: subscription.monthlyAmount,
          predictedDate: subscription.nextPredictedCharge,
          confidence: subscription.confidence,
        ));
      }
    }
    
    nextCharges.sort((a, b) => a.predictedDate.compareTo(b.predictedDate));
    return nextCharges.take(10).toList();
  }

  List<SubscriptionInsight> _generateInsights(List<DetectedSubscription> subscriptions) {
    final insights = <SubscriptionInsight>[];
    
    // Total monthly spending
    final totalMonthly = subscriptions.fold(0.0, (sum, sub) => sum + sub.monthlyAmount);
    insights.add(SubscriptionInsight(
      type: InsightType.spending,
      title: 'Monthly Subscription Spending',
      description: 'You spend \$${totalMonthly.toStringAsFixed(2)} per month on subscriptions',
      impact: totalMonthly,
      priority: InsightPriority.high,
    ));

    // Unused subscriptions
    final unusedSubs = subscriptions.where((sub) {
      final daysSinceLastCharge = DateTime.now().difference(sub.lastCharge).inDays;
      return daysSinceLastCharge > sub.frequency * 2;
    }).toList();

    if (unusedSubs.isNotEmpty) {
      final unusedTotal = unusedSubs.fold(0.0, (sum, sub) => sum + sub.monthlyAmount);
      insights.add(SubscriptionInsight(
        type: InsightType.waste,
        title: 'Potentially Unused Subscriptions',
        description: 'You might be paying \$${unusedTotal.toStringAsFixed(2)}/month for unused services',
        impact: unusedTotal * 12,
        priority: InsightPriority.high,
        actionable: true,
        action: 'Review and cancel unused subscriptions',
      ));
    }

    // Price increases
    final priceIncreaseSubs = subscriptions.where((sub) => 
      sub.priceHistory.isNotEmpty && sub.priceHistory.last.price < sub.monthlyAmount
    ).toList();

    if (priceIncreaseSubs.isNotEmpty) {
      insights.add(SubscriptionInsight(
        type: InsightType.alert,
        title: 'Recent Price Increases',
        description: '${priceIncreaseSubs.length} subscriptions have increased in price',
        impact: 0,
        priority: InsightPriority.medium,
        actionable: true,
        action: 'Consider alternative plans or services',
      ));
    }

    return insights;
  }

  // Helper methods
  bool _isCacheValid() {
    if (_lastAnalysis == null) return false;
    return DateTime.now().difference(_lastAnalysis!) < _cacheExpiry;
  }

  String _normalizeDescription(String description) {
    return description.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();
  }

  bool _isRecurringFrequency(List<Transaction> transactions, int expectedFrequency) {
    if (transactions.length < 2) return false;
    
    final intervals = <int>[];
    for (int i = 1; i < transactions.length; i++) {
      final daysDiff = transactions[i].date.difference(transactions[i-1].date).inDays;
      intervals.add(daysDiff);
    }
    
    final averageInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    return (averageInterval - expectedFrequency).abs() <= 5;
  }

  int _calculateFrequency(List<Transaction> transactions) {
    if (transactions.length < 2) return 30;
    
    final intervals = <int>[];
    for (int i = 1; i < transactions.length; i++) {
      final daysDiff = transactions[i].date.difference(transactions[i-1].date).inDays;
      intervals.add(daysDiff);
    }
    
    return (intervals.reduce((a, b) => a + b) / intervals.length).round();
  }

  DateTime _predictNextCharge(List<Transaction> transactions) {
    final frequency = _calculateFrequency(transactions);
    return transactions.last.date.add(Duration(days: frequency));
  }

  SubscriptionCategory _categorizeSubscription(String key) {
    if (['netflix', 'hulu', 'disney', 'spotify'].contains(key)) {
      return SubscriptionCategory.entertainment;
    } else if (['adobe', 'microsoft', 'google'].contains(key)) {
      return SubscriptionCategory.productivity;
    } else if (['gym'].contains(key)) {
      return SubscriptionCategory.health;
    }
    return SubscriptionCategory.unknown;
  }

  CancellationDifficulty _assessCancellationDifficulty(String key) {
    final easyToCancel = ['netflix', 'spotify', 'hulu', 'disney'];
    final hardToCancel = ['gym', 'cable', 'phone'];
    
    if (easyToCancel.contains(key)) return CancellationDifficulty.easy;
    if (hardToCancel.contains(key)) return CancellationDifficulty.hard;
    return CancellationDifficulty.medium;
  }

  // Public methods for subscription management
  Future<bool> markAsReviewed(String merchantName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool('reviewed_$merchantName', true);
  }

  Future<bool> markAsCancelled(String merchantName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool('cancelled_$merchantName', true);
  }

  Future<void> clearCache() async {
    _cachedSubscriptions = null;
    _lastAnalysis = null;
  }
}

// Data classes
class SubscriptionPattern {
  final List<String> keywords;
  final List<double> amountRange;
  final int frequency;
  final double confidence;

  const SubscriptionPattern({
    required this.keywords,
    required this.amountRange,
    required this.frequency,
    required this.confidence,
  });
}

class DetectedSubscription {
  final String merchantName;
  final String description;
  final double monthlyAmount;
  final int frequency;
  final DateTime lastCharge;
  final DateTime nextPredictedCharge;
  final double confidence;
  final SubscriptionCategory category;
  final List<Transaction> transactions;
  final CancellationDifficulty cancellationDifficulty;
  final String? website;
  final String? logoUrl;
  final String? cancellationInstructions;
  final List<AlternativePlan> alternativePlans;
  final List<PricePoint> priceHistory;

  const DetectedSubscription({
    required this.merchantName,
    required this.description,
    required this.monthlyAmount,
    required this.frequency,
    required this.lastCharge,
    required this.nextPredictedCharge,
    required this.confidence,
    required this.category,
    required this.transactions,
    required this.cancellationDifficulty,
    this.website,
    this.logoUrl,
    this.cancellationInstructions,
    this.alternativePlans = const [],
    this.priceHistory = const [],
  });

  double get annualAmount => monthlyAmount * 12;
  int get daysSinceLastCharge => DateTime.now().difference(lastCharge).inDays;
  bool get isLikelyActive => daysSinceLastCharge <= frequency * 1.5;
}

class SubscriptionAnalysis {
  final List<DetectedSubscription> detectedSubscriptions;
  final double potentialSavings;
  final List<NextCharge> nextCharges;
  final List<SubscriptionInsight> insights;

  const SubscriptionAnalysis({
    required this.detectedSubscriptions,
    required this.potentialSavings,
    required this.nextCharges,
    required this.insights,
  });

  double get totalMonthlySpending => detectedSubscriptions.fold(0.0, (sum, sub) => sum + sub.monthlyAmount);
  double get totalAnnualSpending => totalMonthlySpending * 12;
  int get activeSubscriptionCount => detectedSubscriptions.where((sub) => sub.isLikelyActive).length;
}

class NextCharge {
  final String merchantName;
  final double amount;
  final DateTime predictedDate;
  final double confidence;

  const NextCharge({
    required this.merchantName,
    required this.amount,
    required this.predictedDate,
    required this.confidence,
  });

  int get daysUntilCharge => predictedDate.difference(DateTime.now()).inDays;
}

class SubscriptionInsight {
  final InsightType type;
  final String title;
  final String description;
  final double impact;
  final InsightPriority priority;
  final bool actionable;
  final String? action;

  const SubscriptionInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.impact,
    required this.priority,
    this.actionable = false,
    this.action,
  });
}

class SubscriptionEnrichmentData {
  final SubscriptionCategory category;
  final CancellationDifficulty cancellationDifficulty;
  final String? website;
  final String? logoUrl;
  final String? cancellationInstructions;
  final List<AlternativePlan> alternativePlans;
  final List<PricePoint> priceHistory;

  const SubscriptionEnrichmentData({
    required this.category,
    required this.cancellationDifficulty,
    this.website,
    this.logoUrl,
    this.cancellationInstructions,
    this.alternativePlans = const [],
    this.priceHistory = const [],
  });
}

class AlternativePlan {
  final String name;
  final double price;
  final List<String> features;

  const AlternativePlan({
    required this.name,
    required this.price,
    required this.features,
  });
}

class PricePoint {
  final DateTime date;
  final double price;

  const PricePoint({
    required this.date,
    required this.price,
  });
}

enum SubscriptionCategory {
  entertainment,
  productivity,
  health,
  finance,
  shopping,
  news,
  education,
  unknown,
}

enum CancellationDifficulty {
  easy,
  medium,
  hard,
}

enum InsightType {
  spending,
  savings,
  waste,
  alert,
  opportunity,
}

enum InsightPriority {
  low,
  medium,
  high,
  critical,
}