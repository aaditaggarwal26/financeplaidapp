import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:finsight/models/transaction.dart' as app_model;

class PlaidService {
  // Plaid configuration - ONLY use environment variables for security
  static String get _plaidClientId {
    final clientId = dotenv.env['PLAID_CLIENT_ID'];
    if (clientId == null || clientId.isEmpty) {
      throw Exception('PLAID_CLIENT_ID not found in environment variables');
    }
    return clientId;
  }
  
  static String get _plaidSecret {
    final secret = dotenv.env['PLAID_SECRET'];
    if (secret == null || secret.isEmpty) {
      throw Exception('PLAID_SECRET not found in environment variables');
    }
    return secret;
  }
  
  static String get _plaidEnv => dotenv.env['PLAID_ENV'] ?? 'sandbox';
  
  static String get _plaidBaseUrl {
    switch (_plaidEnv.toLowerCase()) {
      case 'production':
        return 'https://production.plaid.com';
      case 'development':
        return 'https://development.plaid.com';
      default:
        return 'https://sandbox.plaid.com';
    }
  }
  
  // Get products from environment or use defaults
  static List<String> get _plaidProducts {
    final productsStr = dotenv.env['PLAID_PRODUCTS'] ?? 'auth,transactions';
    return productsStr.split(',').map((p) => p.trim()).toList();
  }
  
  // Get country codes from environment or use defaults
  static List<String> get _plaidCountryCodes {
    final codesStr = dotenv.env['PLAID_COUNTRY_CODES'] ?? 'US';
    return codesStr.split(',').map((c) => c.trim()).toList();
  }
  
  // ENHANCEMENT: Use flutter_secure_storage for the sensitive access token.
  final _secureStorage = const FlutterSecureStorage();
  static const String _SECURE_ACCESS_TOKEN_KEY = 'plaid_access_token_secure';
  static const String _ITEM_ID_KEY = 'plaid_item_id';
  
  // Singleton pattern
  static final PlaidService _instance = PlaidService._internal();
  
  factory PlaidService() {
    return _instance;
  }
  
  PlaidService._internal();
  
  // Instance variables
  String? _accessToken;
  List<Map<String, dynamic>>? _cachedAccounts;
  
  // Step 1: Create Link Token
  Future<String?> createLinkToken() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo-user-${DateTime.now().millisecondsSinceEpoch}';
      
