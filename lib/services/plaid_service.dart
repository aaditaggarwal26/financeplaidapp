import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finsight/models/transaction.dart' as app_model;

class PlaidService {
  // Plaid configuration
  static const String _plaidClientId = '67214ae1946242001a565c22';
  static const String _plaidSecret = 'ad0125a2ad3c2a8844fa781568053e';
  static const String _plaidBaseUrl = 'https://sandbox.plaid.com';
  
  // Preferences keys
  static const String _ACCESS_TOKEN_KEY = 'plaid_access_token';
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
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo-user-${DateTime.now().millisecondsSinceEpoch}';
    
    final url = Uri.parse('$_plaidBaseUrl/link/token/create');
    final headers = {'Content-Type': 'application/json'};
    
    final body = json.encode({
      'client_id': _plaidClientId,
      'secret': _plaidSecret,
      'user': {
        'client_user_id': userId,
      },
      'client_name': 'FinSight',
      'products': ['transactions', 'accounts', 'identity'],
      'country_codes': ['US'],
      'language': 'en',
      'account_filters': {
        'depository': {
          'account_subtypes': ['checking', 'savings']
        },
        'credit': {
          'account_subtypes': ['credit card']
        },
        'investment': {
          'account_subtypes': ['401k', 'ira', 'investment']
        }
      }
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['link_token'];
      } else {
        print('Failed to create link token: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception in createLinkToken: $e');
      return null;
    }
  }

  // Step 2: Exchange public token for access token
  Future<bool> exchangePublicToken(String publicToken) async {
    final url = Uri.parse('$_plaidBaseUrl/item/public_token/exchange');
    final headers = {'Content-Type': 'application/json'};
    
    final body = json.encode({
      'client_id': _plaidClientId,
      'secret': _plaidSecret,
      'public_token': publicToken,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String accessToken = data['access_token'];
        final String itemId = data['item_id'];
        
        // Save access token locally
        await _saveAccessToken(accessToken, itemId);
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

  // Save access token locally
  Future<void> _saveAccessToken(String accessToken, String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ACCESS_TOKEN_KEY, accessToken);
      await prefs.setString(_ITEM_ID_KEY, itemId);
      
      // Cache locally for current session
      _accessToken = accessToken;
      
      print('Successfully saved access token locally');
    } catch (e) {
      print('Error saving access token locally: $e');
    }
  }

  // Fetch transactions from Plaid
  Future<List<app_model.Transaction>> fetchTransactions({
    required BuildContext context,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365));
    final end = endDate ?? now;
    
    // Format dates as YYYY-MM-DD
    final formattedStartDate = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final formattedEndDate = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      throw Exception('No Plaid connection found');
    }
    
    try {
      final url = Uri.parse('$_plaidBaseUrl/transactions/get');
      final headers = {'Content-Type': 'application/json'};
      
      List<dynamic> allTransactions = [];
      int offset = 0;
      bool hasMore = true;
      
      // Fetch all transactions with pagination
      while (hasMore) {
        final body = json.encode({
          'client_id': _plaidClientId,
          'secret': _plaidSecret,
          'access_token': accessToken,
          'start_date': formattedStartDate,
          'end_date': formattedEndDate,
          'options': {
            'count': 500,
            'offset': offset,
          },
        });

        final response = await http.post(url, headers: headers, body: body);
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> transactions = data['transactions'] ?? [];
          
          allTransactions.addAll(transactions);
          
          // Check if we need to fetch more
          final totalTransactions = data['total_transactions'] ?? 0;
          hasMore = (offset + transactions.length) < totalTransactions;
          offset += transactions.length;
          
          if (transactions.length < 500) {
            hasMore = false;
          }
        } else {
          print('Failed to fetch transactions: ${response.statusCode}');
          throw Exception('Failed to fetch transactions from Plaid');
        }
      }
      
      // Convert Plaid transactions to app's Transaction model
      final transactions = allTransactions.map((trx) {
        final amount = trx['amount'] != null ? double.parse(trx['amount'].toString()) : 0.0;
        final category = _mapPlaidCategory(trx['category'], trx['name'] ?? '');
        
        return app_model.Transaction(
          id: trx['transaction_id'],
          date: DateTime.parse(trx['date']),
          description: trx['name'] ?? 'Unknown Transaction',
          category: category,
          amount: amount.abs(),
          account: trx['account_owner'] ?? 'Unknown Account', 
          transactionType: amount > 0 ? 'Debit' : 'Credit',
          isPersonal: false,
        );
      }).toList();
      
