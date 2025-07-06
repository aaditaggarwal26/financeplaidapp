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
import 'dart:async';

class DataService {
  static const String initialAssetPath = 'assets/data/transactions.csv';
  final PlaidService _plaidService = PlaidService();

  // Caching mechanism
  static List<Transaction>? _cachedTransactions;
  static DateTime? _lastTransactionFetch;
  static List<AccountBalance>? _cachedBalances;
  static DateTime? _lastBalanceFetch;
  static List<MonthlySpending>? _cachedMonthlySpending;
  static DateTime? _lastMonthlySpendingFetch;
  static List<CheckingAccount>? _cachedCheckingAccounts;
  static DateTime? _lastCheckingAccountsFetch;
  static List<CreditCard>? _cachedCreditCards;
  static DateTime? _lastCreditCardsFetch;
  static List<Map<String, dynamic>>? _cachedCreditScoreHistory;
  static DateTime? _lastCreditScoreFetch;
  static List<Map<String, dynamic>>? _cachedSpendingInsights;
  static DateTime? _lastSpendingInsightsFetch;
  
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Singleton pattern for better performance
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/transactions.csv');
  }

  bool _isCacheValid(DateTime? lastFetch) {
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheExpiry;
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
      
      // Invalidate relevant caches
      clearTransactionCache();
      clearMonthlySpendingCache();
      clearSpendingInsightsCache();

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
      
      // Invalidate relevant caches
      clearTransactionCache();
      clearMonthlySpendingCache();
      clearSpendingInsightsCache();

    } catch (e) {
      print('Error deleting transaction: $e');
      throw Exception('Failed to delete transaction');
    }
  }

  // Enhanced caching for transactions
  Future<List<Transaction>> getTransactions({BuildContext? context, bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_lastTransactionFetch) && _cachedTransactions != null) {
      print('Returning cached transactions (${_cachedTransactions!.length} items)');
      return _cachedTransactions!;
    }

    List<Transaction> allTransactions = [];

    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      if (hasPlaidConnection && context != null) {
        print('Fetching fresh Plaid transactions...');
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

    _cachedTransactions = allTransactions;
    _lastTransactionFetch = DateTime.now();

    return allTransactions;
  }

  // Cached account balances
  Future<List<AccountBalance>> getAccountBalances({BuildContext? context, bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_lastBalanceFetch) && _cachedBalances != null) {
      print('Returning cached account balances');
      return _cachedBalances!;
    }

    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      List<AccountBalance> balances;
      if (hasPlaidConnection) {
        print('Fetching fresh Plaid account balances...');
        final plaidBalances = await _plaidService.getAccountBalances();
        final now = DateTime.now();
        
        balances = [
          AccountBalance(
            date: now,
            checking: plaidBalances['checking'] ?? 0,
            creditCardBalance: plaidBalances['creditCardBalance'] ?? 0,
            savings: plaidBalances['savings'] ?? 0,
            investmentAccount: plaidBalances['investmentAccount'] ?? 0,
            netWorth: plaidBalances['netWorth'] ?? 0,
          )
        ];
      } else {
        balances = await _getStaticAccountBalances();
      }

      _cachedBalances = balances;
      _lastBalanceFetch = DateTime.now();
      
      return balances;
    } catch (e) {
      print('Error loading account balances: $e');
      return await _getStaticAccountBalances();
    }
  }

  // Cached monthly spending
  Future<List<MonthlySpending>> getMonthlySpending({BuildContext? context, bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_lastMonthlySpendingFetch) && _cachedMonthlySpending != null) {
      print('Returning cached monthly spending');
      return _cachedMonthlySpending!;
    }

    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      List<MonthlySpending> spending;
      if (hasPlaidConnection && context != null) {
        print('Generating fresh monthly spending from transactions...');
        spending = await _getMonthlySpendingFromTransactions(context: context);
      } else {
        spending = await _getStaticMonthlySpending();
      }

      _cachedMonthlySpending = spending;
      _lastMonthlySpendingFetch = DateTime.now();
      
      return spending;
    } catch (e) {
      print('Error loading monthly spending: $e');
      return await _getStaticMonthlySpending();
    }
  }
  
  // Get checking accounts - uses Plaid when available
  Future<List<CheckingAccount>> getCheckingAccounts({BuildContext? context, bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_lastCheckingAccountsFetch) && _cachedCheckingAccounts != null) {
      print('Returning cached checking accounts');
      return _cachedCheckingAccounts!;
    }
    
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      List<CheckingAccount> accounts;
      
      if (hasPlaidConnection && context != null) {
         print('Fetching fresh Plaid checking accounts...');
        final plaidAccounts = await _plaidService.getAccounts(context);
        accounts = plaidAccounts
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
      } else {
        accounts = await _getStaticCheckingAccounts();
      }
      
      _cachedCheckingAccounts = accounts;
      _lastCheckingAccountsFetch = DateTime.now();
      return accounts;

    } catch (e) {
      print('Error loading checking accounts: $e');
      return await _getStaticCheckingAccounts();
    }
  }

  // Get credit cards - uses Plaid when available
  Future<List<CreditCard>> getCreditCards({BuildContext? context, bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_lastCreditCardsFetch) && _cachedCreditCards != null) {
      print('Returning cached credit cards');
      return _cachedCreditCards!;
    }
    
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      List<CreditCard> cards;

      if (hasPlaidConnection && context != null) {
        print('Fetching fresh Plaid credit cards...');
        final accounts = await _plaidService.getAccounts(context);
        cards = accounts
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
      } else {
        cards = await _getStaticCreditCards();
      }
      
      _cachedCreditCards = cards;
      _lastCreditCardsFetch = DateTime.now();
      return cards;

    } catch (e) {
      print('Error loading credit cards: $e');
      return await _getStaticCreditCards();
    }
  }
  
  Future<double> getNetCash({BuildContext? context}) async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      if (hasPlaidConnection) {
        final balancesList = await getAccountBalances(context: context);
        if (balancesList.isEmpty) return 0;
        final balances = balancesList.first;
        return balances.checking + balances.savings - balances.creditCardBalance;
      } else {
        final checkingAccounts = await getCheckingAccounts(context: context);
        final creditCards = await getCreditCards(context: context);

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

  Future<List<Map<String, dynamic>>> getCreditScoreHistory({BuildContext? context, bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_lastCreditScoreFetch) && _cachedCreditScoreHistory != null) {
      print('Returning cached credit score history');
      return _cachedCreditScoreHistory!;
    }
    
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      List<Map<String, dynamic>> history;

      if (hasPlaidConnection) {
        print('Generating estimated credit score history...');
        final balancesMap = await _plaidService.getAccountBalances();
        final transactions = await getTransactions(context: context);
        
        int estimatedScore = await _calculateEstimatedCreditScore(balancesMap, transactions);
        
        final baseHistory = await _getStaticCreditScoreHistory();
        
        if (baseHistory.isNotEmpty) {
          final latestEntry = baseHistory.last;
          latestEntry['score'] = estimatedScore;
          
          for (int i = baseHistory.length - 2; i >= baseHistory.length - 4 && i >= 0; i--) {
            final variance = (estimatedScore * 0.05).round(); 
            baseHistory[i]['score'] = estimatedScore + 
                ((baseHistory.length - 1 - i) * variance ~/ 3) * (i % 2 == 0 ? -1 : 1);
          }
        }
        history = baseHistory;
      } else {
        history = await _getStaticCreditScoreHistory();
      }
      
      _cachedCreditScoreHistory = history;
      _lastCreditScoreFetch = DateTime.now();
      return history;

    } catch (e) {
      print('Error loading credit score history: $e');
      return await _getStaticCreditScoreHistory();
    }
  }
  
  Future<List<Map<String, dynamic>>> getSpendingInsights({BuildContext? context, bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_lastSpendingInsightsFetch) && _cachedSpendingInsights != null) {
      print('Returning cached spending insights');
      return _cachedSpendingInsights!;
    }
    
    try {
      final transactions = await getTransactions(context: context);
      final insights = <Map<String, dynamic>>[];
      
      if (transactions.isEmpty) return insights;

      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      final lastMonth = DateTime(now.year, now.month - 1);

      final currentMonthTransactions = transactions.where((t) => t.date.year == currentMonth.year && t.date.month == currentMonth.month && t.transactionType != 'Credit').toList();
      final lastMonthTransactions = transactions.where((t) => t.date.year == lastMonth.year && t.date.month == lastMonth.month && t.transactionType != 'Credit').toList();

      Map<String, double> currentSpending = {};
      Map<String, double> lastSpending = {};

      for (final transaction in currentMonthTransactions) {
        currentSpending[transaction.category] = (currentSpending[transaction.category] ?? 0) + transaction.amount;
      }

      for (final transaction in lastMonthTransactions) {
        lastSpending[transaction.category] = (lastSpending[transaction.category] ?? 0) + transaction.amount;
      }

      currentSpending.forEach((category, currentAmount) {
        final lastAmount = lastSpending[category] ?? 0;
        if (lastAmount > 0) {
          final change = ((currentAmount - lastAmount) / lastAmount) * 100;
          
          if (change > 20) {
            insights.add({'type': 'warning', 'title': 'High $category Spending', 'description': 'You spent ${change.toStringAsFixed(1)}% more on $category this month.', 'category': category, 'change': change});
          } else if (change < -20) {
            insights.add({'type': 'positive', 'title': 'Reduced $category Spending', 'description': 'You spent ${change.abs().toStringAsFixed(1)}% less on $category this month.', 'category': category, 'change': change});
          }
        }
      });

      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      if (hasPlaidConnection) {
        final subscriptionTransactions = transactions.where((t) => t.isRecurring).toList(); // Simplified from isLikelySubscription
        if (subscriptionTransactions.isNotEmpty) {
          final monthlySubscriptionCost = subscriptionTransactions.where((t) => t.date.isAfter(now.subtract(const Duration(days: 30)))).fold(0.0, (sum, t) => sum + t.amount);
          if (monthlySubscriptionCost > 100) {
            insights.add({'type': 'info', 'title': 'Subscription Review Needed', 'description': 'You\'re spending \$${monthlySubscriptionCost.toStringAsFixed(0)}/month on subscriptions. Consider reviewing them.', 'category': 'Subscriptions', 'amount': monthlySubscriptionCost});
          }
        }

        final merchantSpending = <String, double>{};
        for (final transaction in currentMonthTransactions) {
          final merchant = transaction.merchantName ?? transaction.description;
          merchantSpending[merchant] = (merchantSpending[merchant] ?? 0) + transaction.amount;
        }
        
        if (merchantSpending.isNotEmpty) {
          final topMerchant = merchantSpending.entries.reduce((a, b) => a.value > b.value ? a : b);
          if (topMerchant.value > 500) {
            insights.add({'type': 'info', 'title': 'High Merchant Spending', 'description': 'You spent \$${topMerchant.value.toStringAsFixed(0)} at ${topMerchant.key} this month.', 'category': 'Merchant Analysis', 'merchant': topMerchant.key, 'amount': topMerchant.value});
          }
        }
      }

      _cachedSpendingInsights = insights;
      _lastSpendingInsightsFetch = DateTime.now();
      return insights;
    } catch (e) {
      print('Error generating spending insights: $e');
      return [];
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


  // Cache clearing methods
  static void clearCache() {
    _cachedTransactions = null;
    _cachedBalances = null;
    _cachedMonthlySpending = null;
    _cachedCheckingAccounts = null;
    _cachedCreditCards = null;
    _cachedCreditScoreHistory = null;
    _cachedSpendingInsights = null;
    
    _lastTransactionFetch = null;
    _lastBalanceFetch = null;
    _lastMonthlySpendingFetch = null;
    _lastCheckingAccountsFetch = null;
    _lastCreditCardsFetch = null;
    _lastCreditScoreFetch = null;
    _lastSpendingInsightsFetch = null;
    
    print('All caches cleared.');
  }

  static void clearTransactionCache() {
    _cachedTransactions = null;
    _lastTransactionFetch = null;
  }

  static void clearMonthlySpendingCache() {
    _cachedMonthlySpending = null;
    _lastMonthlySpendingFetch = null;
  }
  
  static void clearSpendingInsightsCache() {
    _cachedSpendingInsights = null;
    _lastSpendingInsightsFetch = null;
  }

  // --- Private Helper Methods ---

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
            print('Error parsing account balance row $i: $e');
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

  Future<List<MonthlySpending>> _getMonthlySpendingFromTransactions({BuildContext? context}) async {
    try {
      final transactions = await getTransactions(context: context);
      
      if (transactions.isEmpty) {
        print('No transactions available for monthly spending calculation');
        return await _getStaticMonthlySpending();
      }
      
      final Map<String, List<Transaction>> transactionsByMonth = {};
      
      for (final transaction in transactions) {
        final monthKey = DateFormat('yyyy-MM').format(transaction.date);
        if (!transactionsByMonth.containsKey(monthKey)) {
          transactionsByMonth[monthKey] = [];
        }
        transactionsByMonth[monthKey]!.add(transaction);
      }

      final List<MonthlySpending> result = [];
      
      transactionsByMonth.forEach((key, txList) {
        final date = DateFormat('yyyy-MM').parse(key);
        
        double groceries = 0, utilities = 0, rent = 0, transportation = 0, entertainment = 0, diningOut = 0, shopping = 0, healthcare = 0, insurance = 0, miscellaneous = 0, totalIncome = 0;

        for (final tx in txList) {
          if (tx.transactionType.toLowerCase() == 'credit') {
            totalIncome += tx.amount;
          } else {
            switch (tx.category) {
              case 'Groceries': groceries += tx.amount; break;
              case 'Utilities': utilities += tx.amount; break;
              case 'Rent': rent += tx.amount; break;
              case 'Transportation': transportation += tx.amount; break;
              case 'Entertainment': entertainment += tx.amount; break;
              case 'Dining Out': diningOut += tx.amount; break;
              case 'Shopping': shopping += tx.amount; break;
              case 'Healthcare': healthcare += tx.amount; break;
              case 'Insurance': insurance += tx.amount; break;
              case 'Subscriptions': miscellaneous += tx.amount; break;
              default: miscellaneous += tx.amount; break;
            }
          }
        }

        result.add(MonthlySpending(date: date, groceries: groceries, utilities: utilities, rent: rent, transportation: transportation, entertainment: entertainment, diningOut: diningOut, shopping: shopping, healthcare: healthcare, insurance: insurance, miscellaneous: miscellaneous, earnings: totalIncome > 0 ? totalIncome : null));
      });

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
      if (csvTable.isEmpty) return [];

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
          print('Error parsing monthly spending row $i: $e');
          continue;
        }
      }
      return monthlySpending;
    } catch (e) {
      print('Error loading static monthly spending: $e');
      return [];
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

  Future<int> _calculateEstimatedCreditScore(Map<String, double> balances, List<Transaction> transactions) async {
    int baseScore = 650;
    
    double creditBalance = balances['creditCardBalance'] ?? 0;
    if (creditBalance > 0) {
      double estimatedCreditLimit = creditBalance * 4;
      double utilization = creditBalance / estimatedCreditLimit;
      
      if (utilization < 0.1) baseScore += 50;
      else if (utilization < 0.3) baseScore += 20;
      else if (utilization > 0.7) baseScore -= 30;
    }
    
    double totalAssets = (balances['checking'] ?? 0) + (balances['savings'] ?? 0);
    if (totalAssets > 10000) baseScore += 30;
    else if (totalAssets > 5000) baseScore += 15;
    else if (totalAssets < 1000) baseScore -= 15;
    
    if (transactions.length > 50) {
      baseScore += 10;
      final incomeTransactions = transactions.where((t) => t.transactionType == 'Credit').toList();
      if (incomeTransactions.length > 4) baseScore += 15;
      
      final subscriptions = transactions.where((t) => t.isRecurring).toList(); // Simplified from isLikelySubscription
      final avgMonthlySubscriptions = subscriptions.length / 12;
      if (avgMonthlySubscriptions < 10) baseScore += 10;
      else if (avgMonthlySubscriptions > 20) baseScore -= 10;
    }
    
    return baseScore.clamp(300, 850);
  }

  Future<List<Map<String, dynamic>>> _getStaticCreditScoreHistory() async {
    try {
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

  double _parseDouble(String value) {
    try {
      return double.parse(value);
    } catch (e) {
      // print('Error parsing double value "$value": $e');
      return 0.0;
    }
  }
}