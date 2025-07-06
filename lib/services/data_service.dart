import 'dart:io';
import 'package:csv/csv.dart';
import 'package:finsight/models/account_balance.dart';
import 'package:finsight/models/checking_account.dart';
import 'package:finsight/models/monthly_spending.dart';
import 'package:finsight/models/transaction.dart';
import 'package:finsight/models/credit_card.dart';
import 'package:finsight/services/plaid_service.dart';
import 'package:flutter/services.dart';
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

  // Get transactions - prioritizes Plaid data when available
  Future<List<Transaction>> getTransactions() async {
    List<Transaction> allTransactions = [];

    // First, try to get Plaid transactions if connected
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      if (hasPlaidConnection) {
        final plaidTransactions = await _plaidService.fetchTransactions(
          context: _getDummyContext(),
          startDate: DateTime.now().subtract(const Duration(days: 365)),
          endDate: DateTime.now(),
        );
        allTransactions.addAll(plaidTransactions);
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
  Future<List<AccountBalance>> getAccountBalances() async {
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
  Future<List<MonthlySpending>> getMonthlySpending() async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      if (hasPlaidConnection) {
        // Process real transaction data into monthly spending
        return await _getMonthlySpendingFromTransactions();
      } else {
        // Fall back to static data
        return await _getStaticMonthlySpending();
      }
    } catch (e) {
      print('Error loading monthly spending: $e');
      return await _getStaticMonthlySpending();
    }
  }

  Future<List<MonthlySpending>> _getMonthlySpendingFromTransactions() async {
    try {
      final transactions = await getTransactions();
      
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
            // Categorize spending - including new Subscriptions category
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
                // Add subscriptions to miscellaneous for now since MonthlySpending model doesn't have it
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
          earnings: totalIncome,
        ));
      });

      // Sort chronologically
      result.sort((a, b) => a.date.compareTo(b.date));
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
  Future<List<CheckingAccount>> getCheckingAccounts() async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      if (hasPlaidConnection) {
        final accounts = await _plaidService.getAccounts(_getDummyContext());
        final checkingAccounts = accounts
            .where((account) => account['type'] == 'depository')
            .map((account) => CheckingAccount(
                  name: account['name'] ?? 'Checking Account',
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
  Future<List<CreditCard>> getCreditCards() async {
    try {
      final hasPlaidConnection = await _plaidService.hasPlaidConnection();
      
      if (hasPlaidConnection) {
        final accounts = await _plaidService.getAccounts(_getDummyContext());
        final creditCards = accounts
            .where((account) => account['type'] == 'credit')
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

  Future<double> getNetCash() async {
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

  // Get credit score data
  Future<List<Map<String, dynamic>>> getCreditScoreHistory() async {
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

  // Get insights based on spending patterns
  Future<List<Map<String, dynamic>>> getSpendingInsights() async {
    try {
      final transactions = await getTransactions();
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

      // Generate insights
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

      return insights;
    } catch (e) {
      print('Error generating spending insights: $e');
      return [];
    }
  }

  // Dummy context for when context is needed but not available
  dynamic _getDummyContext() {
    // This is a placeholder - in real usage, proper context should be passed
    return null;
  }
}