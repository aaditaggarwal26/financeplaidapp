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

  factory Transaction.fromCsv(Map<String, dynamic> map) {
    return Transaction(
      date: DateTime.parse(map['Date']),
      description: map['Description'],
      category: map['Category'],
      amount: double.parse(map['Amount']),
      account: map['Account'],
      transactionType: map['Transaction_Type'],
      cardId: map['Card_ID'],
      isPersonal: false,
      id: null,
    );
  }
}
