// Imports for date formatting and account balance model.
import 'package:finsight/models/account_balance.dart';
import 'package:intl/intl.dart';

// Tracks monthly spending across various categories, with optional earnings and balance
class MonthlySpending {
  // Date representing the month (e.g., first day of the month)
  final DateTime date;
  // Spending on groceries
  final double groceries;
  // Spending on utilities (e.g., electricity, water)
  final double utilities;
  // Rent or mortgage payments
  final double rent;
  // Transportation expenses (e.g., gas, public transit)
  final double transportation;
  // Entertainment expenses (e.g., movies, concerts)
  final double entertainment;
  // Dining out expenses
  final double diningOut;
  // Shopping expenses (e.g., clothing, electronics)
  final double shopping;
  // Healthcare expenses (e.g., doctor visits, medications)
  final double healthcare;
  // Insurance payments (e.g., health, auto)
  final double insurance;
  // Miscellaneous expenses not covered by other categories
  final double miscellaneous;
  // Optional earnings for the month (e.g., income)
  final double? earnings;
  // Optional reference to account balances for the month
  final AccountBalance? accountBalance;

  // Constructor requiring spending categories and allowing optional fields
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

  // Calculates total spending across all categories.
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

  // Returns the earnings for the month, if available.
  double? get income => earnings;

  // Provides a breakdown of spending by category as a map.
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

  // Factory method to create a MonthlySpending from a CSV row.
  // Parses a list of values and optionally links an AccountBalance.
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