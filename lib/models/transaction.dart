import 'dart:convert';
import 'package:intl/intl.dart';

class Transaction {
  final String? id;
  final DateTime date;
  final String description;
  final String category;
  final double amount;
  final String account;
  final String transactionType;
  final String? cardId;
  final bool isPersonal;

  // Plaid-specific enriched data
  final String? merchantName;
  final String? merchantLogoUrl;
  final String? merchantWebsite;
  final String? originalDescription;
  final String? plaidCategory;
  final Map<String, dynamic>? merchantMetadata;
  final String? location;
  final double? confidence;
  final bool isRecurring;
  final String? paymentMethod;
  final String? iso_currency_code;

  Transaction({
    required this.id,
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    required this.account,
    required this.transactionType,
    this.cardId,
    this.isPersonal = false,
    this.merchantName,
    this.merchantLogoUrl,
    this.merchantWebsite,
    this.originalDescription,
    this.plaidCategory,
    this.merchantMetadata,
    this.location,
    this.confidence,
    this.isRecurring = false,
    this.paymentMethod,
    this.iso_currency_code,
  });

  // Factory constructor for creating a Transaction from local CSV data.
  factory Transaction.fromLocalCsv(List<dynamic> row) {
    Map<String, dynamic>? metadata;
    if (row.length >= 17 && row[16] is String && row[16].isNotEmpty) {
      try {
        metadata = json.decode(row[16]) as Map<String, dynamic>;
      } catch (e) {
        // Could not parse metadata, leave it as null
      }
    }
    
    return Transaction(
      id: row.length > 8 ? row[8].toString() : 'local_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.tryParse(row[0].toString()) ?? DateTime.now(),
      description: row[1].toString(),
      category: row[2].toString(),
      amount: double.tryParse(row[3].toString()) ?? 0.0,
      account: row[4].toString(),
      transactionType: row[5].toString(),
      cardId: row.length > 6 ? row[6].toString() : null,
      isPersonal: row.length > 7 ? row[7].toString().toLowerCase() == 'true' : false,
      merchantName: row.length > 9 ? row[9].toString() : null,
      merchantLogoUrl: row.length > 10 ? row[10].toString() : null,
      merchantWebsite: row.length > 11 ? row[11].toString() : null,
      location: row.length > 12 ? row[12].toString() : null,
      confidence: row.length > 13 && row[13].toString().isNotEmpty ? double.tryParse(row[13].toString()) : null,
      isRecurring: row.length > 14 ? row[14].toString().toLowerCase() == 'true' : false,
      paymentMethod: row.length > 15 ? row[15].toString() : null,
      merchantMetadata: metadata,
    );
  }

  // Helper properties for UI display
  String get displayName => merchantName != null && merchantName!.isNotEmpty ? merchantName! : description;
  String get formattedAmount => '${transactionType == 'Credit' ? '+' : '-'}\$${amount.abs().toStringAsFixed(2)}';
  bool get hasLogo => merchantLogoUrl != null && merchantLogoUrl!.isNotEmpty;
  
  // FIX: This getter now correctly provides a fallback using the website domain.
  String? get effectiveLogo {
    if (hasLogo) return merchantLogoUrl;
    if (merchantWebsite != null && merchantWebsite!.isNotEmpty) {
      final domain = merchantWebsite!.replaceAll(RegExp(r'https?://'), '').split('/').first;
      // Use a reliable favicon service as a fallback
      return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
    }
    return null;
  }
}
