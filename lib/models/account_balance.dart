// Tracks account balances across different financial accounts at a specific date.
class AccountBalance {
  // Date of the balance snapshot.
  final DateTime date;
  // Balance in the checking account.
  final double checking;
  // Total balance across credit cards.
  final double creditCardBalance;
  // Balance in the savings account.
  final double savings;
  // Balance in the investment account.
  final double investmentAccount;
  // Net worth, calculated as assets minus liabilities.
  final double netWorth;

  // Constructor requiring all fields for a complete balance snapshot.
  AccountBalance({
    required this.date,
    required this.checking,
    required this.creditCardBalance,
    required this.savings,
    required this.investmentAccount,
    required this.netWorth,
  });

  // Factory method to create an AccountBalance from a CSV map.
  // Parses CSV data into the appropriate types for each field.
  factory AccountBalance.fromCsv(Map<String, dynamic> map) {
    return AccountBalance(
      date: DateTime.parse(map['Date']), // Converts string to DateTime.
      checking: double.parse(map['Checking']), // Parses checking balance.
      creditCardBalance: double.parse(map['Credit_Card_Balance']), // Parses credit card balance.
      savings: double.parse(map['Savings']), // Parses savings balance.
      investmentAccount: double.parse(map['Investment_Account']), // Parses investment balance.
      netWorth: double.parse(map['Net_Worth']), // Parses net worth.
    );
  }
}