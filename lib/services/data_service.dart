import 'package:csv/csv.dart';
import 'package:fbla_coding_programming_app/models/account_balance.dart';
import 'package:fbla_coding_programming_app/models/transaction.dart';
import 'package:fbla_coding_programming_app/models/credit_card.dart';
import 'package:flutter/services.dart';

class DataService {
  Future<List<AccountBalance>> getAccountBalances() async {
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
      print('Error loading account balances: $e');
      return [];
    }
  }

  Future<List<Transaction>> getTransactions() async {
    try {
      final String data =
          await rootBundle.loadString('assets/data/transactions.csv');

      List<List<dynamic>> csvTable = const CsvToListConverter().convert(
        data,
        eol: '\n',
        fieldDelimiter: ',',
      );

      List<Transaction> transactions = [];
      if (csvTable.length > 1) {
        for (var i = 1; i < csvTable.length; i++) {
          try {
            var row = csvTable[i];
            if (row.length >= 6) {
              transactions.add(Transaction(
                date: DateTime.parse(row[0].toString()),
                description: row[1].toString(),
                category: row[2].toString(),
                amount: double.parse(row[3].toString()),
                account: row[4].toString(),
                transactionType: row[5].toString(),
                cardId: row.length >= 7 ? row[6].toString() : null,
              ));
            }
          } catch (e) {
            print('Error parsing row $i: $e');
            continue;
          }
        }
      }

      return transactions;
    } catch (e) {
      print('Error loading transactions: $e');
      return [];
    }
  }

  List<CreditCard> getCreditCards(
      List<Transaction> transactions, AccountBalance balance) {
    final secondaryTransactions = transactions
        .where((t) => t.account == 'Credit Card' && t.cardId == 'secondary')
        .toList();

    double secondaryBalance = 0;
    if (secondaryTransactions.isNotEmpty) {
      secondaryBalance = secondaryTransactions
          .map((t) => t.transactionType == 'Debit' ? t.amount : -t.amount)
          .reduce((a, b) => a + b);
    }

    final cards = [CreditCard.primary(balance.creditCardBalance)];

    if (secondaryTransactions.isNotEmpty) {
      cards.add(CreditCard.secondary(secondaryBalance));
    }

    return cards;
  }
}
