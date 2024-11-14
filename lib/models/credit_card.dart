class CreditCard {
  final String name;
  final String lastFour;
  final double balance;
  final double creditLimit;
  final double apr;
  final String bankName;

  CreditCard({
    required this.name,
    required this.lastFour,
    required this.balance,
    required this.creditLimit,
    required this.apr,
    required this.bankName,
  });
}