      final url = Uri.parse('$_plaidBaseUrl/link/token/create');
      final headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'FinSight/1.0.0',
      };
      
      final redirectUri = dotenv.env['PLAID_REDIRECT_URI'];
      
      final bodyData = {
        'client_id': _plaidClientId,
        'secret': _plaidSecret,
        'user': {
          'client_user_id': userId,
        },
        'client_name': 'FinSight',
        'products': _plaidProducts,
        'country_codes': _plaidCountryCodes,
        'language': 'en',
      };
      
      if (redirectUri != null && redirectUri.isNotEmpty) {
        bodyData['redirect_uri'] = redirectUri;
      }
      
      final body = json.encode(bodyData);
      
      print('Creating link token with products: $_plaidProducts');

      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Successfully created link token');
        return data['link_token'];
      } else {
        print('Failed to create link token: ${response.statusCode}');
        final errorData = json.decode(response.body);
        print('Plaid error: ${errorData['error_code']} - ${errorData['error_message']}');
        return null;
      }
    } catch (e) {
      print('Exception in createLinkToken: $e');
      return null;
    }
  }

  // Step 2: Exchange public token for access token
  Future<bool> exchangePublicToken(String publicToken) async {
    try {
      final url = Uri.parse('$_plaidBaseUrl/item/public_token/exchange');
      final headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'FinSight/1.0.0',
      };
      
      final body = json.encode({
        'client_id': _plaidClientId,
        'secret': _plaidSecret,
        'public_token': publicToken,
      });

      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveAccessToken(data['access_token'], data['item_id']);
        print('Successfully exchanged public token');
        return true;
      } else {
        print('Failed to exchange public token: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception in exchangePublicToken: $e');
      return false;
    }
  }

  // Save access token securely
  Future<void> _saveAccessToken(String accessToken, String itemId) async {
    try {
      await _secureStorage.write(key: _SECURE_ACCESS_TOKEN_KEY, value: accessToken);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ITEM_ID_KEY, itemId);
      
      _accessToken = accessToken;
      print('Successfully saved access token securely');
    } catch (e) {
      print('Error saving access token securely: $e');
    }
  }

  // Get access token from secure storage
  Future<String?> _getAccessToken() async {
    if (_accessToken != null) {
      return _accessToken;
    }
    try {
      _accessToken = await _secureStorage.read(key: _SECURE_ACCESS_TOKEN_KEY);
      return _accessToken;
    } catch (e) {
      print('Error getting secure access token: $e');
      return null;
    }
  }

  // Enhanced merchant logo fetching
  Future<String?> _getMerchantLogo(String merchantName) async {
    try {
      final cleanName = merchantName.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
      
      final commonLogos = {
        'amazon': 'amazon.com', 'apple': 'apple.com', 'starbucks': 'starbucks.com',
        'mcdonalds': 'mcdonalds.com', 'walmart': 'walmart.com', 'target': 'target.com',
        'uber': 'uber.com', 'lyft': 'lyft.com', 'netflix': 'netflix.com',
        'spotify': 'spotify.com', 'google': 'google.com', 'chase': 'chase.com',
        'wellsfargo': 'wellsfargo.com', 'bankofamerica': 'bankofamerica.com',
      };
      
      String? domain;
      for (final entry in commonLogos.entries) {
        if (cleanName.contains(entry.key)) {
          domain = entry.value;
          break;
        }
      }
      
      if (domain == null) {
        final words = cleanName.split(' ').where((w) => w.length > 2 && !RegExp(r'\d').hasMatch(w)).toList();
        if (words.isNotEmpty) {
          final potentialDomain = '${words.first}.com';
          if (!potentialDomain.contains(RegExp(r'[^a-z.]'))) {
              domain = potentialDomain;
          }
        }
      }
      
      if (domain != null) {
        final logoUrl = 'https://logo.clearbit.com/$domain';
        try {
          final response = await http.head(Uri.parse(logoUrl)).timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            return logoUrl;
          }
        } catch (e) {
          // Fallback to favicon
        }
        return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
      }
      
      return null;
    } catch (e) {
      print('Error getting merchant logo for "$merchantName": $e');
      return null;
    }
  }

  // Fetch transactions from Plaid
  Future<List<app_model.Transaction>> fetchTransactions({
    required BuildContext context,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) throw Exception('No Plaid connection found');
    
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365));
    final end = endDate ?? now;
    
    final formattedStartDate = DateFormat('yyyy-MM-dd').format(start);
    final formattedEndDate = DateFormat('yyyy-MM-dd').format(end);
    
    try {
      final url = Uri.parse('$_plaidBaseUrl/transactions/get');
      final headers = {'Content-Type': 'application/json', 'User-Agent': 'FinSight/1.0.0'};
      
      List<dynamic> allTransactions = [];
      int offset = 0;
      bool hasMore = true;
      
      while (hasMore) {
        final body = json.encode({
          'client_id': _plaidClientId, 'secret': _plaidSecret, 'access_token': accessToken,
          'start_date': formattedStartDate, 'end_date': formattedEndDate,
          'options': {'count': 500, 'offset': offset, 'include_personal_finance_category': true},
        });

        final response = await http.post(url, headers: headers, body: body);
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final transactions = data['transactions'] as List<dynamic>? ?? [];
          allTransactions.addAll(transactions);
          final total = data['total_transactions'] as int? ?? 0;
          offset += transactions.length;
          hasMore = offset < total;
        } else {
          print('Failed to fetch transactions: ${response.statusCode}');
          throw Exception('Failed to fetch transactions from Plaid');
        }
      }
      
      final processed = <app_model.Transaction>[];
      for (final trx in allTransactions) {
        try {
          processed.add(await _processPlaidTransaction(trx));
        } catch (e) {
          print('Error processing transaction: $e');
        }
      }
      return processed;
    } catch (e) {
      print('Exception in fetchTransactions: $e');
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  Future<app_model.Transaction> _processPlaidTransaction(Map<String, dynamic> trx) async {
      final amount = (trx['amount'] as num?)?.toDouble() ?? 0.0;
      final merchantName = trx['merchant_name'] as String? ?? trx['name'] as String? ?? 'Unknown';
      final description = trx['name'] as String? ?? 'Unknown Transaction';
      final date = DateTime.parse(trx['date'] as String);

      String category = 'Miscellaneous';
      double? confidence;
      
      if (trx['personal_finance_category'] != null) {
        category = _mapPlaidPersonalFinanceCategory(trx['personal_finance_category']);
        confidence = 0.9;
      } else if (trx['category'] != null && (trx['category'] as List).isNotEmpty) {
        category = _mapPlaidLegacyCategory(trx['category']);
        confidence = 0.7;
      } else {
        category = _fallbackCategorizeTransaction(description);
        confidence = 0.3;
      }

      final logoUrl = await _getMerchantLogo(merchantName);
      final website = (logoUrl != null && logoUrl.contains('clearbit.com/')) ? logoUrl.split('clearbit.com/').last : null;

      return app_model.Transaction(
        id: trx['transaction_id'] as String,
        date: date,
        description: merchantName,
        category: category,
        amount: amount.abs(),
        account: trx['account_owner'] as String? ?? 'Unknown Account',
        transactionType: amount < 0 ? 'Debit' : 'Credit',
        isPersonal: false,
        merchantName: merchantName,
        merchantLogoUrl: logoUrl,
        merchantWebsite: website,
        originalDescription: description,
        plaidCategory: (trx['category'] as List?)?.join(', '),
        confidence: confidence,
        isRecurring: _detectRecurringTransaction(description, amount),
        paymentMethod: trx['payment_channel'] as String?,
        location: _extractLocation(trx),
        iso_currency_code: trx['iso_currency_code'] as String?,
        unofficial_currency_code: trx['unofficial_currency_code'] as String?,
      );
  }

  String _mapPlaidPersonalFinanceCategory(Map<String, dynamic> pfc) {
    final primary = pfc['primary']?.toString().toLowerCase() ?? '';
    final detailed = pfc['detailed']?.toString().toLowerCase() ?? '';
    
    if (primary.contains('food_and_drink')) return detailed.contains('groceries') ? 'Groceries' : 'Dining Out';
    if (primary.contains('transportation')) return 'Transportation';
    if (primary.contains('general_merchandise') || primary.contains('shops')) return 'Shopping';
    if (primary.contains('medical')) return 'Healthcare';
    if (primary.contains('entertainment') || primary.contains('recreation')) return 'Entertainment';
    if (primary.contains('travel')) return 'Transportation';
    if (primary.contains('rent_and_utilities')) return detailed.contains('rent') ? 'Rent' : 'Utilities';
    if (detailed.contains('subscription')) return 'Subscriptions';
    if (detailed.contains('insurance')) return 'Insurance';
    if (primary.contains('bank_fees') || primary.contains('loan_payments')) return 'Banking';
    
    return 'Miscellaneous';
  }

  String _mapPlaidLegacyCategory(List<dynamic> categories) {
    final catString = categories.join(' ').toLowerCase();
    if (catString.contains('food')) return catString.contains('grocery') ? 'Groceries' : 'Dining Out';
    if (catString.contains('shop') || catString.contains('retail')) return 'Shopping';
    if (catString.contains('transport')) return 'Transportation';
    if (catString.contains('recreation') || catString.contains('entertainment')) return 'Entertainment';
    if (catString.contains('health') || catString.contains('medical')) return 'Healthcare';
    if (catString.contains('utilities') || catString.contains('internet')) return 'Utilities';
    if (catString.contains('rent') || catString.contains('mortgage')) return 'Rent';
    if (catString.contains('insurance')) return 'Insurance';
    return 'Miscellaneous';
  }

  String _fallbackCategorizeTransaction(String description) {
    final d = description.toLowerCase();
    if (d.contains('grocery') || d.contains('market')) return 'Groceries';
    if (d.contains('restaurant') || d.contains('coffee') || d.contains('starbucks')) return 'Dining Out';
    if (d.contains('gas') || d.contains('uber') || d.contains('lyft')) return 'Transportation';
    if (d.contains('amazon') || d.contains('target') || d.contains('walmart')) return 'Shopping';
    if (d.contains('netflix') || d.contains('spotify') || d.contains('subscription')) return 'Subscriptions';
    return 'Miscellaneous';
  }

  bool _detectRecurringTransaction(String description, double amount) {
    final d = description.toLowerCase();
    return d.contains('subscription') || d.contains('monthly') || d.contains('recurring') ||
           ['netflix', 'spotify', 'amazon prime', 'hulu', 'disney', 'apple music', 'youtube premium',
            'adobe', 'microsoft', 'google', 'dropbox', 'electric', 'gas company', 'water',
            'internet', 'phone', 'insurance'].any((s) => d.contains(s));
  }

  String? _extractLocation(Map<String, dynamic> transaction) {
    final location = transaction['location'] as Map<String, dynamic>?;
    if (location != null) {
      final city = location['city'] as String?;
      final region = location['region'] as String?;
      if (city != null && region != null) return '$city, $region';
      return city;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAccounts(BuildContext context) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) throw Exception('No Plaid connection found');
    
    try {
      final url = Uri.parse('$_plaidBaseUrl/accounts/get');
      final headers = {'Content-Type': 'application/json', 'User-Agent': 'FinSight/1.0.0'};
      final body = json.encode({'client_id': _plaidClientId, 'secret': _plaidSecret, 'access_token': accessToken});
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cachedAccounts = List<Map<String, dynamic>>.from(data['accounts'] ?? []);
        return _cachedAccounts!;
      } else {
        throw Exception('Failed to fetch accounts from Plaid');
      }
    } catch (e) {
      throw Exception('Failed to fetch accounts: $e');
    }
  }

  Future<Map<String, double>> getAccountBalances() async {
    final accounts = await getAccounts(_getDummyContext());
    double checking = 0, savings = 0, creditCardBalance = 0, investment = 0;

    for (final account in accounts) {
      final balance = (account['balances']['current'] as num?)?.toDouble() ?? 0.0;
      final type = (account['type'] as String?)?.toLowerCase();
      final subtype = (account['subtype'] as String?)?.toLowerCase();

      if (type == 'depository') {
        if (subtype == 'checking') checking += balance;
        else if (subtype == 'savings') savings += balance;
        else checking += balance;
      } else if (type == 'credit') {
        creditCardBalance += balance.abs();
      } else if (type == 'investment') {
        investment += balance;
      }
    }
    
    return {
      'checking': checking, 'savings': savings, 'creditCardBalance': creditCardBalance,
      'investmentAccount': investment, 'netWorth': checking + savings - creditCardBalance + investment,
    };
  }

  Future<bool> disconnectInstitution() async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return false;
    
    try {
      final url = Uri.parse('$_plaidBaseUrl/item/remove');
      final headers = {'Content-Type': 'application/json', 'User-Agent': 'FinSight/1.0.0'};
      final body = json.encode({'client_id': _plaidClientId, 'secret': _plaidSecret, 'access_token': accessToken});
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        await _secureStorage.delete(key: _SECURE_ACCESS_TOKEN_KEY);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_ITEM_ID_KEY);
        _accessToken = null;
        _cachedAccounts = null;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasPlaidConnection() async {
    final token = await _getAccessToken();
    return token != null && token.isNotEmpty;
  }

  BuildContext _getDummyContext() {
    return WidgetsBinding.instance.rootElement!;
  }
}