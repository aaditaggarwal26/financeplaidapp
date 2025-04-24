// Represents a credit score snapshot at a specific date.
class CreditScore {
  // Date of the credit score record.
  final DateTime date;
  // Credit score value (e.g., 720).
  final int score;

  // Constructor requiring date and score.
  CreditScore({required this.date, required this.score});

  // Factory method to create a CreditScore from a CSV map.
  // Parses the date and score from the provided map.
  factory CreditScore.fromCsv(Map<String, dynamic> map) {
    return CreditScore(
      date: DateTime.parse(map['Date']), // Converts string to DateTime.
      score: int.parse(map['Credit_Score']), // Parses score to integer.
    );
  }
}