      return transactions;
    } catch (e) {
      print('Exception in fetchTransactions: $e');
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  // Enhanced category mapping with subscription detection
  String _mapPlaidCategory(List<dynamic>? plaidCategories, String transactionName) {
    if (plaidCategories == null || plaidCategories.isEmpty) {
      return _detectSubscriptionOrMisc(transactionName);
    }
    
    final primaryCategory = plaidCategories.first.toString().toLowerCase();
    final detailedCategory = plaidCategories.length > 1 ? plaidCategories.last.toString().toLowerCase() : '';
    final name = transactionName.toLowerCase();
    
    // Check for subscriptions first
    if (_isSubscription(name, primaryCategory, detailedCategory)) {
      return 'Subscriptions';
    }
    
    // Food categories
    if (primaryCategory.contains('food') || detailedCategory.contains('restaurant') || 
        detailedCategory.contains('fast food') || detailedCategory.contains('cafe')) {
      return 'Dining Out';
    }
    
    // Grocery stores
    if (detailedCategory.contains('grocery') || detailedCategory.contains('supermarket') || 
        name.contains('whole foods') || name.contains('trader joe') || name.contains('safeway') ||
        name.contains('kroger') || name.contains('walmart') || name.contains('target')) {
      return 'Groceries';
    }
    
    // Shopping
    if (primaryCategory.contains('shop') || primaryCategory.contains('retail') ||
        detailedCategory.contains('department') || detailedCategory.contains('clothing') ||
        detailedCategory.contains('electronics')) {
      return 'Shopping';
    }
    
    // Transportation
    if (primaryCategory.contains('transport') || detailedCategory.contains('gas') ||
        detailedCategory.contains('parking') || detailedCategory.contains('taxi') ||
        detailedCategory.contains('public transport') || name.contains('uber') || name.contains('lyft')) {
      return 'Transportation';
    }
    
    // Entertainment
    if (primaryCategory.contains('entertainment') || primaryCategory.contains('recreation') ||
        detailedCategory.contains('movie') || detailedCategory.contains('music') ||
        detailedCategory.contains('sports') || detailedCategory.contains('gym')) {
      return 'Entertainment';
    }
    
    // Healthcare
    if (primaryCategory.contains('healthcare') || primaryCategory.contains('medical') ||
        detailedCategory.contains('doctor') || detailedCategory.contains('pharmacy') ||
        detailedCategory.contains('hospital')) {
      return 'Healthcare';
    }
    
    // Insurance
    if (primaryCategory.contains('insurance') || detailedCategory.contains('insurance')) {
      return 'Insurance';
    }
    
    // Utilities
    if (primaryCategory.contains('utilities') || detailedCategory.contains('internet') ||
        detailedCategory.contains('phone') || detailedCategory.contains('electric') ||
        detailedCategory.contains('water') || detailedCategory.contains('gas')) {
      return 'Utilities';
    }
    
    // Housing/Rent
    if (primaryCategory.contains('rent') || primaryCategory.contains('mortgage') ||
        detailedCategory.contains('housing') || detailedCategory.contains('rent')) {
      return 'Rent';
    }
    
    return 'Miscellaneous';
  }

  // Check if transaction is a subscription
  bool _isSubscription(String name, String primaryCategory, String detailedCategory) {
    // Common subscription patterns
    final subscriptionPatterns = [
      'netflix', 'spotify', 'amazon prime', 'hulu', 'disney plus', 'apple music',
      'youtube premium', 'adobe', 'microsoft', 'google', 'dropbox', 'icloud',
      'gym', 'fitness', 'subscription', 'monthly', 'recurring'
    ];
    
    for (final pattern in subscriptionPatterns) {
      if (name.contains(pattern)) {
        return true;
      }
    }
    
    // Check categories for subscription indicators
    if (primaryCategory.contains('subscription') || detailedCategory.contains('subscription') ||
        primaryCategory.contains('recurring') || detailedCategory.contains('recurring')) {
      return true;
    }
    
    return false;
  }

  String _detectSubscriptionOrMisc(String transactionName) {
    if (_isSubscription(transactionName.toLowerCase(), '', '')) {
      return 'Subscriptions';
    }
    return 'Miscellaneous';
  }

  // Get access token
  Future<String?> _getAccessToken() async {
    if (_accessToken != null) {
      return _accessToken;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_ACCESS_TOKEN_KEY);
      return _accessToken;
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }

  // Fetch account information
  Future<List<Map<String, dynamic>>> getAccounts(BuildContext context) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      throw Exception('No Plaid connection found');
    }
    
    try {
      final url = Uri.parse('$_plaidBaseUrl/accounts/get');
      final headers = {'Content-Type': 'application/json'};
      
      final body = json.encode({
        'client_id': _plaidClientId,
        'secret': _plaidSecret,
        'access_token': accessToken,
      });

      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> accounts = data['accounts'] ?? [];
        
        final mappedAccounts = accounts.map<Map<String, dynamic>>((account) => {
          'id': account['account_id'],
          'name': account['name'],
          'mask': account['mask'],
          'type': account['type'],
          'subtype': account['subtype'],
          'balance': {
            'available': account['balances']['available'],
            'current': account['balances']['current'],
            'limit': account['balances']['limit'],
          },
          'institution': data['item']['institution_id'] ?? 'Unknown',
        }).toList();
        
        _cachedAccounts = mappedAccounts;
        return mappedAccounts;
      } else {
        print('Failed to fetch accounts: ${response.statusCode}');
        throw Exception('Failed to fetch accounts from Plaid');
      }
    } catch (e) {
      print('Exception in getAccounts: $e');
      throw Exception('Failed to fetch accounts: $e');
    }
  }

  // Get account balances in app format
  Future<Map<String, double>> getAccountBalances() async {
    try {
      final accounts = await getAccounts(_getDummyContext());
      
      double checking = 0;
      double savings = 0;
      double creditCardBalance = 0;
      double investmentAccount = 0;
      
      for (final account in accounts) {
        final balance = (account['balance']['current'] ?? 0).toDouble();
        final type = account['type'].toString().toLowerCase();
        final subtype = account['subtype'].toString().toLowerCase();
        
        if (type == 'depository') {
          if (subtype == 'checking') {
            checking += balance;
          } else if (subtype == 'savings') {
            savings += balance;
          } else {
            checking += balance; // Default depository accounts to checking
          }
        } else if (type == 'credit') {
          creditCardBalance += balance.abs(); // Credit balances should be positive for debt
        } else if (type == 'investment') {
          investmentAccount += balance;
        }
      }
      
      final netWorth = checking + savings - creditCardBalance + investmentAccount;
      
      return {
        'checking': checking,
        'savings': savings,
        'creditCardBalance': creditCardBalance,
        'investmentAccount': investmentAccount,
        'netWorth': netWorth,
      };
    } catch (e) {
      print('Error getting account balances: $e');
      return {
        'checking': 0,
        'savings': 0,
        'creditCardBalance': 0,
        'investmentAccount': 0,
        'netWorth': 0,
      };
    }
  }

  // Disconnect Plaid institution
  Future<bool> disconnectInstitution(BuildContext context) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return false;
    
    try {
      final url = Uri.parse('$_plaidBaseUrl/item/remove');
      final headers = {'Content-Type': 'application/json'};
      
      final body = json.encode({
        'client_id': _plaidClientId,
        'secret': _plaidSecret,
        'access_token': accessToken,
      });

      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        // Remove from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_ACCESS_TOKEN_KEY);
        await prefs.remove(_ITEM_ID_KEY);
        
        // Clear cached data
        _accessToken = null;
        _cachedAccounts = null;
        
        return true;
      } else {
        print('Failed to disconnect institution: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Exception in disconnectInstitution: $e');
      return false;
    }
  }

  // Check if user has Plaid connection
  Future<bool> hasPlaidConnection() async {
    final accessToken = await _getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  // Helper method to create a dummy context
  BuildContext _getDummyContext() {
    return WidgetsBinding.instance.rootElement!;
  }
}