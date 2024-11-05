class CreditScore {
  final DateTime date;
  final int score;

  CreditScore({required this.date, required this.score});

  factory CreditScore.fromCsv(Map<String, dynamic> map) {
    return CreditScore(
      date: DateTime.parse(map['Date']),
      score: int.parse(map['Credit_Score']),
    );
  }
}