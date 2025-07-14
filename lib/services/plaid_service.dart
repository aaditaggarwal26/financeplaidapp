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
  static String get _plaidEnv => dotenv.env['PLAID_ENV'] ?? 'development'; 
  
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
    (dotenv.env['PLAID_PRODUCTS'] ?? 'transactions,auth,accounts')
      .split(',')
      .map((p) => p.trim())
      .toList();
      
  static List<String> get _plaidCountryCodes => 
    (dotenv.env['PLAID_COUNTRY_CODES'] ?? 'US')
      .split(',')
      .map((c) => c.trim())
      .toList();

  final _secureStorage = const FlutterSecureStorage();
  static const String _SECURE_ACCESS_TOKENS_KEY = 'plaid_access_tokens_secure';
  static const String _CONNECTED_ACCOUNTS_KEY = 'plaid_connected_accounts';
  static const String _LAST_SUCCESSFUL_SYNC_KEY = 'plaid_last_sync';

  static final PlaidService _instance = PlaidService._internal();
  factory PlaidService() => _instance;
  PlaidService._internal();

  List<String> _accessTokens = [];
  List<ConnectedAccount> _connectedAccounts = [];
  List<Map<String, dynamic>>? _cachedAccounts;
  final Map<String, String?> _logoCache = {};

  /// Validates Plaid configuration
  bool _validateConfiguration() {
    if (_plaidClientId.isEmpty) {
      print('PlaidService Error: PLAID_CLIENT_ID is empty');
      return false;
    }
    if (_plaidSecret.isEmpty) {
      print('PlaidService Error: PLAID_SECRET is empty');
      return false;
    }
    
    print('PlaidService Configuration:');
    print('- Environment: $_plaidEnv');
    print('- Base URL: $_plaidBaseUrl');
    print('- Client ID: ${_plaidClientId.substring(0, 10)}...');
    print('- Products: $_plaidProducts');
    print('- Countries: $_plaidCountryCodes');
    
    return true;
  }

  /// Creates a link token for Plaid Link initialization
  Future<String?> createLinkToken() async {
    print('=== PlaidService: createLinkToken called ===');
    
    if (!_validateConfiguration()) {
      throw PlaidException('INVALID_CONFIG', 'Plaid configuration is invalid. Please check your .env file.');
    }

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
      'webhook': null,
      if (redirectUri != null && redirectUri.isNotEmpty) 
        'redirect_uri': redirectUri,
    };

    try {
      print('Creating link token for environment: $_plaidEnv');
      print('Request URL: ${url.toString()}');
      
      final response = await http.post(
        url, 
        headers: headers, 
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        print('Link token created successfully');
        return responseBody['link_token'];
      } else {
        print('PlaidService Error (createLinkToken): ${response.statusCode}');
        print('Response body: ${response.body}');
        
        try {
          final errorData = json.decode(response.body);
          final errorCode = errorData['error_code'] ?? 'UNKNOWN_ERROR';
          final errorMessage = errorData['error_message'] ?? 'Failed to create link token';
          
          if (errorCode == 'INVALID_CREDENTIALS') {
            throw PlaidException(errorCode, 'Invalid Plaid credentials. Please check your Client ID and Secret in the .env file.');
          } else if (errorCode == 'INVALID_PRODUCT') {
            throw PlaidException(errorCode, 'Invalid product configuration. Your account may not have access to the requested products.');
          }
          
          throw PlaidException(errorCode, errorMessage);
        } catch (e) {
          if (e is PlaidException) rethrow;
          throw PlaidException('PARSE_ERROR', 'Failed to parse error response: ${response.body}');
        }
      }
    } catch (e) {
      print('PlaidService Exception (createLinkToken): $e');
      if (e is PlaidException) rethrow;
      
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('No address associated with hostname')) {
        throw PlaidException('NETWORK_ERROR', 'Cannot connect to Plaid servers. Please check your internet connection and try again.');
      } else if (e.toString().contains('Connection timed out')) {
        throw PlaidException('TIMEOUT_ERROR', 'Connection timed out. Please try again.');
      }
      
      throw PlaidException('UNEXPECTED_ERROR', 'Unexpected error: ${e.toString()}');
    }
  }

  /// Exchanges public token for access token
  Future<bool> exchangePublicToken(String publicToken) async {
    print('=== PlaidService: exchangePublicToken called ===');
    
    if (!_validateConfiguration()) {
      return false;
    }

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
      print('Exchanging public token...');
      final response = await http.post(
        url, 
        headers: headers, 
        body: body,
      ).timeout(const Duration(seconds: 30));
      
      print('Exchange response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _addAccessToken(data['access_token'], data['item_id']);
        print('Access token exchanged successfully');
        
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

  /// Add a new access token to the list
  Future<void> _addAccessToken(String accessToken, String itemId) async {
    try {
      await _loadAccessTokens();
      
      // Get institution info for this access token
      final institutionInfo = await _getInstitutionInfo(accessToken);
      
      final newAccount = ConnectedAccount(
        accessToken: accessToken,
        itemId: itemId,
        institutionName: institutionInfo['name'] ?? 'Unknown Bank',
        institutionId: institutionInfo['institution_id'] ?? '',
        connectedAt: DateTime.now(),
      );
      
      _connectedAccounts.add(newAccount);
      _accessTokens.add(accessToken);
      
      await _saveAccessTokens();
      await _saveConnectedAccounts();
      
      print('Access token and account info saved securely');
    } catch (e) {
      print('PlaidService Exception (_addAccessToken): $e');
      throw PlaidException('STORAGE_ERROR', 'Failed to save credentials securely');
    }
  }

  /// Get institution information
  Future<Map<String, dynamic>> _getInstitutionInfo(String accessToken) async {
    try {
      final url = Uri.parse('$_plaidBaseUrl/item/get');
      final headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'FinSight/1.0.0',
        'Plaid-Version': '2020-09-14',
      };
      
      final body = json.encode({
        'client_id': _plaidClientId,
        'secret': _plaidSecret,
        'access_token': accessToken,
      });

      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final institutionId = data['item']['institution_id'];
        
        // Get institution details
        final instUrl = Uri.parse('$_plaidBaseUrl/institutions/get_by_id');
        final instBody = json.encode({
          'client_id': _plaidClientId,
          'secret': _plaidSecret,
          'institution_id': institutionId,
          'country_codes': _plaidCountryCodes,
        });

        final instResponse = await http.post(instUrl, headers: headers, body: instBody);
        
        if (instResponse.statusCode == 200) {
          final instData = json.decode(instResponse.body);
          return {
            'institution_id': institutionId,
            'name': instData['institution']['name'],
            'url': instData['institution']['url'],
            'logo': instData['institution']['logo'],
            'primary_color': instData['institution']['primary_color'],
          };
        }
      }
      
      return {'name': 'Unknown Bank', 'institution_id': ''};
    } catch (e) {
      print('Error getting institution info: $e');
      return {'name': 'Unknown Bank', 'institution_id': ''};
    }
  }

  /// Load access tokens from secure storage
  Future<void> _loadAccessTokens() async {
    try {
      final tokensJson = await _secureStorage.read(key: _SECURE_ACCESS_TOKENS_KEY);
      final accountsJson = await _secureStorage.read(key: _CONNECTED_ACCOUNTS_KEY);
      
      if (tokensJson != null) {
        final tokensList = List<String>.from(json.decode(tokensJson));
        _accessTokens = tokensList;
      }
      
      if (accountsJson != null) {
        final accountsList = List<Map<String, dynamic>>.from(json.decode(accountsJson));
        _connectedAccounts = accountsList.map((json) => ConnectedAccount.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading access tokens: $e');
      _accessTokens = [];
      _connectedAccounts = [];
    }
  }

  /// Save access tokens to secure storage
  Future<void> _saveAccessTokens() async {
    try {
      await _secureStorage.write(
        key: _SECURE_ACCESS_TOKENS_KEY, 
        value: json.encode(_accessTokens)
      );
    } catch (e) {
      print('Error saving access tokens: $e');
    }
  }

  /// Save connected accounts info
  Future<void> _saveConnectedAccounts() async {
    try {
      final accountsJson = _connectedAccounts.map((account) => account.toJson()).toList();
      await _secureStorage.write(
        key: _CONNECTED_ACCOUNTS_KEY,
        value: json.encode(accountsJson)
      );
    } catch (e) {
      print('Error saving connected accounts: $e');
    }
  }

  /// Get all connected accounts
  Future<List<ConnectedAccount>> getConnectedAccounts() async {
    await _loadAccessTokens();
    return _connectedAccounts;
  }

  /// Disconnect a specific account
  Future<bool> disconnectAccount(String itemId) async {
    try {
      await _loadAccessTokens();
      
      // Find the account to disconnect
      final accountIndex = _connectedAccounts.indexWhere((account) => account.itemId == itemId);
      if (accountIndex == -1) return false;
      
      final account = _connectedAccounts[accountIndex];
      
      // Remove the item on Plaid's end
      final url = Uri.parse('$_plaidBaseUrl/item/remove');
      final headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'FinSight/1.0.0',
        'Plaid-Version': '2020-09-14',
      };
      
      final body = json.encode({
        'client_id': _plaidClientId,
        'secret': _plaidSecret,
        'access_token': account.accessToken,
      });

      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        // Remove from local storage
        _connectedAccounts.removeAt(accountIndex);
        _accessTokens.remove(account.accessToken);
        
        await _saveAccessTokens();
        await _saveConnectedAccounts();
        
        // Clear cache
        clearCaches();
        
        print('Account disconnected successfully');
        return true;
      } else {
        print('Error disconnecting account: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error disconnecting account: $e');
      return false;
    }
  }

  /// Check if we have any Plaid connections
  Future<bool> hasPlaidConnection() async {
    await _loadAccessTokens();
    return _accessTokens.isNotEmpty;
  }

  /// Get the first available access token
  Future<String?> _getAccessToken() async {
    await _loadAccessTokens();
    return _accessTokens.isNotEmpty ? _accessTokens.first : null;
  }

  /// Fetches real transactions from all connected accounts
  Future<List<app_model.Transaction>> fetchTransactions({
    required BuildContext context, 
    DateTime? startDate, 
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    print('=== PlaidService: fetchTransactions called ===');
    
    await _loadAccessTokens();
    
    if (_accessTokens.isEmpty) {
      print('No access tokens found');
      throw PlaidException('NO_ACCESS_TOKEN', 'No Plaid connection found. Please connect your account first.');
    }

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365));
    final end = endDate ?? now;
    
    List<app_model.Transaction> allTransactions = [];
    
    // Fetch transactions from all connected accounts
    for (final accessToken in _accessTokens) {
      try {
        final transactions = await _fetchTransactionsForToken(accessToken, start, end);
        allTransactions.addAll(transactions);
      } catch (e) {
        print('Error fetching transactions for token: $e');
        // Continue with other accounts even if one fails
      }
    }
    
    // Sort by date (newest first)
    allTransactions.sort((a, b) => b.date.compareTo(a.date));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_LAST_SUCCESSFUL_SYNC_KEY, DateTime.now().toIso8601String());
    
    print('Successfully processed ${allTransactions.length} total transactions from ${_accessTokens.length} accounts');
    return allTransactions;
  }

  /// Fetch transactions for a specific access token
  Future<List<app_model.Transaction>> _fetchTransactionsForToken(
    String accessToken, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    final formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);
    final formattedEndDate = DateFormat('yyyy-MM-dd').format(endDate);

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
    const int maxTransactions = 2000;

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
          
          print('Fetched ${transactions.length} transactions (${totalFetched}/$total total) for token');
        } else {
          print('PlaidService Error (fetchTransactions): ${response.statusCode}');
          print('Response body: ${response.body}');
          
          final errorData = json.decode(response.body);
          
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
        
        if (e.toString().contains('Failed host lookup')) {
          throw PlaidException('DNS_ERROR', 'Cannot resolve Plaid servers. Please check your internet connection.');
        }
        throw PlaidException('NETWORK_ERROR', 'Network error: ${e.toString()}');
      }
    }
    
    print('Processing ${allPlaidTransactions.length} transactions for token...');
    final processedTransactions = await Future.wait(
      allPlaidTransactions.map((trx) => _processPlaidTransaction(trx)).toList()
    );
    
    return processedTransactions;
  }

  /// Gets real account information from all connected banks
  Future<List<Map<String, dynamic>>> getAccounts(BuildContext context, {bool forceRefresh = false}) async {
    print('=== PlaidService: getAccounts called ===');
    
    if (!forceRefresh && _cachedAccounts != null) {
      print('Returning cached account data');
      return _cachedAccounts!;
    }
    
    await _loadAccessTokens();
    
    if (_accessTokens.isEmpty) {
      throw PlaidException('NO_ACCESS_TOKEN', 'No Plaid connection found');
    }

    List<Map<String, dynamic>> allAccounts = [];
    
    // Get accounts from all connected institutions
    for (final accessToken in _accessTokens) {
      try {
        final accounts = await _getAccountsForToken(accessToken);
        allAccounts.addAll(accounts);
      } catch (e) {
        print('Error getting accounts for token: $e');
        // Continue with other accounts
      }
    }
    
    _cachedAccounts = allAccounts;
    print('Fetched ${allAccounts.length} total accounts from ${_accessTokens.length} institutions');
    return allAccounts;
  }

  /// Get accounts for a specific access token
  Future<List<Map<String, dynamic>>> _getAccountsForToken(String accessToken) async {
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
        
        for (var acc in accounts) {
          acc['institution'] = institutionId;
          acc['last_update'] = DateTime.now().toIso8601String();
          acc['access_token'] = accessToken; // Add access token for tracking
        }
        
        return accounts;
      } else {
        print('PlaidService Error (getAccountsForToken): ${response.statusCode}');
        print('Response body: ${response.body}');
        
        final errorData = json.decode(response.body);
        throw PlaidException(
          errorData['error_code'] ?? 'API_ERROR',
          errorData['error_message'] ?? 'Failed to fetch accounts',
        );
      }
    } catch (e) {
      print('PlaidService Exception (getAccountsForToken): $e');
      if (e is PlaidException) rethrow;
      
      if (e.toString().contains('Failed host lookup')) {
        throw PlaidException('DNS_ERROR', 'Cannot resolve Plaid servers. Please check your internet connection.');
      }
      throw PlaidException('NETWORK_ERROR', 'Network error: ${e.toString()}');
    }
  }

  /// Gets real-time account balances from all connected accounts
  Future<Map<String, double>> getAccountBalances({bool forceRefresh = false}) async {
    print('=== PlaidService: getAccountBalances called ===');
    
    try {
      final accounts = await _getAccountsWithoutContext(forceRefresh: forceRefresh);
      
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
              checking += available ?? balance;
            }
            break;
          case 'credit':
            creditCardBalance += balance.abs();
            break;
          case 'investment':
            investment += balance;
            break;
        }
      }
      
      final netWorth = checking + savings + investment - creditCardBalance;
      
      print('Account Balances:');
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
      print('Error getting account balances: $e');
      rethrow;
    }
  }

  /// Helper method to get accounts without requiring context
  Future<List<Map<String, dynamic>>> _getAccountsWithoutContext({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedAccounts != null) {
      return _cachedAccounts!;
    }
    
    await _loadAccessTokens();
    
    if (_accessTokens.isEmpty) {
      throw PlaidException('NO_ACCESS_TOKEN', 'No Plaid connection found');
    }

    List<Map<String, dynamic>> allAccounts = [];
    
    for (final accessToken in _accessTokens) {
      try {
        final accounts = await _getAccountsForToken(accessToken);
        allAccounts.addAll(accounts);
      } catch (e) {
        print('Error getting accounts for token: $e');
      }
    }
    
    _cachedAccounts = allAccounts;
    return allAccounts;
  }

  // [Keep all the existing helper methods for processing transactions, mapping categories, etc.]
  Future<app_model.Transaction> _processPlaidTransaction(Map<String, dynamic> trx) async {
    final amount = (trx['amount'] as num?)?.toDouble() ?? 0.0;
    final merchantName = trx['merchant_name'] as String? ?? 
                        _extractMerchantFromDescription(trx['name'] as String? ?? 'Unknown');
    final originalDescription = trx['name'] as String? ?? 'Unknown Transaction';
    final date = DateTime.parse(trx['date'] as String);
    final accountId = trx['account_id'] as String? ?? 'Unknown';

    String category = _mapPlaidCategory(trx);
    double confidence = _calculateCategoryConfidence(trx);

    final plaidLogoUrl = trx['logo_url'] as String?;
    final website = trx['website'] as String?;
    final logoUrl = plaidLogoUrl ?? await _getMerchantLogo(merchantName, website);
    
    final location = _extractLocation(trx);
    final isRecurring = _detectRecurringTransaction(trx, originalDescription);
    
    return app_model.Transaction(
      id: trx['transaction_id'] as String,
      date: date,
      description: merchantName,
      category: category,
      amount: amount.abs(),
      account: accountId,
      transactionType: amount < 0 ? 'Debit' : 'Credit',
      isPersonal: false,
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

  String _mapPlaidCategory(Map<String, dynamic> trx) {
    if (trx['personal_finance_category'] != null) {
      final pfc = trx['personal_finance_category'];
      final primary = pfc['primary']?.toString().toLowerCase() ?? '';
      final detailed = pfc['detailed']?.toString().toLowerCase() ?? '';
      
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
      if (primary.contains('travel')) return 'Transportation';
      
      if (primary.contains('rent_and_utilities')) {
        if (detailed.contains('rent') || detailed.contains('mortgage')) return 'Rent';
        return 'Utilities';
      }
      
      if (detailed.contains('subscription') || detailed.contains('streaming')) return 'Subscriptions';
      if (detailed.contains('insurance')) return 'Insurance';
      if (primary.contains('bank_fees')) return 'Banking';
      
      return 'Miscellaneous';
    }
    
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
    
    return _categorizeByDescription(trx['name'] ?? '');
  }

  double _calculateCategoryConfidence(Map<String, dynamic> trx) {
    double confidence = 0.3;
    
    if (trx['personal_finance_category'] != null) {
      confidence = 0.9;
    } else if (trx['category'] != null && (trx['category'] as List).isNotEmpty) {
      confidence = 0.7;
    }
    
    if (trx['merchant_name'] != null && (trx['merchant_name'] as String).isNotEmpty) {
      confidence = (confidence + 0.1).clamp(0.0, 1.0);
    }
    
    return confidence;
  }

  String? _extractLocation(Map<String, dynamic> transaction) {
    final location = transaction['location'] as Map<String, dynamic>?;
    if (location != null) {
      final city = location['city'] as String?;
      final region = location['region'] as String?;
      
      final parts = <String>[];
      if (city != null && city.isNotEmpty) parts.add(city);
      if (region != null && region.isNotEmpty) parts.add(region);
      
      if (parts.isNotEmpty) return parts.join(', ');
    }
    return null;
  }

  bool _detectRecurringTransaction(Map<String, dynamic> trx, String description) {
    final personalFinanceCategory = trx['personal_finance_category'] as Map<String, dynamic>?;
    if (personalFinanceCategory != null) {
      final detailed = personalFinanceCategory['detailed']?.toString().toLowerCase() ?? '';
      if (detailed.contains('subscription') || 
          detailed.contains('recurring') || 
          detailed.contains('monthly')) {
        return true;
      }
    }
    
    final d = description.toLowerCase();
    return d.contains('subscription') || 
           d.contains('monthly') || 
           d.contains('recurring') ||
           _isKnownRecurringMerchant(d);
  }

  bool _isKnownRecurringMerchant(String description) {
    final knownRecurring = [
      'netflix', 'spotify', 'amazon prime', 'hulu', 'disney', 'apple music', 
      'youtube premium', 'adobe', 'microsoft', 'google one', 'dropbox', 
      'electric', 'gas company', 'water', 'internet', 'phone', 'insurance',
      'gym', 'fitness', 'mortgage', 'rent', 'loan payment'
    ];
    
    return knownRecurring.any((pattern) => description.contains(pattern));
  }

  String _extractMerchantFromDescription(String description) {
    String cleaned = description
        .replaceAll(RegExp(r'#\d+'), '')
        .replaceAll(RegExp(r'\d{4}\*+\d{4}'), '')
        .replaceAll(RegExp(r'[A-Z]{2}\d+'), '')
        .trim();
    
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      return parts.take(3).join(' ').trim();
    }
    
    return cleaned.isNotEmpty ? cleaned : description;
  }

  String _categorizeByDescription(String description) {
    final d = description.toLowerCase();
    
    if (d.contains('grocery') || d.contains('market') || d.contains('supermarket') ||
        d.contains('whole foods') || d.contains('trader joe') || d.contains('safeway') ||
        d.contains('kroger') || d.contains('walmart') || d.contains('target')) {
      return 'Groceries';
    }
    
    if (d.contains('restaurant') || d.contains('coffee') || d.contains('starbucks') ||
        d.contains('mcdonald') || d.contains('subway') || d.contains('pizza') ||
        d.contains('taco') || d.contains('burger')) {
      return 'Dining Out';
    }
    
    if (d.contains('gas') || d.contains('fuel') || d.contains('uber') || 
        d.contains('lyft') || d.contains('parking') || d.contains('metro') ||
        d.contains('taxi') || d.contains('transportation')) {
      return 'Transportation';
    }
    
    if (d.contains('amazon') || d.contains('ebay') || d.contains('best buy') ||
        d.contains('clothing') || d.contains('mall') || d.contains('store')) {
      return 'Shopping';
    }
    
    if (d.contains('subscription') || d.contains('netflix') || d.contains('spotify') ||
        d.contains('hulu') || d.contains('disney') || d.contains('prime')) {
      return 'Subscriptions';
    }
    
    if (d.contains('electric') || d.contains('gas bill') || d.contains('water') ||
        d.contains('utility') || d.contains('internet') || d.contains('phone')) {
      return 'Utilities';
    }
    
    return 'Miscellaneous';
  }
  
  Future<String?> _getMerchantLogo(String merchantName, String? website) async {
    final cacheKey = website ?? merchantName.toLowerCase();
    if (_logoCache.containsKey(cacheKey)) return _logoCache[cacheKey];

    String? logoUrl;
    
    if (website != null && website.isNotEmpty) {
      final domain = _extractDomain(website);
      logoUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
    } else {
      final inferredWebsite = _inferWebsiteFromMerchant(merchantName);
      if (inferredWebsite != null) {
        logoUrl = 'https://www.google.com/s2/favicons?domain=$inferredWebsite&sz=64';
      }
    }

    _logoCache[cacheKey] = logoUrl;
    return logoUrl;
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

  String? _inferWebsiteFromMerchant(String merchantName) {
    final commonWebsites = {
      'amazon': 'amazon.com',
      'target': 'target.com',
      'walmart': 'walmart.com',
      'starbucks': 'starbucks.com',
      'mcdonalds': 'mcdonalds.com',
      'apple': 'apple.com',
      'google': 'google.com',
      'netflix': 'netflix.com',
      'spotify': 'spotify.com',
      'uber': 'uber.com',
      'lyft': 'lyft.com',
    };
    
    final cleanName = merchantName.toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .trim();
    
    for (final entry in commonWebsites.entries) {
      if (cleanName.contains(entry.key)) {
        return entry.value;
      }
    }
    
    if (cleanName.isNotEmpty && !cleanName.contains(' ') && cleanName.length > 3) {
      return '$cleanName.com';
    }
    
    return null;
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

  /// Remove all stored credentials (for logout)
  Future<void> disconnectAll() async {
    try {
      // Remove all items on Plaid's end
      for (final account in _connectedAccounts) {
        try {
          await disconnectAccount(account.itemId);
        } catch (e) {
          print('Error disconnecting account ${account.institutionName}: $e');
        }
      }
      
      await _secureStorage.delete(key: _SECURE_ACCESS_TOKENS_KEY);
      await _secureStorage.delete(key: _CONNECTED_ACCOUNTS_KEY);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_LAST_SUCCESSFUL_SYNC_KEY);
      
      _accessTokens.clear();
      _connectedAccounts.clear();
      clearCaches();
      print('All Plaid connections removed');
    } catch (e) {
      print('Error disconnecting all Plaid accounts: $e');
    }
  }
}

/// Connected Account model
class ConnectedAccount {
  final String accessToken;
  final String itemId;
  final String institutionName;
  final String institutionId;
  final DateTime connectedAt;

  ConnectedAccount({
    required this.accessToken,
    required this.itemId,
    required this.institutionName,
    required this.institutionId,
    required this.connectedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'itemId': itemId,
      'institutionName': institutionName,
      'institutionId': institutionId,
      'connectedAt': connectedAt.toIso8601String(),
    };
  }

  factory ConnectedAccount.fromJson(Map<String, dynamic> json) {
    return ConnectedAccount(
      accessToken: json['accessToken'] ?? '',
      itemId: json['itemId'] ?? '',
      institutionName: json['institutionName'] ?? 'Unknown Bank',
      institutionId: json['institutionId'] ?? '',
      connectedAt: DateTime.parse(json['connectedAt'] ?? DateTime.now().toIso8601String()),
    );
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