// Represents a financial transaction with key details like date, amount, and category.
class Transaction {
  final DateTime date;
  final String description;
  final String category;
  final double amount;
  final String account;
  final String transactionType;
  final String? cardId;
  final bool isPersonal;
  final String? id;

  // Constructor with required and optional fields.
  Transaction({
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    required this.account,
    required this.transactionType,
    this.cardId,
    this.isPersonal = false,
    this.id,
  });

  // Factory method to create a Transaction from a CSV map.
  // Expects specific keys in the map and parses them into the correct types.
  factory Transaction.fromCsv(Map<String, dynamic> map) {
    return Transaction(
      date: DateTime.parse(map['Date']), // Converts string date to DateTime.
      description: map['Description'],
      category: map['Category'], 
      amount: double.parse(map['Amount']), // Parses string to double.
      account: map['Account'], 
      transactionType: map['Transaction_Type'], // Maps to Credit/Debit.
      cardId: map['Card_ID'], 
      isPersonal: false, 
      id: null, 
    );
  }
}