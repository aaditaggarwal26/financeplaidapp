class AccountBalance {
  final DateTime date;
  final double checking;
  final double creditCardBalance;
  final double savings;
  final double investmentAccount;
  final double netWorth;

  AccountBalance({
    required this.date,
    required this.checking,
    required this.creditCardBalance,
    required this.savings,
    required this.investmentAccount,
    required this.netWorth,
  });

  factory AccountBalance.fromCsv(Map<String, dynamic> map) {
    return AccountBalance(
      date: DateTime.parse(map['Date']),
      checking: double.parse(map['Checking']),
      creditCardBalance: double.parse(map['Credit_Card_Balance']),
      savings: double.parse(map['Savings']),
      investmentAccount: double.parse(map['Investment_Account']),
      netWorth: double.parse(map['Net_Worth']),
    );
  }
}
