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
  // Plaid configuration read from .env file
  static String get _plaidClientId => dotenv.env['PLAID_CLIENT_ID'] ?? '';
  static String get _plaidSecret => dotenv.env['PLAID_SECRET'] ?? '';
  // Reads the environment from your .env file. Defaults to 'sandbox' if not set.
  static String get _plaidEnv => dotenv.env['PLAID_ENV'] ?? 'sandbox'; 
  
  static String get _plaidBaseUrl {
    switch (_plaidEnv.toLowerCase()) {
      case 'production': 
        return 'https://production.plaid.com';
      case 'development': 
        return 'https://development.plaid.com';
      case 'sandbox':
      default: 
        return 'https://sandbox.plaid.com';
    }
  }
  
  static List<String> get _plaidProducts => 
    (dotenv.env['PLAID_PRODUCTS'] ?? 'auth,transactions,identity,assets')
      .split(',')
      .map((p) => p.trim())
      .toList();
      
  static List<String> get _plaidCountryCodes => 
    (dotenv.env['PLAID_COUNTRY_CODES'] ?? 'US,CA')
      .split(',')
      .map((c) => c.trim())
      .toList();

  final _secureStorage = const FlutterSecureStorage();
  static const String _SECURE_ACCESS_TOKEN_KEY = 'plaid_access_token_secure';
  static const String _ITEM_ID_KEY = 'plaid_item_id';
  static const String _LAST_SUCCESSFUL_SYNC_KEY = 'plaid_last_sync';

  static final PlaidService _instance = PlaidService._internal();
  factory PlaidService() => _instance;
  PlaidService._internal();

  String? _accessToken;
  List<Map<String, dynamic>>? _cachedAccounts;
  final Map<String, String?> _logoCache = {};

  /// Creates a link token for Plaid Link initialization
  Future<String?> createLinkToken() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 
      'user_${DateTime.now().millisecondsSinceEpoch}';
    
    final url = Uri.parse('$_plaidBaseUrl/link/token/create');
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'FinSight/1.0.0',
      'Plaid-Version': '2020-09-14',
    };
    
    final redirectUri = dotenv.env['PLAID_REDIRECT_URI'];

    final body = {
      'client_id': _plaidClientId,
      'secret': _plaidSecret,
      'user': {
        'client_user_id': userId,
        'email_address': FirebaseAuth.instance.currentUser?.email,
        'phone_number': null,
        'legal_name': FirebaseAuth.instance.currentUser?.displayName,
      },
      'client_name': 'FinSight Personal Finance',
      'products': _plaidProducts,
      'country_codes': _plaidCountryCodes,
      'language': 'en',
      'webhook': null, // Add webhook URL for production
      'link_customization_name': null,
      if (redirectUri != null && redirectUri.isNotEmpty) 
        'redirect_uri': redirectUri,
      // Production-specific configurations
      'android_package_name': null,
      'account_filters': {
        'depository': {
          'account_subtypes': ['checking', 'savings', 'money market'],
        },
        'credit': {
          'account_subtypes': ['credit card'],
        },
        'investment': {
          'account_subtypes': ['401k', 'ira', 'retirement', 'brokerage'],
        },
      },
      'required_if_supported_products': ['identity'],
      'optional_products': ['assets', 'liabilities'],
    };

    try {
      print('Creating link token for environment: $_plaidEnv');
      final response = await http.post(
        url, 
        headers: headers, 
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        print('Link token created successfully');
        return responseBody['link_token'];
      } else {
        print('PlaidService Error (createLinkToken): ${response.statusCode}');
        print('Response body: ${response.body}');
        final errorData = json.decode(response.body);
        throw PlaidException(
          errorData['error_code'] ?? 'UNKNOWN_ERROR',
          errorData['error_message'] ?? 'Failed to create link token',
        );
      }
    } catch (e) {
      print('PlaidService Exception (createLinkToken): $e');
      if (e is PlaidException) rethrow;
      throw PlaidException('NETWORK_ERROR', 'Failed to connect to Plaid: ${e.toString()}');
    }
  }

  /// Exchanges public token for access token
  Future<bool> exchangePublicToken(String publicToken) async {
    final url = Uri.parse('$_plaidBaseUrl/item/public_token/exchange');
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'FinSight/1.0.0',
      'Plaid-Version': '2020-09-14',
    };
    
    final body = json.encode({
      'client_id': _plaidClientId,
      'secret': _plaidSecret,
      'public_token': publicToken,
    });

    try {
      final response = await http.post(
        url, 
        headers: headers, 
        body: body,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveAccessToken(data['access_token'], data['item_id']);
        print('Access token exchanged successfully');
        
        // Record successful sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_LAST_SUCCESSFUL_SYNC_KEY, DateTime.now().toIso8601String());
        
        return true;
      } else {
        print('PlaidService Error (exchangePublicToken): ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('PlaidService Exception (exchangePublicToken): $e');
      return false;
    }
  }
  
  /// Fetches real transactions from connected accounts
  Future<List<app_model.Transaction>> fetchTransactions({
    required BuildContext context, 
    DateTime? startDate, 
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      throw PlaidException('NO_ACCESS_TOKEN', 'No Plaid connection found. Please connect your account first.');
    }

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365)); // Get last year by default
    final end = endDate ?? now;
    final formattedStartDate = DateFormat('yyyy-MM-dd').format(start);
    final formattedEndDate = DateFormat('yyyy-MM-dd').format(end);

    final url = Uri.parse('$_plaidBaseUrl/transactions/get');
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'FinSight/1.0.0',
      'Plaid-Version': '2020-09-14',
    };
    
    List<dynamic> allPlaidTransactions = [];
    int offset = 0;
    bool hasMore = true;
    int totalFetched = 0;
    const int maxTransactions = 2000; // Reasonable limit for mobile app

    print('Fetching real transactions from $_plaidEnv environment...');
    print('Date range: $formattedStartDate to $formattedEndDate');

    while (hasMore && totalFetched < maxTransactions) {
      final body = json.encode({
        'client_id': _plaidClientId,
        'secret': _plaidSecret,
        'access_token': accessToken,
        'start_date': formattedStartDate,
        'end_date': formattedEndDate,
        'options': {
          'count': 500,
          'offset': offset,
          'include_personal_finance_category': true,
          'include_original_description': true,
          'include_personal_finance_category_icon_url': true,
        },
      });

      try {
        final response = await http.post(
          url, 
          headers: headers, 
          body: body,
        ).timeout(const Duration(seconds: 45));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final transactions = data['transactions'] as List<dynamic>? ?? [];
          allPlaidTransactions.addAll(transactions);
          
          final total = data['total_transactions'] as int? ?? 0;
          offset += transactions.length;
          totalFetched += transactions.length;
          hasMore = offset < total && transactions.isNotEmpty;
          
          print('Fetched ${transactions.length} transactions (${totalFetched}/$total total)');
        } else {
          print('PlaidService Error (fetchTransactions): ${response.statusCode}');
          print('Response body: ${response.body}');
          
          final errorData = json.decode(response.body);
          
          // Handle specific Plaid errors
          if (response.statusCode == 400) {
            final errorCode = errorData['error_code'];
            if (errorCode == 'ITEM_LOGIN_REQUIRED') {
              throw PlaidException(errorCode, 'Please reconnect your bank account as your login credentials have changed.');
            }
          }
          
          throw PlaidException(
            errorData['error_code'] ?? 'API_ERROR',
            errorData['error_message'] ?? 'Failed to fetch transactions from Plaid',
          );
        }
      } catch (e) {
        print('PlaidService Exception (fetchTransactions): $e');
        if (e is PlaidException) rethrow;
        throw PlaidException('NETWORK_ERROR', 'Failed to fetch transactions: ${e.toString()}');
      }
    }
    
    print('Processing ${allPlaidTransactions.length} real transactions...');
    final processedTransactions = await Future.wait(
      allPlaidTransactions.map((trx) => _processPlaidTransaction(trx)).toList()
    );
    
    // Update last successful sync
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_LAST_SUCCESSFUL_SYNC_KEY, DateTime.now().toIso8601String());
    
    print('Successfully processed ${processedTransactions.length} real transactions');
    return processedTransactions;
  }

  /// Gets real account information from connected banks
  Future<List<Map<String, dynamic>>> getAccounts(BuildContext context, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedAccounts != null) {
      print('Returning cached account data');
      return _cachedAccounts!;
    }
    
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      throw PlaidException('NO_ACCESS_TOKEN', 'No Plaid connection found');
    }

    final url = Uri.parse('$_plaidBaseUrl/accounts/get');
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'FinSight/1.0.0',
      'Plaid-Version': '2020-09-14',
    };
    
    final body = json.encode({
      'client_id': _plaidClientId,
      'secret': _plaidSecret,
      'access_token': accessToken,
      'options': {
        'account_ids': null, // Get all accounts
      },
    });

    try {
      final response = await http.post(
        url, 
        headers: headers, 
        body: body,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accounts = List<Map<String, dynamic>>.from(data['accounts'] ?? []);
        final item = data['item'] as Map<String, dynamic>?;
        final institutionId = item?['institution_id'] ?? 'Unknown';
        
        // Enhance account data with institution info
        for (var acc in accounts) {
          acc['institution'] = institutionId;
          acc['last_update'] = DateTime.now().toIso8601String();
        }
        
        _cachedAccounts = accounts;
        print('Fetched ${accounts.length} real accounts from connected institutions');
        return accounts;
      } else {
        print('PlaidService Error (getAccounts): ${response.statusCode}');
        print('Response body: ${response.body}');
        
        final errorData = json.decode(response.body);
        throw PlaidException(
          errorData['error_code'] ?? 'API_ERROR',
          errorData['error_message'] ?? 'Failed to fetch accounts',
        );
      }
    } catch (e) {
      print('PlaidService Exception (getAccounts): $e');
      if (e is PlaidException) rethrow;
      throw PlaidException('NETWORK_ERROR', 'Failed to connect to bank: ${e.toString()}');
    }
  }

  /// Gets real-time account balances
  Future<Map<String, double>> getAccountBalances({bool forceRefresh = false}) async {
    try {
      final accounts = await getAccounts(WidgetsBinding.instance.rootElement!, forceRefresh: forceRefresh);
      
      double checking = 0, savings = 0, creditCardBalance = 0, investment = 0;

      for (final account in accounts) {
        final balances = account['balances'] as Map<String, dynamic>?;
        if (balances == null) continue;
        
        final balance = (balances['current'] as num?)?.toDouble() ?? 0.0;
        final available = (balances['available'] as num?)?.toDouble();
        final type = (account['type'] as String?)?.toLowerCase();
        final subtype = (account['subtype'] as String?)?.toLowerCase();

        print('Account: ${account['name']} ($type/$subtype) - Balance: \$${balance.toStringAsFixed(2)}');

        switch (type) {
          case 'depository':
            if (subtype == 'checking') {
              checking += available ?? balance;
            } else if (subtype == 'savings') {
              savings += available ?? balance;
            } else {
              checking += available ?? balance; // Default to checking
            }
            break;
          case 'credit':
            creditCardBalance += balance.abs(); // Credit card balances are typically negative
            break;
          case 'investment':
            investment += balance;
            break;
        }
      }
      
      final netWorth = checking + savings + investment - creditCardBalance;
      
      print('Real Account Balances:');
      print('  Checking: \$${checking.toStringAsFixed(2)}');
      print('  Savings: \$${savings.toStringAsFixed(2)}');
      print('  Credit Cards: \$${creditCardBalance.toStringAsFixed(2)}');
      print('  Investments: \$${investment.toStringAsFixed(2)}');
      print('  Net Worth: \$${netWorth.toStringAsFixed(2)}');
      
      return {
        'checking': checking,
        'savings': savings,
        'creditCardBalance': creditCardBalance,
        'investmentAccount': investment,
        'netWorth': netWorth,
      };
    } catch (e) {
      print('Error getting real account balances: $e');
      rethrow;
    }
  }

  /// Processes a raw Plaid transaction into our app model
  Future<app_model.Transaction> _processPlaidTransaction(Map<String, dynamic> trx) async {
    final amount = (trx['amount'] as num?)?.toDouble() ?? 0.0;
    final merchantName = trx['merchant_name'] as String? ?? 
                        _extractMerchantFromDescription(trx['name'] as String? ?? 'Unknown');
    final originalDescription = trx['name'] as String? ?? 'Unknown Transaction';
    final date = DateTime.parse(trx['date'] as String);
    final accountId = trx['account_id'] as String? ?? 'Unknown';

    // Enhanced category mapping using Plaid's personal finance categories
    String category = _mapPlaidCategoryEnhanced(trx);
    double confidence = _calculateCategoryConfidence(trx);

    // Enhanced logo fetching
    final plaidLogoUrl = trx['logo_url'] as String?;
    final website = trx['website'] as String?;
    final logoUrl = plaidLogoUrl ?? await _getMerchantLogo(merchantName, website);
    
    // Enhanced location extraction
    final location = _extractLocationEnhanced(trx);
    
    // Detect if this is a recurring transaction
    final isRecurring = _detectRecurringTransactionEnhanced(trx, originalDescription);
    
    return app_model.Transaction(
      id: trx['transaction_id'] as String,
      date: date,
      description: merchantName,
      category: category,
      amount: amount.abs(),
      account: accountId,
      transactionType: amount < 0 ? 'Debit' : 'Credit',
      isPersonal: false, // All Plaid transactions are bank transactions
      merchantName: merchantName,
      merchantLogoUrl: logoUrl,
      merchantWebsite: website,
      originalDescription: originalDescription,
      plaidCategory: (trx['personal_finance_category']?['detailed'] as String?) ?? 
                    (trx['category'] as List?)?.join(', '),
      confidence: confidence,
      isRecurring: isRecurring,
      paymentMethod: trx['payment_channel'] as String?,
      location: location,
      iso_currency_code: trx['iso_currency_code'] as String? ?? 'USD',
    );
  }

  /// Enhanced category mapping using Plaid's personal finance categories
  String _mapPlaidCategoryEnhanced(Map<String, dynamic> trx) {
    // First try Plaid's personal finance category (most accurate)
    if (trx['personal_finance_category'] != null) {
      final pfc = trx['personal_finance_category'];
      final primary = pfc['primary']?.toString().toLowerCase() ?? '';
      final detailed = pfc['detailed']?.toString().toLowerCase() ?? '';
      
      // Map Plaid categories to our app categories
      if (primary.contains('food_and_drink')) {
        if (detailed.contains('groceries') || detailed.contains('supermarkets')) {
          return 'Groceries';
        }
        return 'Dining Out';
      }
      
      if (primary.contains('transportation')) return 'Transportation';
      if (primary.contains('shops') || primary.contains('retail')) return 'Shopping';
      if (primary.contains('medical') || primary.contains('healthcare')) return 'Healthcare';
      if (primary.contains('recreation') || primary.contains('entertainment')) return 'Entertainment';
      if (primary.contains('travel')) return 'Transportation'; // Map travel to transportation
      
      if (primary.contains('rent_and_utilities')) {
        if (detailed.contains('rent') || detailed.contains('mortgage')) return 'Rent';
        return 'Utilities';
      }
      
      if (detailed.contains('subscription') || detailed.contains('streaming')) return 'Subscriptions';
      if (detailed.contains('insurance')) return 'Insurance';
      if (primary.contains('bank_fees')) return 'Banking';
      
      return 'Miscellaneous';
    }
    
    // Fallback to legacy category array
    if (trx['category'] is List) {
      final categories = (trx['category'] as List).map((c) => c.toString().toLowerCase()).toList();
      
      if (categories.any((c) => ['food and drink', 'restaurants'].contains(c))) {
        if (categories.any((c) => ['groceries', 'supermarkets'].contains(c))) {
          return 'Groceries';
        }
        return 'Dining Out';
      }
      
      if (categories.any((c) => ['transportation', 'gas stations'].contains(c))) return 'Transportation';
      if (categories.any((c) => ['shops', 'clothing', 'electronics'].contains(c))) return 'Shopping';
      if (categories.any((c) => ['healthcare', 'medical'].contains(c))) return 'Healthcare';
      if (categories.any((c) => ['recreation', 'entertainment'].contains(c))) return 'Entertainment';
      if (categories.any((c) => ['utilities', 'telecommunication'].contains(c))) return 'Utilities';
      if (categories.any((c) => ['rent', 'mortgage'].contains(c))) return 'Rent';
    }
    
    // Final fallback: analyze description
    return _categorizeByDescription(trx['name'] ?? '');
  }

  /// Calculate confidence score for categorization
  double _calculateCategoryConfidence(Map<String, dynamic> trx) {
    double confidence = 0.3; // Base confidence
    
    // Higher confidence if we have personal finance category
    if (trx['personal_finance_category'] != null) {
      confidence = 0.9;
    } else if (trx['category'] != null && (trx['category'] as List).isNotEmpty) {
      confidence = 0.7;
    }
    
    // Boost confidence if we have merchant info
    if (trx['merchant_name'] != null && (trx['merchant_name'] as String).isNotEmpty) {
      confidence = (confidence + 0.1).clamp(0.0, 1.0);
    }
    
    return confidence;
  }

  /// Enhanced location extraction
  String? _extractLocationEnhanced(Map<String, dynamic> transaction) {
    final location = transaction['location'] as Map<String, dynamic>?;
    if (location != null) {
      final address = location['address'] as String?;
      final city = location['city'] as String?;
      final region = location['region'] as String?;
      final country = location['country'] as String?;
      
      // Build location string from available parts
      final parts = <String>[];
      if (city != null && city.isNotEmpty) parts.add(city);
      if (region != null && region.isNotEmpty) parts.add(region);
      if (country != null && country.isNotEmpty && country != 'US') parts.add(country);
      
      if (parts.isNotEmpty) return parts.join(', ');
      if (address != null && address.isNotEmpty) return address;
    }
    return null;
  }

  /// Enhanced recurring transaction detection
  bool _detectRecurringTransactionEnhanced(Map<String, dynamic> trx, String description) {
    // Check if Plaid has marked this as recurring
    final personalFinanceCategory = trx['personal_finance_category'] as Map<String, dynamic>?;
    if (personalFinanceCategory != null) {
      final detailed = personalFinanceCategory['detailed']?.toString().toLowerCase() ?? '';
      if (detailed.contains('subscription') || 
          detailed.contains('recurring') || 
          detailed.contains('monthly')) {
        return true;
      }
    }
    
    // Check description for recurring patterns
    final d = description.toLowerCase();
    return d.contains('subscription') || 
           d.contains('monthly') || 
           d.contains('recurring') ||
           _isKnownRecurringMerchant(d);
  }

  /// Check if merchant is known to be recurring
  bool _isKnownRecurringMerchant(String description) {
    final knownRecurring = [
      'netflix', 'spotify', 'amazon prime', 'hulu', 'disney', 'apple music', 
      'youtube premium', 'adobe', 'microsoft', 'google one', 'dropbox', 
      'electric', 'gas company', 'water', 'internet', 'phone', 'insurance',
      'gym', 'fitness', 'mortgage', 'rent', 'loan payment'
    ];
    
    return knownRecurring.any((pattern) => description.contains(pattern));
  }

  /// Extract clean merchant name from description
  String _extractMerchantFromDescription(String description) {
    // Remove common transaction codes and IDs
    String cleaned = description
        .replaceAll(RegExp(r'#\d+'), '') // Remove #numbers
        .replaceAll(RegExp(r'\d{4}\*+\d{4}'), '') // Remove card numbers
        .replaceAll(RegExp(r'[A-Z]{2}\d+'), '') // Remove state/country codes
        .trim();
    
    // Take first meaningful part
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      return parts.take(3).join(' ').trim(); // Take first 3 words max
    }
    
    return cleaned.isNotEmpty ? cleaned : description;
  }

  /// Categorize transaction by description analysis
  String _categorizeByDescription(String description) {
    final d = description.toLowerCase();
    
    // Grocery stores
    if (d.contains('grocery') || d.contains('market') || d.contains('supermarket') ||
        d.contains('whole foods') || d.contains('trader joe') || d.contains('safeway') ||
        d.contains('kroger') || d.contains('walmart') || d.contains('target')) {
      return 'Groceries';
    }
    
    // Restaurants and dining
    if (d.contains('restaurant') || d.contains('coffee') || d.contains('starbucks') ||
        d.contains('mcdonald') || d.contains('subway') || d.contains('pizza') ||
        d.contains('taco') || d.contains('burger')) {
      return 'Dining Out';
    }
    
    // Transportation
    if (d.contains('gas') || d.contains('fuel') || d.contains('uber') || 
        d.contains('lyft') || d.contains('parking') || d.contains('metro') ||
        d.contains('taxi') || d.contains('transportation')) {
      return 'Transportation';
    }
    
    // Shopping
    if (d.contains('amazon') || d.contains('ebay') || d.contains('best buy') ||
        d.contains('clothing') || d.contains('mall') || d.contains('store')) {
      return 'Shopping';
    }
    
    // Subscriptions
    if (d.contains('subscription') || d.contains('netflix') || d.contains('spotify') ||
        d.contains('hulu') || d.contains('disney') || d.contains('prime')) {
      return 'Subscriptions';
    }
    
    // Utilities
    if (d.contains('electric') || d.contains('gas bill') || d.contains('water') ||
        d.contains('utility') || d.contains('internet') || d.contains('phone')) {
      return 'Utilities';
    }
    
    return 'Miscellaneous';
  }
  
  /// Enhanced merchant logo fetching
  Future<String?> _getMerchantLogo(String merchantName, String? website) async {
    final cacheKey = website ?? merchantName.toLowerCase();
    if (_logoCache.containsKey(cacheKey)) return _logoCache[cacheKey];

    String? logoUrl;
    
    // Try website-based logo services
    if (website != null && website.isNotEmpty) {
      final domain = _extractDomain(website);
      logoUrl = await _tryLogoService('https://logo.clearbit.com/$domain');
      logoUrl ??= await _tryLogoService('https://favicons.githubusercontent.com/$domain');
    }
    
    // Try merchant name inference
    if (logoUrl == null) {
      final inferredWebsite = await _inferWebsiteFromMerchant(merchantName);
      if (inferredWebsite != null) {
        logoUrl = await _tryLogoService('https://logo.clearbit.com/$inferredWebsite');
        logoUrl ??= await _tryLogoService('https://favicons.githubusercontent.com/$inferredWebsite');
      }
    }
    
    // Fallback to Google favicon service
    if (logoUrl == null) {
      final domain = website ?? await _inferWebsiteFromMerchant(merchantName);
      if (domain != null) {
        logoUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
      }
    }

    _logoCache[cacheKey] = logoUrl;
    print('Found logo for $merchantName: $logoUrl');
    return logoUrl;
  }

  Future<String?> _tryLogoService(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 && 
          (response.headers['content-type']?.startsWith('image/') ?? false)) {
        return url;
      }
    } catch (e) {
      // Ignore and try next service
    }
    return null;
  }

  String _extractDomain(String website) {
    try {
      return website
          .replaceAll(RegExp(r'https?://'), '')
          .replaceAll(RegExp(r'^www\.'), '')
          .split('/')[0]
          .toLowerCase();
    } catch (e) {
      return '';
    }
  }

  /// Enhanced merchant website inference
  Future<String?> _inferWebsiteFromMerchant(String merchantName) async {
    final commonWebsites = {
      // Major retailers
      'amazon': 'amazon.com',
      'target': 'target.com',
      'walmart': 'walmart.com',
      'costco': 'costco.com',
      'best buy': 'bestbuy.com',
      'home depot': 'homedepot.com',
      'lowes': 'lowes.com',
      'cvs': 'cvs.com',
      'walgreens': 'walgreens.com',
      
      // Food & Restaurants
      'starbucks': 'starbucks.com',
      'mcdonalds': 'mcdonalds.com',
      'subway': 'subway.com',
      'chipotle': 'chipotle.com',
      'dunkin': 'dunkindonuts.com',
      'whole foods': 'wholefoodsmarket.com',
      
      // Tech & Streaming
      'apple': 'apple.com',
      'google': 'google.com',
      'microsoft': 'microsoft.com',
      'netflix': 'netflix.com',
      'spotify': 'spotify.com',
      'hulu': 'hulu.com',
      'disney': 'disneyplus.com',
      
      // Transportation
      'uber': 'uber.com',
      'lyft': 'lyft.com',
      'airbnb': 'airbnb.com',
      
      // Financial
      'paypal': 'paypal.com',
      'venmo': 'venmo.com',
      'chase': 'chase.com',
      'wells fargo': 'wellsfargo.com',
      'bank of america': 'bankofamerica.com',
      
      // Gas Stations
      'shell': 'shell.com',
      'exxon': 'exxon.com',
      'chevron': 'chevron.com',
      'bp': 'bp.com',
      'mobil': 'mobil.com',
    };
    
    final cleanName = merchantName.toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .trim();
    
    // Check for exact matches first
    for (final entry in commonWebsites.entries) {
      if (cleanName.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // For single word merchants, try .com
    if (cleanName.isNotEmpty && !cleanName.contains(' ') && cleanName.length > 3) {
      return '$cleanName.com';
    }
    
    return null;
  }

  /// Secure token storage
  Future<void> _saveAccessToken(String accessToken, String itemId) async {
    try {
      await _secureStorage.write(key: _SECURE_ACCESS_TOKEN_KEY, value: accessToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ITEM_ID_KEY, itemId);
      _accessToken = accessToken;
      print('Access token saved securely');
    } catch (e) {
      print('PlaidService Exception (_saveAccessToken): $e');
      throw PlaidException('STORAGE_ERROR', 'Failed to save credentials securely');
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

  /// Check if we have a valid Plaid connection
  Future<bool> hasPlaidConnection() async {
    final token = await _getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Get last successful sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncTimeStr = prefs.getString(_LAST_SUCCESSFUL_SYNC_KEY);
      if (syncTimeStr != null) {
        return DateTime.parse(syncTimeStr);
      }
    } catch (e) {
      print('Error getting last sync time: $e');
    }
    return null;
  }

  /// Clear all cached data
  void clearCaches() {
    _cachedAccounts = null;
    _logoCache.clear();
    print('Plaid caches cleared');
  }

  /// Remove stored credentials (for logout)
  Future<void> disconnect() async {
    try {
      await _secureStorage.delete(key: _SECURE_ACCESS_TOKEN_KEY);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ITEM_ID_KEY);
      await prefs.remove(_LAST_SUCCESSFUL_SYNC_KEY);
      
      _accessToken = null;
      clearCaches();
      print('Plaid connection removed');
    } catch (e) {
      print('Error disconnecting Plaid: $e');
    }
  }
}

/// Custom exception class for Plaid errors
class PlaidException implements Exception {
  final String code;
  final String message;
  
  PlaidException(this.code, this.message);
  
  @override
  String toString() => 'PlaidException($code): $message';
}
