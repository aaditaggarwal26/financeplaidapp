import 'package:finsight/models/account_balance.dart';
import 'package:intl/intl.dart';

class MonthlySpending {
  final DateTime date;
  final double groceries;
  final double utilities;
  final double rent;
  final double transportation;
  final double entertainment;
  final double diningOut;
  final double shopping;
  final double healthcare;
  final double insurance;
  final double miscellaneous;
  final double? earnings;
  final AccountBalance? accountBalance;

  MonthlySpending({
    required this.date,
    required this.groceries,
    required this.utilities,
    required this.rent,
    required this.transportation,
    required this.entertainment,
    required this.diningOut,
    required this.shopping,
    required this.healthcare,
    required this.insurance,
    required this.miscellaneous,
    this.earnings,
    this.accountBalance,
  });

  double get totalSpent =>
      groceries +
      utilities +
      rent +
      transportation +
      entertainment +
      diningOut +
      shopping +
      healthcare +
      insurance +
      miscellaneous;

  double? get income => earnings;

  Map<String, double> get categoryBreakdown => {
        'Groceries': groceries,
        'Utilities': utilities,
        'Rent': rent,
        'Transportation': transportation,
        'Entertainment': entertainment,
        'Dining Out': diningOut,
        'Shopping': shopping,
        'Healthcare': healthcare,
        'Insurance': insurance,
        'Miscellaneous': miscellaneous,
      };

  static MonthlySpending fromCsv(List<dynamic> row, {AccountBalance? balance}) {
    return MonthlySpending(
      date: DateFormat('yyyy-MM').parse(row[0].toString()),
      groceries: double.parse(row[1].toString()),
      utilities: double.parse(row[2].toString()),
      rent: double.parse(row[3].toString()),
      transportation: double.parse(row[4].toString()),
      entertainment: double.parse(row[5].toString()),
      diningOut: double.parse(row[6].toString()),
      shopping: double.parse(row[7].toString()),
      healthcare: double.parse(row[8].toString()),
      insurance: double.parse(row[9].toString()),
      miscellaneous: double.parse(row[10].toString()),
      accountBalance: balance,
    );
  }
}
