import 'dart:io';
import 'package:csv/csv.dart';
import 'package:finsight/models/account_balance.dart';
import 'package:finsight/models/checking_account.dart';
import 'package:finsight/models/monthly_spending.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/models/credit_card.dart';
import 'package:finsight/services/plaid_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class DataService {
  static const String initialAssetPath = 'assets/data/transactions.csv';
  final PlaidService _plaidService = PlaidService();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/transactions.csv');
  }

  Future<void> _initializeLocalFile() async {
    final file = await _localFile;
    final exists = await file.exists();

    if (!exists) {
      final String initialData = await rootBundle.loadString(initialAssetPath);
      await file.writeAsString(initialData);
    }
  }

  Future<void> appendTransaction(Transaction transaction) async {
    try {
      final file = await _localFile;

      final row = [
        DateFormat('yyyy-MM-dd').format(transaction.date),
        transaction.description,
        transaction.category,
        transaction.amount.toString(),
        transaction.account,
        transaction.transactionType,
        transaction.cardId ?? '',
        transaction.isPersonal.toString(),
        transaction.id ?? '',
        transaction.merchantName ?? '',
        transaction.merchantLogoUrl ?? '',
        transaction.merchantWebsite ?? '',
        transaction.location ?? '',
        transaction.confidence?.toString() ?? '',
        transaction.isRecurring.toString(),
        transaction.paymentMethod ?? '',
      ].map((field) => '"${field.replaceAll('"', '""')}"').join(',');

      await file.writeAsString('$row\n', mode: FileMode.append);
    } catch (e) {
      print('Error appending transaction: $e');
      throw Exception('Failed to save transaction');
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      final file = await _localFile;
      final lines = await file.readAsLines();

      final updatedLines = lines.where((line) {
        final fields =
            const CsvToListConverter().convert(line).firstOrNull ?? [];
        return fields.length < 9 || fields[8].toString() != id;
      }).toList();

      await file.writeAsString(updatedLines.join('\n') + '\n');
    } catch (e) {
      print('Error deleting transaction: $e');
      throw Exception('Failed to delete transaction');
    }
  }

  // Get transactions - prioritizes Plaid enriched data when available
  Future<List<Transaction>> getTransactions({BuildContext? context}) async {
    List<Transaction> allTransactions = [];

    // First, try to get Plaid transactions if connected
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      if (hasPlaidConnection && context != null) {
        final plaidTransactions = await _plaidService.fetchTransactions(
          context: context,
          startDate: DateTime.now().subtract(const Duration(days: 365)),
          endDate: DateTime.now(),
        );
        allTransactions.addAll(plaidTransactions);
        print('Loaded ${plaidTransactions.length} enriched Plaid transactions');
      }
    } catch (e) {
      print('Could not load Plaid transactions: $e');
    }

    // Then get local/manual transactions
    try {
      await _initializeLocalFile();
      final file = await _localFile;
      final String data = await file.readAsString();

      List<List<dynamic>> csvTable = const CsvToListConverter().convert(
        data,
        eol: '\n',
        fieldDelimiter: ',',
      );

      if (csvTable.length > 1) {
        for (var i = 1; i < csvTable.length; i++) {
          try {
            var row = csvTable[i];
            if (row.length >= 6) {
              allTransactions.add(Transaction(
                date: DateTime.parse(row[0].toString()),
                description: row[1].toString(),
                category: row[2].toString(),
                amount: double.parse(row[3].toString()),
                account: row[4].toString(),
                transactionType: row[5].toString(),
                cardId: row.length >= 7 ? row[6].toString() : null,
                isPersonal: row.length >= 8
                    ? row[7].toString().toLowerCase() == 'true'
                    : false,
                id: row.length >= 9 ? row[8].toString() : null,
                merchantName: row.length >= 10 ? row[9].toString() : null,
                merchantLogoUrl: row.length >= 11 ? row[10].toString() : null,
                merchantWebsite: row.length >= 12 ? row[11].toString() : null,
                location: row.length >= 13 ? row[12].toString() : null,
                confidence: row.length >= 14 && row[13].toString().isNotEmpty
                    ? double.tryParse(row[13].toString())
                    : null,
                isRecurring: row.length >= 15
                    ? row[14].toString().toLowerCase() == 'true'
                    : false,
                paymentMethod: row.length >= 16 ? row[15].toString() : null,
              ));
            }
          } catch (e) {
            print('Error parsing row $i: $e');
            continue;
          }
        }
      }
    } catch (e) {
      print('Error loading local transactions: $e');
    }

    return allTransactions;
  }

  // Get account balances - uses Plaid when available
  Future<List<AccountBalance>> getAccountBalances({BuildContext? context}) async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      if (hasPlaidConnection) {
        // Use real Plaid data
        final balances = await _plaidService.getAccountBalances();
        final now = DateTime.now();
        
        return [
          AccountBalance(
            date: now,
            checking: balances['checking'] ?? 0,
            creditCardBalance: balances['creditCardBalance'] ?? 0,
            savings: balances['savings'] ?? 0,
            investmentAccount: balances['investmentAccount'] ?? 0,
            netWorth: balances['netWorth'] ?? 0,
          )
        ];
      } else {
        // Fall back to static data
        return await _getStaticAccountBalances();
      }
    } catch (e) {
      print('Error loading account balances: $e');
      return await _getStaticAccountBalances();
    }
  }

  Future<List<AccountBalance>> _getStaticAccountBalances() async {
    try {
      final String data =
          await rootBundle.loadString('assets/data/account_balances.csv');

      List<List<dynamic>> csvTable = const CsvToListConverter().convert(
        data,
        eol: '\n',
        fieldDelimiter: ',',
      );

      List<AccountBalance> balances = [];
      if (csvTable.length > 1) {
        for (var i = 1; i < csvTable.length; i++) {
          try {
            var row = csvTable[i];
            if (row.length >= 6) {
              balances.add(AccountBalance(
                date: DateTime.parse(row[0].toString()),
                checking: double.parse(row[1].toString()),
                creditCardBalance: double.parse(row[2].toString()),
                savings: double.parse(row[3].toString()),
                investmentAccount: double.parse(row[4].toString()),
                netWorth: double.parse(row[5].toString()),
              ));
            }
          } catch (e) {
            print('Error parsing row $i: $e');
            continue;
          }
        }
      }

      return balances;
    } catch (e) {
      print('Error loading static account balances: $e');
      return [];
    }
  }

  // Get monthly spending - processes from real transaction data when Plaid is available
  Future<List<MonthlySpending>> getMonthlySpending({BuildContext? context}) async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      if (hasPlaidConnection && context != null) {
        // Process real transaction data into monthly spending
        return await _getMonthlySpendingFromTransactions(context: context);
      } else {
        // Fall back to static data
        return await _getStaticMonthlySpending();
      }
    } catch (e) {
      print('Error loading monthly spending: $e');
      return await _getStaticMonthlySpending();
    }
  }

  Future<List<MonthlySpending>> _getMonthlySpendingFromTransactions({BuildContext? context}) async {
    try {
      final transactions = await getTransactions(context: context);
      
      if (transactions.isEmpty) {
        print('No transactions available for monthly spending calculation');
        return await _getStaticMonthlySpending();
      }
      
      // Group transactions by month
      final Map<String, List<Transaction>> transactionsByMonth = {};
      
      for (final transaction in transactions) {
        final monthKey = DateFormat('yyyy-MM').format(transaction.date);
        if (!transactionsByMonth.containsKey(monthKey)) {
          transactionsByMonth[monthKey] = [];
        }
        transactionsByMonth[monthKey]!.add(transaction);
      }

      // Convert to MonthlySpending objects
      final List<MonthlySpending> result = [];
      
      transactionsByMonth.forEach((key, txList) {
        final date = DateFormat('yyyy-MM').parse(key);
        
        // Calculate spending by category
        double groceries = 0;
        double utilities = 0;
        double rent = 0;
        double transportation = 0;
        double entertainment = 0;
        double diningOut = 0;
        double shopping = 0;
        double healthcare = 0;
        double insurance = 0;
        double miscellaneous = 0;
        double totalIncome = 0;

        for (final tx in txList) {
          if (tx.transactionType.toLowerCase() == 'credit') {
            totalIncome += tx.amount;
          } else {
            // Categorize spending - including Subscriptions category
            switch (tx.category) {
              case 'Groceries':
                groceries += tx.amount;
                break;
              case 'Utilities':
                utilities += tx.amount;
                break;
              case 'Rent':
                rent += tx.amount;
                break;
              case 'Transportation':
                transportation += tx.amount;
                break;
              case 'Entertainment':
                entertainment += tx.amount;
                break;
              case 'Dining Out':
                diningOut += tx.amount;
                break;
              case 'Shopping':
                shopping += tx.amount;
                break;
              case 'Healthcare':
                healthcare += tx.amount;
                break;
              case 'Insurance':
                insurance += tx.amount;
                break;
              case 'Subscriptions':
                // Add subscriptions to miscellaneous since MonthlySpending model doesn't have it
                miscellaneous += tx.amount;
                break;
              default:
                miscellaneous += tx.amount;
                break;
            }
          }
        }

        result.add(MonthlySpending(
          date: date,
          groceries: groceries,
          utilities: utilities,
          rent: rent,
          transportation: transportation,
          entertainment: entertainment,
          diningOut: diningOut,
          shopping: shopping,
          healthcare: healthcare,
          insurance: insurance,
          miscellaneous: miscellaneous,
          earnings: totalIncome > 0 ? totalIncome : null,
        ));
      });

      // Sort chronologically
      result.sort((a, b) => a.date.compareTo(b.date));
      
      print('Generated ${result.length} months of spending data from ${transactions.length} enriched transactions');
      return result;
    } catch (e) {
      print('Error processing transactions to monthly spending: $e');
      return await _getStaticMonthlySpending();
    }
  }

  Future<List<MonthlySpending>> _getStaticMonthlySpending() async {
    try {
      final String data = await rootBundle
          .loadString('assets/data/monthly_spending_categories.csv');

      List<List<dynamic>> csvTable = const CsvToListConverter().convert(
        data,
        eol: '\n',
        fieldDelimiter: ',',
        shouldParseNumbers: false,
      );

      List<MonthlySpending> monthlySpending = [];

      if (csvTable.isEmpty) {
        print('Error: CSV table is empty');
        return [];
      }

      for (var i = 1; i < csvTable.length; i++) {
        try {
          var row = csvTable[i];
          if (row.length >= 12) {
            monthlySpending.add(MonthlySpending(
              date: DateFormat('yyyy-MM').parse(row[0].toString().trim()),
              groceries: _parseDouble(row[1].toString().trim()),
              utilities: _parseDouble(row[2].toString().trim()),
              rent: _parseDouble(row[3].toString().trim()),
              transportation: _parseDouble(row[4].toString().trim()),
              entertainment: _parseDouble(row[5].toString().trim()),
              diningOut: _parseDouble(row[6].toString().trim()),
              shopping: _parseDouble(row[7].toString().trim()),
              healthcare: _parseDouble(row[8].toString().trim()),
              insurance: _parseDouble(row[9].toString().trim()),
              miscellaneous: _parseDouble(row[10].toString().trim()),
              earnings: _parseDouble(row[11].toString().trim()),
            ));
          }
        } catch (e) {
          print('Error parsing row $i: $e');
          continue;
        }
      }

      return monthlySpending;
    } catch (e) {
      print('Error loading static monthly spending: $e');
      return [];
    }
  }

  double _parseDouble(String value) {
    try {
      return double.parse(value);
    } catch (e) {
      print('Error parsing double value "$value": $e');
      return 0.0;
    }
  }

  // Get checking accounts - uses Plaid when available
  Future<List<CheckingAccount>> getCheckingAccounts({BuildContext? context}) async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      if (hasPlaidConnection && context != null) {
        final accounts = await _plaidService.getAccounts(context);
        final checkingAccounts = accounts
            .where((account) => 
                account['type'] == 'depository' ||
                (account['subtype'] != null && 
                 ['checking', 'savings'].contains(account['subtype'].toString().toLowerCase())))
            .map((account) => CheckingAccount(
                  name: account['name'] ?? 'Account',
                  accountNumber: '****${account['mask'] ?? '0000'}',
                  balance: (account['balance']['current'] ?? 0).toDouble(),
                  type: account['subtype'] ?? 'checking',
                  bankName: account['institution'] ?? 'Bank',
                ))
            .toList();
        
        return checkingAccounts;
      } else {
        return await _getStaticCheckingAccounts();
      }
    } catch (e) {
      print('Error loading checking accounts: $e');
      return await _getStaticCheckingAccounts();
    }
  }

  Future<List<CheckingAccount>> _getStaticCheckingAccounts() async {
    try {
      final String data =
          await rootBundle.loadString('assets/data/checking_accounts.csv');
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(
        data,
        eol: '\n',
        fieldDelimiter: ',',
      );

      List<CheckingAccount> accounts = [];
      if (csvTable.length > 1) {
        for (var i = 1; i < csvTable.length; i++) {
          var row = csvTable[i];
          accounts.add(CheckingAccount(
            name: row[0].toString(),
            accountNumber: row[1].toString(),
            balance: double.parse(row[2].toString()),
            type: row[3].toString(),
            bankName: row[4].toString(),
          ));
        }
      }

      return accounts;
    } catch (e) {
      print('Error loading static checking accounts: $e');
      return [];
    }
  }

  // Get credit cards - uses Plaid when available
  Future<List<CreditCard>> getCreditCards({BuildContext? context}) async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      if (hasPlaidConnection && context != null) {
        final accounts = await _plaidService.getAccounts(context);
        final creditCards = accounts
            .where((account) => 
                account['type'] == 'credit' ||
                (account['subtype'] != null && 
                 ['credit card', 'credit'].contains(account['subtype'].toString().toLowerCase())))
            .map((account) => CreditCard(
                  name: account['name'] ?? 'Credit Card',
                  lastFour: account['mask'] ?? '0000',
                  balance: (account['balance']['current'] ?? 0).toDouble().abs(),
                  creditLimit: (account['balance']['limit'] ?? 1000).toDouble(),
                  apr: 19.99, // Default APR since Plaid doesn't provide this
                  bankName: account['institution'] ?? 'Bank',
                ))
            .toList();
        
        return creditCards;
      } else {
        return await _getStaticCreditCards();
      }
    } catch (e) {
      print('Error loading credit cards: $e');
      return await _getStaticCreditCards();
    }
  }

  Future<List<CreditCard>> _getStaticCreditCards() async {
    try {
      final String data =
          await rootBundle.loadString('assets/data/credit_cards.csv');
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(
        data,
        eol: '\n',
        fieldDelimiter: ',',
      );

      List<CreditCard> cards = [];
      if (csvTable.length > 1) {
        for (var i = 1; i < csvTable.length; i++) {
          var row = csvTable[i];
          cards.add(CreditCard(
            name: row[0].toString(),
            lastFour: row[1].toString(),
            balance: double.parse(row[2].toString()),
            creditLimit: double.parse(row[3].toString()),
            apr: double.parse(row[4].toString()),
            bankName: row[5].toString(),
          ));
        }
      }

      return cards;
    } catch (e) {
      print('Error loading static credit cards: $e');
      return [];
    }
  }

  Future<double> getNetCash({BuildContext? context}) async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      if (hasPlaidConnection) {
        final balances = await _plaidService.getAccountBalances();
        return (balances['checking'] ?? 0) + 
               (balances['savings'] ?? 0) - 
               (balances['creditCardBalance'] ?? 0);
      } else {
        final checkingAccounts = await _getStaticCheckingAccounts();
        final creditCards = await _getStaticCreditCards();

        double totalChecking =
            checkingAccounts.fold(0, (sum, account) => sum + account.balance);
        double totalCredit = creditCards.fold(0, (sum, card) => sum + card.balance);

        return totalChecking - totalCredit;
      }
    } catch (e) {
      print('Error calculating net cash: $e');
      return 0;
    }
  }

  // Helper method to check if we should use Plaid data
  Future<bool> shouldUsePlaidData() async {
    try {
      return await _plaidService.hasPlaidConnection();
    } catch (e) {
      return false;
    }
  }

  // Get credit score data - Enhanced with real-time estimates when Plaid is connected
  Future<List<Map<String, dynamic>>> getCreditScoreHistory({BuildContext? context}) async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      if (hasPlaidConnection) {
        // When connected to Plaid, generate more realistic credit score based on financial health
        final balances = await _plaidService.getAccountBalances();
        final transactions = await getTransactions(context: context);
        
        // Calculate estimated credit score based on financial behavior
        int estimatedScore = await _calculateEstimatedCreditScore(balances, transactions);
        
        // Generate historical data with the current estimated score
        final baseHistory = await _getStaticCreditScoreHistory();
        
        // Adjust the most recent entries to be closer to estimated score
        if (baseHistory.isNotEmpty) {
          final latestEntry = baseHistory.last;
          latestEntry['score'] = estimatedScore;
          
          // Gradually adjust previous months to create a trend
          for (int i = baseHistory.length - 2; i >= baseHistory.length - 4 && i >= 0; i--) {
            final variance = (estimatedScore * 0.05).round(); // 5% variance
            baseHistory[i]['score'] = estimatedScore + 
                ((baseHistory.length - 1 - i) * variance ~/ 3) * (i % 2 == 0 ? -1 : 1);
          }
        }
        
        return baseHistory;
      } else {
        return await _getStaticCreditScoreHistory();
      }
    } catch (e) {
      print('Error loading credit score history: $e');
      return await _getStaticCreditScoreHistory();
    }
  }

  Future<int> _calculateEstimatedCreditScore(Map<String, double> balances, List<Transaction> transactions) async {
    // Base score
    int baseScore = 650;
    
    // Factor 1: Credit utilization (30% of score)
    double creditBalance = balances['creditCardBalance'] ?? 0;
    if (creditBalance > 0) {
      // Assume average credit limit based on balance (conservative estimate)
      double estimatedCreditLimit = creditBalance * 4; // Assume 25% utilization
      double utilization = creditBalance / estimatedCreditLimit;
      
      if (utilization < 0.1) {
        baseScore += 50; // Excellent utilization
      } else if (utilization < 0.3) {
        baseScore += 20; // Good utilization
      } else if (utilization > 0.7) {
        baseScore -= 30; // High utilization
      }
    }
    
    // Factor 2: Account balance stability (20% of score)
    double totalAssets = (balances['checking'] ?? 0) + (balances['savings'] ?? 0);
    if (totalAssets > 10000) {
      baseScore += 30; // Strong financial position
    } else if (totalAssets > 5000) {
      baseScore += 15; // Moderate financial position
    } else if (totalAssets < 1000) {
      baseScore -= 15; // Weak financial position
    }
    
    // Factor 3: Transaction patterns (10% of score)
    if (transactions.length > 50) {
      // Regular transaction activity
      baseScore += 10;
      
      // Check for consistent income
      final incomeTransactions = transactions.where((t) => t.transactionType == 'Credit').toList();
      if (incomeTransactions.length > 4) {
        baseScore += 15; // Regular income
      }
      
      // Check for subscription management (positive for having subscriptions under control)
      final subscriptions = transactions.where((t) => t.isLikelySubscription).toList();
      final avgMonthlySubscriptions = subscriptions.length / 12;
      if (avgMonthlySubscriptions < 10) {
        baseScore += 10; // Good subscription management
      } else if (avgMonthlySubscriptions > 20) {
        baseScore -= 10; // Too many subscriptions
      }
    }
    
    // Ensure score is within realistic range
    return baseScore.clamp(300, 850);
  }

  Future<List<Map<String, dynamic>>> _getStaticCreditScoreHistory() async {
    try {
      // For now, return static data since Plaid credit score requires special access
      final String data =
          await rootBundle.loadString('assets/data/credit_score.csv');
      
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(
        data,
        eol: '\n',
        fieldDelimiter: ',',
      );

      List<Map<String, dynamic>> scores = [];
      if (csvTable.length > 1) {
        for (var i = 1; i < csvTable.length; i++) {
          try {
            var row = csvTable[i];
            if (row.length >= 6) {
              scores.add({
                'date': DateTime.parse(row[0].toString()),
                'score': int.parse(row[1].toString()),
                'on_time_payments': int.parse(row[2].toString()),
                'credit_utilization': int.parse(row[3].toString()),
                'credit_age_years': double.parse(row[4].toString()),
                'new_credit_inquiries': int.parse(row[5].toString()),
              });
            }
          } catch (e) {
            print('Error parsing credit score row $i: $e');
            continue;
          }
        }
      }

      return scores;
    } catch (e) {
      print('Error loading credit score history: $e');
      return [];
    }
  }

  // Get insights based on spending patterns - Enhanced with enriched transaction analysis
  Future<List<Map<String, dynamic>>> getSpendingInsights({BuildContext? context}) async {
    try {
      final transactions = await getTransactions(context: context);
      final insights = <Map<String, dynamic>>[];
      
      if (transactions.isEmpty) return insights;

      // Analyze current month vs previous month
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      final lastMonth = DateTime(now.year, now.month - 1);

      final currentMonthTransactions = transactions.where((t) {
        return t.date.year == currentMonth.year && 
               t.date.month == currentMonth.month &&
               t.transactionType == 'Debit';
      }).toList();

      final lastMonthTransactions = transactions.where((t) {
        return t.date.year == lastMonth.year && 
               t.date.month == lastMonth.month &&
               t.transactionType == 'Debit';
      }).toList();

      // Calculate spending by category for both months
      Map<String, double> currentSpending = {};
      Map<String, double> lastSpending = {};

      for (final transaction in currentMonthTransactions) {
        currentSpending[transaction.category] = 
            (currentSpending[transaction.category] ?? 0) + transaction.amount;
      }

      for (final transaction in lastMonthTransactions) {
        lastSpending[transaction.category] = 
            (lastSpending[transaction.category] ?? 0) + transaction.amount;
      }

      // Generate insights based on enriched data
      currentSpending.forEach((category, currentAmount) {
        final lastAmount = lastSpending[category] ?? 0;
        if (lastAmount > 0) {
          final change = ((currentAmount - lastAmount) / lastAmount) * 100;
          
          if (change > 20) {
            insights.add({
              'type': 'warning',
              'title': 'High $category Spending',
              'description': 'You spent ${change.toStringAsFixed(1)}% more on $category this month.',
              'category': category,
              'change': change,
            });
          } else if (change < -20) {
            insights.add({
              'type': 'positive',
              'title': 'Reduced $category Spending',
              'description': 'You spent ${change.abs().toStringAsFixed(1)}% less on $category this month.',
              'category': category,
              'change': change,
            });
          }
        }
      });

      // Enriched insights using Plaid data
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      if (hasPlaidConnection) {
        // Subscription analysis with enriched data
        final subscriptionTransactions = transactions.where((t) => t.isLikelySubscription).toList();
        if (subscriptionTransactions.isNotEmpty) {
          final monthlySubscriptionCost = subscriptionTransactions
              .where((t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
              .fold(0.0, (sum, t) => sum + t.amount);
          
          if (monthlySubscriptionCost > 100) {
            insights.add({
              'type': 'info',
              'title': 'Subscription Review Needed',
              'description': 'You\'re spending \$${monthlySubscriptionCost.toStringAsFixed(0)}/month on subscriptions. Consider reviewing them.',
              'category': 'Subscriptions',
              'amount': monthlySubscriptionCost,
            });
          }
        }

        // Merchant concentration analysis
        final merchantSpending = <String, double>{};
        for (final transaction in currentMonthTransactions) {
          final merchant = transaction.merchantName ?? transaction.description;
          merchantSpending[merchant] = (merchantSpending[merchant] ?? 0) + transaction.amount;
        }
        
        if (merchantSpending.isNotEmpty) {
          final topMerchant = merchantSpending.entries.reduce((a, b) => a.value > b.value ? a : b);
          if (topMerchant.value > 500) {
            insights.add({
              'type': 'info',
              'title': 'High Merchant Spending',
              'description': 'You spent \$${topMerchant.value.toStringAsFixed(0)} at ${topMerchant.key} this month.',
              'category': 'Merchant Analysis',
              'merchant': topMerchant.key,
              'amount': topMerchant.value,
            });
          }
        }

        // Location-based insights
        final locationTransactions = transactions.where((t) => t.location != null).toList();
        if (locationTransactions.isNotEmpty) {
          final locationSpending = <String, double>{};
          for (final transaction in locationTransactions) {
            final location = transaction.formattedLocation!;
            locationSpending[location] = (locationSpending[location] ?? 0) + transaction.amount;
          }
          
          if (locationSpending.length > 1) {
            final topLocation = locationSpending.entries.reduce((a, b) => a.value > b.value ? a : b);
            insights.add({
              'type': 'info',
              'title': 'Top Spending Location',
              'description': 'Most spending this month was in ${topLocation.key} (\$${topLocation.value.toStringAsFixed(0)}).',
              'category': 'Location Analysis',
              'location': topLocation.key,
              'amount': topLocation.value,
            });
          }
        }

        // Confidence-based insights
        final lowConfidenceTransactions = transactions
            .where((t) => t.confidence != null && t.confidence! < 0.5)
            .toList();
        
        if (lowConfidenceTransactions.length > 10) {
          insights.add({
            'type': 'info',
            'title': 'Transaction Categorization',
            'description': '${lowConfidenceTransactions.length} transactions have uncertain categorization. Review for accuracy.',
            'category': 'Data Quality',
            'count': lowConfidenceTransactions.length,
          });
        }

        // Large transaction analysis with enriched data
        final largeTransactions = currentMonthTransactions
            .where((t) => t.amount > 500)
            .toList();
        if (largeTransactions.isNotEmpty) {
          insights.add({
            'type': 'info',
            'title': 'Large Purchases',
            'description': 'You made ${largeTransactions.length} large purchase${largeTransactions.length > 1 ? 's' : ''} this month.',
            'category': 'Large Purchases',
            'count': largeTransactions.length,
            'transactions': largeTransactions.map((t) => {
              'merchant': t.merchantName ?? t.description,
              'amount': t.amount,
              'category': t.category,
            }).toList(),
          });
        }
      }

      return insights;
    } catch (e) {
      print('Error generating spending insights: $e');
      return [];
    }
  }
}