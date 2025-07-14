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
  // --- Plaid Configuration ---
  static String get _plaidClientId => dotenv.env['PLAID_CLIENT_ID'] ?? '';
  static String get _plaidSecret => dotenv.env['PLAID_SECRET'] ?? '';
  static String get _plaidEnv => dotenv.env['PLAID_ENV'] ?? 'sandbox';
  static String get _plaidBaseUrl {
    switch (_plaidEnv.toLowerCase()) {
      case 'production': return 'https://production.plaid.com';
      case 'development': return 'https://development.plaid.com';
      default: return 'https://sandbox.plaid.com';
    }
  }
  static List<String> get _plaidProducts => (dotenv.env['PLAID_PRODUCTS'] ?? 'auth,transactions,identity').split(',').map((p) => p.trim()).toList();
  static List<String> get _plaidCountryCodes => (dotenv.env['PLAID_COUNTRY_CODES'] ?? 'US').split(',').map((c) => c.trim()).toList();

  // --- Secure Storage ---
  final _secureStorage = const FlutterSecureStorage();
  static const String _SECURE_ACCESS_TOKEN_KEY = 'plaid_access_token_secure';
  static const String _ITEM_ID_KEY = 'plaid_item_id';

  // --- Singleton Pattern ---
  static final PlaidService _instance = PlaidService._internal();
  factory PlaidService() => _instance;
  PlaidService._internal();

  // --- In-memory Cache ---
  String? _accessToken;
  List<Map<String, dynamic>>? _cachedAccounts;
  final Map<String, String?> _logoCache = {};

  // --- API Methods ---

  Future<String?> createLinkToken() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    final url = Uri.parse('$_plaidBaseUrl/link/token/create');
    final headers = {'Content-Type': 'application/json', 'User-Agent': 'FinSight/1.0.0'};
    final redirectUri = dotenv.env['PLAID_REDIRECT_URI'];

    final body = {
      'client_id': _plaidClientId, 'secret': _plaidSecret,
      'user': {'client_user_id': userId},
      'client_name': 'FinSight', 'products': _plaidProducts,
      'country_codes': _plaidCountryCodes, 'language': 'en',
      if (redirectUri != null && redirectUri.isNotEmpty) 'redirect_uri': redirectUri,
    };

    try {
      final response = await http.post(url, headers: headers, body: json.encode(body));
      if (response.statusCode == 200) {
        return json.decode(response.body)['link_token'];
      }
      print('PlaidService Error (createLinkToken): ${response.statusCode} ${response.body}');
      throw Exception('Failed to create link token.');
    } catch (e) {
      print('PlaidService Exception (createLinkToken): $e');
      rethrow;
    }
  }

  Future<bool> exchangePublicToken(String publicToken) async {
    final url = Uri.parse('$_plaidBaseUrl/item/public_token/exchange');
    final headers = {'Content-Type': 'application/json', 'User-Agent': 'FinSight/1.0.0'};
    final body = json.encode({'client_id': _plaidClientId, 'secret': _plaidSecret, 'public_token': publicToken});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveAccessToken(data['access_token'], data['item_id']);
        return true;
      }
      print('PlaidService Error (exchangePublicToken): ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      print('PlaidService Exception (exchangePublicToken): $e');
      return false;
    }
  }
  
  Future<List<app_model.Transaction>> fetchTransactions({required BuildContext context, DateTime? startDate, DateTime? endDate}) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) throw Exception('Not connected to Plaid.');

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 730)); // Fetch 2 years of data
    final end = endDate ?? now;
    final formattedStartDate = DateFormat('yyyy-MM-dd').format(start);
    final formattedEndDate = DateFormat('yyyy-MM-dd').format(end);

    final url = Uri.parse('$_plaidBaseUrl/transactions/get');
    final headers = {'Content-Type': 'application/json', 'User-Agent': 'FinSight/1.0.0'};
    
    List<dynamic> allPlaidTransactions = [];
    int offset = 0;
    bool hasMore = true;

    while (hasMore) {
      final body = json.encode({
        'client_id': _plaidClientId, 'secret': _plaidSecret, 'access_token': accessToken,
        'start_date': formattedStartDate, 'end_date': formattedEndDate,
        'options': {
          'count': 500, 
          'offset': offset, 
          'include_personal_finance_category': true,
          'include_logo_and_counterparty_beta': true, // Enable logo enrichment
        },
      });

      try {
        final response = await http.post(url, headers: headers, body: body);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final transactions = data['transactions'] as List<dynamic>? ?? [];
          allPlaidTransactions.addAll(transactions);
          final total = data['total_transactions'] as int? ?? 0;
          offset += transactions.length;
          hasMore = offset < total;
        } else {
          print('PlaidService Error (fetchTransactions): ${response.statusCode} ${response.body}');
          throw Exception('Failed to fetch transactions from Plaid.');
        }
      } catch (e) {
        print('PlaidService Exception (fetchTransactions): $e');
        rethrow;
      }
    }
    
    // Process all transactions and fetch logos in parallel
    final processedTransactions = await Future.wait(
      allPlaidTransactions.map((trx) => _processPlaidTransaction(trx)).toList()
    );
    
    return processedTransactions;
  }

  Future<List<Map<String, dynamic>>> getAccounts(BuildContext context) async {
    if (_cachedAccounts != null) return _cachedAccounts!;
    final accessToken = await _getAccessToken();
    if (accessToken == null) return [];

    final url = Uri.parse('$_plaidBaseUrl/accounts/get');
    final headers = {'Content-Type': 'application/json', 'User-Agent': 'FinSight/1.0.0'};
    final body = json.encode({'client_id': _plaidClientId, 'secret': _plaidSecret, 'access_token': accessToken});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accounts = List<Map<String, dynamic>>.from(data['accounts'] ?? []);
        final institution = data['item']['institution_id'] ?? 'Unknown';
        for (var acc in accounts) {
          acc['institution'] = institution;
        }
        _cachedAccounts = accounts;
        return accounts;
      }
      print('PlaidService Error (getAccounts): ${response.statusCode} ${response.body}');
      return [];
    } catch (e) {
      print('PlaidService Exception (getAccounts): $e');
      return [];
    }
  }

  Future<Map<String, double>> getAccountBalances() async {
    final accounts = await getAccounts(WidgetsBinding.instance.rootElement!);
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
        creditCardBalance += balance;
      } else if (type == 'investment') {
        investment += balance;
      }
    }
    
    return {
      'checking': checking, 'savings': savings, 'creditCardBalance': creditCardBalance.abs(),
      'investmentAccount': investment, 'netWorth': checking + savings + investment - creditCardBalance.abs(),
    };
  }

  // --- Data Processing and Enrichment ---

  Future<app_model.Transaction> _processPlaidTransaction(Map<String, dynamic> trx) async {
    final amount = (trx['amount'] as num?)?.toDouble() ?? 0.0;
    
    // Extract merchant information with fallbacks
    String merchantName = 'Unknown';
    String? website;
    String? logoUrl;

    // Try to get enriched merchant data first
    if (trx['counterparties'] != null && (trx['counterparties'] as List).isNotEmpty) {
      final counterparty = (trx['counterparties'] as List)[0];
      merchantName = counterparty['name'] as String? ?? merchantName;
      website = counterparty['website'] as String?;
      logoUrl = counterparty['logo_url'] as String?;
    }

    // Fallback to merchant_name or original description
    if (merchantName == 'Unknown') {
      merchantName = trx['merchant_name'] as String? ?? trx['name'] as String? ?? 'Unknown';
    }

    // If no website from counterparty, try logo_url or infer from merchant name
    if (website == null && logoUrl == null) {
      website = await _inferWebsiteFromMerchant(merchantName);
    }

    final originalDescription = trx['name'] as String? ?? 'Unknown Transaction';
    final date = DateTime.parse(trx['date'] as String);

    String category = _mapPlaidCategory(trx);
    double? confidence = (trx['personal_finance_category'] != null) ? 0.9 : (trx['category'] != null ? 0.7 : 0.3);

    // Enhanced logo fetching with multiple fallbacks
    if (logoUrl == null) {
      logoUrl = await _getMerchantLogo(merchantName, website);
    }
    
    return app_model.Transaction(
      id: trx['transaction_id'] as String,
      date: date,
      description: merchantName,
      category: category,
      amount: amount.abs(),
      account: trx['account_id'] as String? ?? 'Unknown',
      transactionType: amount < 0 ? 'Debit' : 'Credit',
      isPersonal: false,
      merchantName: merchantName,
      merchantLogoUrl: logoUrl,
      merchantWebsite: website,
      originalDescription: originalDescription,
      plaidCategory: (trx['personal_finance_category']?['detailed'] as String?) ?? (trx['category'] as List?)?.join(', '),
      confidence: confidence,
      isRecurring: _detectRecurringTransaction(originalDescription),
      paymentMethod: trx['payment_channel'] as String?,
      location: _extractLocation(trx),
      iso_currency_code: trx['iso_currency_code'] as String?,
    );
  }

  // Enhanced logo fetching with multiple services and caching
  Future<String?> _getMerchantLogo(String merchantName, String? website) async {
    final cacheKey = website ?? merchantName.toLowerCase();
    
    // Check cache first
    if (_logoCache.containsKey(cacheKey)) {
      return _logoCache[cacheKey];
    }

    String? logoUrl;

    // Try multiple approaches to get logos
    if (website != null && website.isNotEmpty) {
      logoUrl = await _tryMultipleLogoServices(website);
    }

    // If no website or logo found, try to infer website from merchant name
    if (logoUrl == null) {
      final inferredWebsite = await _inferWebsiteFromMerchant(merchantName);
      if (inferredWebsite != null) {
        logoUrl = await _tryMultipleLogoServices(inferredWebsite);
      }
    }

    // Cache the result (even if null to avoid repeated failed attempts)
    _logoCache[cacheKey] = logoUrl;
    
    return logoUrl;
  }

  Future<String?> _tryMultipleLogoServices(String website) async {
    final domain = _extractDomain(website);
    if (domain.isEmpty) return null;

    final logoServices = [
      'https://logo.clearbit.com/$domain',
      'https://www.google.com/s2/favicons?domain=$domain&sz=64',
      'https://logo.uplead.com/$domain',
      'https://img.logo.dev/$domain?token=pk_X5dCdDzSSO6vDudH5weAAg', // Alternative service
    ];

    for (final logoUrl in logoServices) {
      try {
        final response = await http.head(Uri.parse(logoUrl))
            .timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          // Additional check: make sure it's actually an image
          final contentType = response.headers['content-type'] ?? '';
          if (contentType.startsWith('image/')) {
            print('Found logo for $domain: $logoUrl');
            return logoUrl;
          }
        }
      } catch (e) {
        // Continue to next service
        continue;
      }
    }

    // Last resort: Google favicon (almost always works)
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=32';
  }

  String _extractDomain(String website) {
    try {
      // Remove protocol and www
      String domain = website
          .replaceAll(RegExp(r'https?://'), '')
          .replaceAll(RegExp(r'^www\.'), '')
          .split('/')[0]
          .split('?')[0];
      
      return domain.toLowerCase();
    } catch (e) {
      return '';
    }
  }

  Future<String?> _inferWebsiteFromMerchant(String merchantName) async {
    // Common merchant mappings
    final merchantMap = {
      'starbucks': 'starbucks.com',
      'amazon': 'amazon.com',
      'target': 'target.com',
      'walmart': 'walmart.com',
      'mcdonalds': 'mcdonalds.com',
      'apple': 'apple.com',
      'google': 'google.com',
      'microsoft': 'microsoft.com',
      'netflix': 'netflix.com',
      'spotify': 'spotify.com',
      'uber': 'uber.com',
      'lyft': 'lyft.com',
      'airbnb': 'airbnb.com',
      'paypal': 'paypal.com',
      'venmo': 'venmo.com',
      'chase': 'chase.com',
      'wells fargo': 'wellsfargo.com',
      'bank of america': 'bankofamerica.com',
      'whole foods': 'wholefoodsmarket.com',
      'costco': 'costco.com',
      'home depot': 'homedepot.com',
      'lowes': 'lowes.com',
      'best buy': 'bestbuy.com',
      'cvs': 'cvs.com',
      'walgreens': 'walgreens.com',
      'rite aid': 'riteaid.com',
      'shell': 'shell.com',
      'exxon': 'exxon.com',
      'chevron': 'chevron.com',
      'bp': 'bp.com',
      'mobil': 'mobil.com',
      'dunkin': 'dunkindonuts.com',
      'subway': 'subway.com',
      'chipotle': 'chipotle.com',
    };

    final cleanName = merchantName.toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '') // Remove special characters
        .trim();

    // Direct match
    if (merchantMap.containsKey(cleanName)) {
      return merchantMap[cleanName];
    }

    // Partial match
    for (final entry in merchantMap.entries) {
      if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
        return entry.value;
      }
    }

    // Try simple heuristic: merchantname.com
    if (cleanName.isNotEmpty && !cleanName.contains(' ')) {
      return '$cleanName.com';
    }

    return null;
  }

  String _mapPlaidCategory(Map<String, dynamic> trx) {
    if (trx['personal_finance_category'] != null) {
      final pfc = trx['personal_finance_category'];
      final primary = pfc['primary']?.toString().toLowerCase() ?? '';
      final detailed = pfc['detailed']?.toString().toLowerCase() ?? '';
      
      if (primary.contains('food_and_drink')) return detailed.contains('groceries') ? 'Groceries' : 'Dining Out';
      if (primary.contains('transportation')) return 'Transportation';
      if (primary.contains('shops')) return 'Shopping';
      if (primary.contains('medical')) return 'Healthcare';
      if (primary.contains('recreation') || primary.contains('entertainment')) return 'Entertainment';
      if (primary.contains('travel')) return 'Travel';
      if (primary.contains('rent_and_utilities')) return detailed.contains('rent') ? 'Rent' : 'Utilities';
      if (detailed.contains('subscription')) return 'Subscriptions';
      if (detailed.contains('insurance')) return 'Insurance';
      return 'Miscellaneous';
    }
    return _fallbackCategorizeTransaction(trx['name'] ?? '');
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

  bool _detectRecurringTransaction(String description) {
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

  // --- Helper Methods ---

  Future<void> _saveAccessToken(String accessToken, String itemId) async {
    try {
      await _secureStorage.write(key: _SECURE_ACCESS_TOKEN_KEY, value: accessToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ITEM_ID_KEY, itemId);
      _accessToken = accessToken;
    } catch (e) { 
      print('PlaidService Exception (_saveAccessToken): $e'); 
    }
  }

  Future<String?> _getAccessToken() async {
    if (_accessToken != null) return _accessToken;
    try {
      _accessToken = await _secureStorage.read(key: _SECURE_ACCESS_TOKEN_KEY);
      return _accessToken;
    } catch (e) {
      print('PlaidService Exception (_getAccessToken): $e');
      return null;
    }
  }

  Future<bool> hasPlaidConnection() async {
    final token = await _getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Clear caches when needed
  void clearCaches() {
    _cachedAccounts = null;
    _logoCache.clear();
  }
}