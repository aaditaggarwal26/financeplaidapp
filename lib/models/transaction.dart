// Enhanced transaction model with Plaid Enrich data support
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
  
  // Enhanced merchant information from Plaid Enrich
  final String? merchantName;
  final String? merchantLogoUrl;
  final String? merchantWebsite;
  final String? originalDescription;
  final String? plaidCategory;
  final Map<String, dynamic>? merchantMetadata;
  
  // Location and additional context from Plaid Enrich
  final String? location;
  final String? subcategory;
  final double? confidence;
  final bool isRecurring;
  final String? paymentMethod;
  
  // Additional enriched fields from Plaid
  final String? merchantDescription;
  final List<String>? merchantCategories;
  final bool? isSubscription;
  final String? iso_currency_code;
  final String? unofficial_currency_code;

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
    this.merchantName,
    this.merchantLogoUrl,
    this.merchantWebsite,
    this.originalDescription,
    this.plaidCategory,
    this.merchantMetadata,
    this.location,
    this.subcategory,
    this.confidence,
    this.isRecurring = false,
    this.paymentMethod,
    this.merchantDescription,
    this.merchantCategories,
    this.isSubscription,
    this.iso_currency_code,
    this.unofficial_currency_code,
  });

  // Factory method to create a Transaction from a CSV map.
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

  // Create a copy with updated fields
  Transaction copyWith({
    DateTime? date,
    String? description,
    String? category,
    double? amount,
    String? account,
    String? transactionType,
    String? cardId,
    bool? isPersonal,
    String? id,
    String? merchantName,
    String? merchantLogoUrl,
    String? merchantWebsite,
    String? originalDescription,
    String? plaidCategory,
    Map<String, dynamic>? merchantMetadata,
    String? location,
    String? subcategory,
    double? confidence,
    bool? isRecurring,
    String? paymentMethod,
    String? merchantDescription,
    List<String>? merchantCategories,
    bool? isSubscription,
    String? iso_currency_code,
    String? unofficial_currency_code,
  }) {
    return Transaction(
      date: date ?? this.date,
      description: description ?? this.description,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      account: account ?? this.account,
      transactionType: transactionType ?? this.transactionType,
      cardId: cardId ?? this.cardId,
      isPersonal: isPersonal ?? this.isPersonal,
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      merchantLogoUrl: merchantLogoUrl ?? this.merchantLogoUrl,
      merchantWebsite: merchantWebsite ?? this.merchantWebsite,
      originalDescription: originalDescription ?? this.originalDescription,
      plaidCategory: plaidCategory ?? this.plaidCategory,
      merchantMetadata: merchantMetadata ?? this.merchantMetadata,
      location: location ?? this.location,
      subcategory: subcategory ?? this.subcategory,
      confidence: confidence ?? this.confidence,
      isRecurring: isRecurring ?? this.isRecurring,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      merchantDescription: merchantDescription ?? this.merchantDescription,
      merchantCategories: merchantCategories ?? this.merchantCategories,
      isSubscription: isSubscription ?? this.isSubscription,
      iso_currency_code: iso_currency_code ?? this.iso_currency_code,
      unofficial_currency_code: unofficial_currency_code ?? this.unofficial_currency_code,
    );
  }

  // Get display name (prioritizes merchant name over description)
  String get displayName {
    if (merchantName != null && merchantName!.isNotEmpty) {
      return merchantName!;
    }
    return description;
  }

  // Get formatted amount with proper sign
  String get formattedAmount {
    final sign = transactionType == 'Credit' ? '+' : '-';
    return '$sign\$${amount.toStringAsFixed(2)}';
  }

  // Check if transaction has merchant logo
  bool get hasLogo => merchantLogoUrl != null && merchantLogoUrl!.isNotEmpty;

  // Get merchant logo with fallback
  String? get effectiveLogo {
    if (hasLogo) {
      return merchantLogoUrl;
    }
    
    // If we have a website, try to generate a logo URL
    if (merchantWebsite != null && merchantWebsite!.isNotEmpty) {
      final domain = merchantWebsite!.replaceAll('https://', '').replaceAll('http://', '').split('/').first;
      return 'https://logo.clearbit.com/$domain';
    }
    
    return null;
  }

  // Get confidence level as a readable string
  String get confidenceLevel {
    if (confidence == null) return 'Unknown';
    
    if (confidence! >= 0.9) return 'Very High';
    if (confidence! >= 0.7) return 'High';
    if (confidence! >= 0.5) return 'Medium';
    if (confidence! >= 0.3) return 'Low';
    return 'Very Low';
  }

  // Check if this is likely a subscription based on multiple factors
  bool get isLikelySubscription {
    if (isSubscription == true) return true;
    if (isRecurring) return true;
    
    // Check category
    if (category.toLowerCase().contains('subscription')) return true;
    
    // Check description for subscription keywords
    final desc = description.toLowerCase();
    return desc.contains('subscription') || 
           desc.contains('monthly') || 
           desc.contains('annual') ||
           desc.contains('netflix') ||
           desc.contains('spotify') ||
           desc.contains('amazon prime');
  }

  // Get formatted location with fallback
  String? get formattedLocation {
    if (location != null && location!.isNotEmpty) {
      return location;
    }
    
    // If we have merchant metadata, try to extract location
    if (merchantMetadata != null) {
      final city = merchantMetadata!['city'];
      final state = merchantMetadata!['state'];
      if (city != null && state != null) {
        return '$city, $state';
      }
    }
    
    return null;
  }

  // Get category icon based on category
  String get categoryIcon {
    switch (category) {
      case 'Groceries':
        return '🛒';
      case 'Dining Out':
        return '🍽️';
      case 'Transportation':
        return '🚗';
      case 'Shopping':
        return '🛍️';
      case 'Entertainment':
        return '🎬';
      case 'Healthcare':
        return '🏥';
      case 'Utilities':
        return '⚡';
      case 'Insurance':
        return '🛡️';
      case 'Rent':
        return '🏠';
      case 'Subscriptions':
        return '📱';
      case 'Banking':
        return '🏦';
      case 'Travel':
        return '✈️';
      case 'Education':
        return '📚';
      default:
        return '💳';
    }
  }

  // Get payment method display name
  String get paymentMethodDisplay {
    switch (paymentMethod?.toLowerCase()) {
      case 'online':
        return 'Online';
      case 'in store':
        return 'In Store';
      case 'other':
        return 'Other';
      default:
        return paymentMethod ?? 'Unknown';
    }
  }

  // Convert to JSON for storage/API
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'description': description,
      'category': category,
      'amount': amount,
      'account': account,
      'transactionType': transactionType,
      'cardId': cardId,
      'isPersonal': isPersonal,
      'id': id,
      'merchantName': merchantName,
      'merchantLogoUrl': merchantLogoUrl,
      'merchantWebsite': merchantWebsite,
      'originalDescription': originalDescription,
      'plaidCategory': plaidCategory,
      'merchantMetadata': merchantMetadata,
      'location': location,
      'subcategory': subcategory,
      'confidence': confidence,
      'isRecurring': isRecurring,
      'paymentMethod': paymentMethod,
      'merchantDescription': merchantDescription,
      'merchantCategories': merchantCategories,
      'isSubscription': isSubscription,
      'iso_currency_code': iso_currency_code,
      'unofficial_currency_code': unofficial_currency_code,
    };
  }

  // Create from JSON
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      date: DateTime.parse(json['date']),
      description: json['description'],
      category: json['category'],
      amount: json['amount'].toDouble(),
      account: json['account'],
      transactionType: json['transactionType'],
      cardId: json['cardId'],
      isPersonal: json['isPersonal'] ?? false,
      id: json['id'],
      merchantName: json['merchantName'],
      merchantLogoUrl: json['merchantLogoUrl'],
      merchantWebsite: json['merchantWebsite'],
      originalDescription: json['originalDescription'],
      plaidCategory: json['plaidCategory'],
      merchantMetadata: json['merchantMetadata'],
      location: json['location'],
      subcategory: json['subcategory'],
      confidence: json['confidence']?.toDouble(),
      isRecurring: json['isRecurring'] ?? false,
      paymentMethod: json['paymentMethod'],
      merchantDescription: json['merchantDescription'],
      merchantCategories: json['merchantCategories']?.cast<String>(),
      isSubscription: json['isSubscription'],
      iso_currency_code: json['iso_currency_code'],
      unofficial_currency_code: json['unofficial_currency_code'],
    );
  }

  @override
  String toString() {
    return 'Transaction{date: $date, description: $description, amount: $amount, category: $category, merchant: $merchantName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.date == date &&
        other.amount == amount &&
        other.description == description;
  }

  @override
  int get hashCode {
    return id.hashCode ^ date.hashCode ^ amount.hashCode ^ description.hashCode;
  }
}