class CreditCard {
  final String id;
  final String name;
  final double balance;
  final double limit;
  final String type;
  final String lastFourDigits;
  final DateTime expiryDate;

  CreditCard({
    required this.id,
    required this.name,
    required this.balance,
    required this.limit,
    required this.type,
    required this.lastFourDigits,
    required this.expiryDate,
  });

  factory CreditCard.primary(double balance) {
    return CreditCard(
      id: 'primary',
      name: 'Primary Visa',
      balance: balance,
      limit: 5000.00,
      type: 'Visa',
      lastFourDigits: '4321',
      expiryDate: DateTime(2027, 12),
    );
  }

  factory CreditCard.secondary(double balance) {
    return CreditCard(
      id: 'secondary',
      name: 'Rewards Mastercard',
      balance: balance,
      limit: 3000.00,
      type: 'Mastercard',
      lastFourDigits: '8765',
      expiryDate: DateTime(2026, 8),
    );
  }

  String get formattedExpiryDate {
    return '${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.year.toString().substring(2)}';
  }
}
