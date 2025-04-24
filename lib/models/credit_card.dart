// Models a credit card with essential financial details.
class CreditCard {
  // Name of the card (e.g., "Visa Platinum").
  final String name;
  // Last four digits of the card number for identification.
  final String lastFour;
  // Current balance on the card.
  final double balance;
  // Maximum credit limit for the card.
  final double creditLimit;
  // Annual percentage rate (APR) for interest calculations.
  final double apr;
  // Name of the issuing bank (e.g., "Chase").
  final String bankName;

  // Constructor requiring all fields to ensure complete data.
  CreditCard({
    required this.name,
    required this.lastFour,
    required this.balance,
    required this.creditLimit,
    required this.apr,
    required this.bankName,
  });
}