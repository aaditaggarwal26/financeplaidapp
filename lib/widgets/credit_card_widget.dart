import 'package:fbla_coding_programming_app/models/transaction.dart';
import 'package:flutter/material.dart';
import '../models/credit_card.dart';

class CreditCardWidget extends StatelessWidget {
  final CreditCard card;
  final List<Transaction> recentTransactions;

  const CreditCardWidget({
    Key? key,
    required this.card,
    required this.recentTransactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  card.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  card.type,
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '•••• ${card.lastFourDigits}',
              style: const TextStyle(
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Expires: ${card.formattedExpiryDate}',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const Divider(height: 24),
            _buildBalanceRow('Current Balance:',
                '\$${card.balance.abs().toStringAsFixed(2)}'),
            _buildBalanceRow('Available Credit:',
                '\$${(card.limit - card.balance.abs()).toStringAsFixed(2)}'),
            _buildBalanceRow(
                'Credit Limit:', '\$${card.limit.toStringAsFixed(2)}'),
            if (recentTransactions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...recentTransactions.take(3).map((t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            t.description,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '\$${t.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: t.transactionType == 'Credit'
                                ? Colors.green
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
