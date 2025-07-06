import 'dart:convert';
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
import 'package:shared_preferences/shared_preferences.dart';
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
  static Map<String, List<Map<String, dynamic>>>? _cachedAccounts;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Receipt toggle settings
  static const String _SHOW_SCANNED_RECEIPTS_KEY = 'show_scanned_receipts';
  static bool? _cachedShowScannedReceipts;

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

  // Receipt toggle management
  Future<bool> getShowScannedReceipts() async {
    if (_cachedShowScannedReceipts != null) {
      return _cachedShowScannedReceipts!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedShowScannedReceipts =
          prefs.getBool(_SHOW_SCANNED_RECEIPTS_KEY) ?? true;
      return _cachedShowScannedReceipts!;
    } catch (e) {
      print('Error getting scanned receipts preference: $e');
      return true; // Default to showing scanned receipts
    }
  }

  Future<void> setShowScannedReceipts(bool show) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_SHOW_SCANNED_RECEIPTS_KEY, show);
      _cachedShowScannedReceipts = show;

      // Clear cache to refresh data with new filter
      clearTransactionCache();
    } catch (e) {
      print('Error setting scanned receipts preference: $e');
    }
  }

  // Helper method to check if transaction is from scanned receipt
  bool _isScannedReceipt(Transaction transaction) {
    if (transaction.merchantMetadata == null) return false;
    return transaction.merchantMetadata!['receipt_scanned'] == true;
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
        DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.date),
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
        // FIX: Use json.encode for reliable serialization of metadata
        transaction.merchantMetadata != null
            ? json.encode(transaction.merchantMetadata)
            : '',
      ].map((field) => '"${field.replaceAll('"', '""')}"').join(',');

      await file.writeAsString('$row\n', mode: FileMode.append);

      // Invalidate cache
      clearTransactionCache();
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

      // Invalidate cache
      clearTransactionCache();
    } catch (e) {
      print('Error deleting transaction: $e');
      throw Exception('Failed to delete transaction');
    }
  }

  // Enhanced caching for transactions with receipt filtering
  Future<List<Transaction>> getTransactions({
    BuildContext? context,
    bool forceRefresh = false,
    bool? includeScannedReceipts,
  }) async {
    // Get filter preference
    final showScannedReceipts =
        includeScannedReceipts ?? await getShowScannedReceipts();

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh &&
        _isCacheValid(_lastTransactionFetch) &&
        _cachedTransactions != null) {
      print(
          'Returning cached transactions (${_cachedTransactions!.length} items)');
      return _filterTransactionsByReceipts(
          _cachedTransactions!, showScannedReceipts);
    }

    List<Transaction> allTransactions = [];

    // First, try to get Plaid transactions if connected
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
        print(
            'Loaded ${plaidTransactions.length} enriched Plaid transactions');
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
              // Parse metadata if present
              Map<String, dynamic>? metadata;
              if (row.length >= 17 && row[16].toString().isNotEmpty) {
                try {
                  // FIX: Use json.decode for reliable parsing
                  metadata =
                      json.decode(row[16].toString()) as Map<String, dynamic>;
                } catch (e) {
                  print('Error parsing metadata for row $i: $e');
                }
              }

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
                merchantLogoUrl:
                    row.length >= 11 ? row[10].toString() : null,
                merchantWebsite:
                    row.length >= 12 ? row[11].toString() : null,
                location: row.length >= 13 ? row[12].toString() : null,
                confidence: row.length >= 14 && row[13].toString().isNotEmpty
                    ? double.tryParse(row[13].toString())
                    : null,
                isRecurring: row.length >= 15
                    ? row[14].toString().toLowerCase() == 'true'
                    : false,
                paymentMethod: row.length >= 16 ? row[15].toString() : null,
                merchantMetadata: metadata,
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

    // Update cache
    _cachedTransactions = allTransactions;
    _lastTransactionFetch = DateTime.now();

    return _filterTransactionsByReceipts(
        allTransactions, showScannedReceipts);
  }

  List<Transaction> _filterTransactionsByReceipts(
      List<Transaction> transactions, bool showScannedReceipts) {
    if (showScannedReceipts) {
      return transactions; // Show all transactions
    } else {
      return transactions.where((t) => !_isScannedReceipt(t)).toList();
    }
  }

  // Get transaction count by type
  Future<Map<String, int>> getTransactionCounts({BuildContext? context}) async {
    final allTransactions =
        await getTransactions(context: context, includeScannedReceipts: true);
    final scannedCount = allTransactions.where(_isScannedReceipt).length;
    final plaidCount =
        allTransactions.where((t) => !t.isPersonal && !_isScannedReceipt(t)).length;
    final manualCount =
        allTransactions.where((t) => t.isPersonal && !_isScannedReceipt(t)).length;

    return {
      'total': allTransactions.length,
      'scanned': scannedCount,
      'plaid': plaidCount,
      'manual': manualCount,
    };
  }

  // Cached account balances
  Future<List<AccountBalance>> getAccountBalances({
    BuildContext? context,
    bool forceRefresh = false,
    bool? includeScannedReceipts,
  }) async {
    if (!forceRefresh &&
        _isCacheValid(_lastBalanceFetch) &&
        _cachedBalances != null) {
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

      // Update cache
      _cachedBalances = balances;
      _lastBalanceFetch = DateTime.now();

      return balances;
    } catch (e) {
      print('Error loading account balances: $e');
      return await _getStaticAccountBalances();
    }
  }

  // Cached monthly spending with receipt filtering
  Future<List<MonthlySpending>> getMonthlySpending({
    BuildContext? context,
    bool forceRefresh = false,
    bool? includeScannedReceipts,
  }) async {
    final showScannedReceipts =
        includeScannedReceipts ?? await getShowScannedReceipts();

    if (!forceRefresh &&
        _isCacheValid(_lastMonthlySpendingFetch) &&
        _cachedMonthlySpending != null) {
      print('Returning cached monthly spending');
      return _cachedMonthlySpending!;
    }

    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();

      List<MonthlySpending> spending;
      if (hasPlaidConnection && context != null) {
        print('Generating fresh monthly spending from transactions...');
        spending = await _getMonthlySpendingFromTransactions(
          context: context,
          includeScannedReceipts: showScannedReceipts,
        );
      } else {
        spending = await _getStaticMonthlySpending();
      }

      // Update cache
      _cachedMonthlySpending = spending;
      _lastMonthlySpendingFetch = DateTime.now();

      return spending;
    } catch (e) {
      print('Error loading monthly spending: $e');
      return await _getStaticMonthlySpending();
    }
  }

  // Cache clearing methods
  static void clearCache() {
    _cachedTransactions = null;
    _cachedBalances = null;
    _cachedMonthlySpending = null;
    _cachedAccounts = null;
    _lastTransactionFetch = null;
    _lastBalanceFetch = null;
    _lastMonthlySpendingFetch = null;
  }

  static void clearTransactionCache() {
    _cachedTransactions = null;
    _lastTransactionFetch = null;
    _cachedMonthlySpending = null;
    _lastMonthlySpendingFetch = null;
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

  Future<List<MonthlySpending>> _getMonthlySpendingFromTransactions({
    BuildContext? context,
    bool includeScannedReceipts = true,
  }) async {
    try {
      final transactions = await getTransactions(
        context: context,
        includeScannedReceipts: includeScannedReceipts,
      );

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

      print(
          'Generated ${result.length} months of spending data from ${transactions.length} transactions');
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

  // ... rest of the existing methods remain the same with receipt filtering support
  Future<List<CheckingAccount>> getCheckingAccounts(
      {BuildContext? context}) async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();

      if (hasPlaidConnection && context != null) {
        final accounts = await _plaidService.getAccounts(context);
        final checkingAccounts = accounts
            .where((account) =>
                account['type'] == 'depository' ||
                (account['subtype'] != null &&
                    ['checking', 'savings'].contains(
                        account['subtype'].toString().toLowerCase())))
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

  Future<List<CreditCard>> getCreditCards({BuildContext? context}) async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();

      if (hasPlaidConnection && context != null) {
        final accounts = await _plaidService.getAccounts(context);
        final creditCards = accounts
            .where((account) =>
                account['type'] == 'credit' ||
                (account['subtype'] != null &&
                    ['credit card', 'credit']
                        .contains(account['subtype'].toString().toLowerCase())))
            .map((account) => CreditCard(
                  name: account['name'] ?? 'Credit Card',
                  lastFour: account['mask'] ?? '0000',
                  balance:
                      (account['balance']['current'] ?? 0).toDouble().abs(),
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
        double totalCredit =
            creditCards.fold(0, (sum, card) => sum + card.balance);

        return totalChecking - totalCredit;
      }
    } catch (e) {
      print('Error calculating net cash: $e');
      return 0;
    }
  }

  Future<bool> shouldUsePlaidData() async {
    try {
      return await _plaidService.hasPlaidConnection();
    } catch (e) {
      return false;
    }
  }

  // Enhanced spending insights with receipt data awareness
  Future<List<Map<String, dynamic>>> getSpendingInsights({
    BuildContext? context,
    bool? includeScannedReceipts,
  }) async {
    try {
      final showScannedReceipts =
          includeScannedReceipts ?? await getShowScannedReceipts();
      final transactions = await getTransactions(
        context: context,
        includeScannedReceipts: showScannedReceipts,
      );
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

      // Add receipt-specific insights
      final scannedReceipts =
          currentMonthTransactions.where(_isScannedReceipt).toList();
      if (scannedReceipts.isNotEmpty) {
        final receiptTotal =
            scannedReceipts.fold(0.0, (sum, t) => sum + t.amount);
        insights.add({
          'type': 'info',
          'title': 'Receipt Scanner Usage',
          'description':
              'You\'ve scanned ${scannedReceipts.length} receipts totaling \$${receiptTotal.toStringAsFixed(0)} this month.',
          'category': 'Receipt Scanning',
          'count': scannedReceipts.length,
          'amount': receiptTotal,
        });
      }

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

      // Generate insights based on spending changes
      currentSpending.forEach((category, currentAmount) {
        final lastAmount = lastSpending[category] ?? 0;
        if (lastAmount > 0) {
          final change = ((currentAmount - lastAmount) / lastAmount) * 100;

          if (change > 20) {
            insights.add({
              'type': 'warning',
              'title': 'High $category Spending',
              'description':
                  'You spent ${change.toStringAsFixed(1)}% more on $category this month.',
              'category': category,
              'change': change,
            });
          } else if (change < -20) {
            insights.add({
              'type': 'positive',
              'title': 'Reduced $category Spending',
              'description':
                  'You spent ${change.abs().toStringAsFixed(1)}% less on $category this month.',
              'category': category,
              'change': change,
            });
          }
        }
      });

      return insights;
    } catch (e) {
      print('Error generating spending insights: $e');
      return [];
    }
  }
}