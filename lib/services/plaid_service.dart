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

  // Enhanced merchant logo fetching
  Future<String?> _getMerchantLogo(String merchantName) async {
    try {
      // Clean merchant name for logo lookup
      final cleanName = merchantName.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
      
      // Try common merchant mappings first
      final commonLogos = {
        'amazon': 'amazon.com',
        'apple': 'apple.com',
        'starbucks': 'starbucks.com',
        'mcdonalds': 'mcdonalds.com',
        'walmart': 'walmart.com',
        'target': 'target.com',
        'costco': 'costco.com',
        'uber': 'uber.com',
        'lyft': 'lyft.com',
        'netflix': 'netflix.com',
        'spotify': 'spotify.com',
        'google': 'google.com',
        'microsoft': 'microsoft.com',
        'facebook': 'facebook.com',
        'tesla': 'tesla.com',
        'nike': 'nike.com',
        'adidas': 'adidas.com',
        'bestbuy': 'bestbuy.com',
        'homedepot': 'homedepot.com',
        'lowes': 'lowes.com',
        'wholefoods': 'wholefoodsmarket.com',
        'traderjoes': 'traderjoes.com',
        'safeway': 'safeway.com',
        'kroger': 'kroger.com',
        'chipotle': 'chipotle.com',
        'panera': 'panerabread.com',
        'chickfila': 'chick-fil-a.com',
        'subway': 'subway.com',
        'tacobell': 'tacobell.com',
        'pizzahut': 'pizzahut.com',
        'dominos': 'dominos.com',
        'shell': 'shell.com',
        'exxon': 'exxon.com',
        'chevron': 'chevron.com',
        'bp': 'bp.com',
        'cvs': 'cvs.com',
        'walgreens': 'walgreens.com',
        'verizon': 'verizon.com',
        'att': 'att.com',
        'tmobile': 't-mobile.com',
        'chase': 'chase.com',
        'wellsfargo': 'wellsfargo.com',
        'bankofamerica': 'bankofamerica.com',
      };
      
      String? domain;
      for (final entry in commonLogos.entries) {
        if (cleanName.contains(entry.key)) {
          domain = entry.value;
          break;
        }
      }
      
      // If no direct match, try to guess domain
      if (domain == null) {
        // Extract first meaningful word for domain guessing
        final words = cleanName.split(' ').where((w) => w.length > 2).toList();
        if (words.isNotEmpty) {
          domain = '${words.first}.com';
        }
      }
      
      if (domain != null) {
        // Try Clearbit Logo API
        final logoUrl = 'https://logo.clearbit.com/$domain';
        try {
          final response = await http.head(Uri.parse(logoUrl));
          if (response.statusCode == 200) {
            return logoUrl;
          }
        } catch (e) {
          // Clearbit failed, continue to fallback
        }
        
        // Fallback to favicon
        return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
      }
      
      return null;
    } catch (e) {
      print('Error getting merchant logo: $e');
      return null;
    }
  }

  // Fetch transactions from Plaid with proper categorization
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
            'include_personal_finance_category': true,
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
      
      print('Fetched ${allTransactions.length} raw transactions from Plaid');
      
      // Process transactions with proper categorization and logos
      final List<app_model.Transaction> processedTransactions = [];
      
      for (final trx in allTransactions) {
        try {
          final amount = trx['amount'] != null ? double.parse(trx['amount'].toString()) : 0.0;
          final merchantName = trx['merchant_name'] ?? trx['name'] ?? 'Unknown Transaction';
          final description = trx['name'] ?? 'Unknown Transaction';
          final date = DateTime.parse(trx['date']);
          
          // Get category from Plaid's personal finance category or fallback
          String category = 'Miscellaneous';
          double? confidence;
          
          if (trx['personal_finance_category'] != null) {
            final pfc = trx['personal_finance_category'];
            category = _mapPlaidPersonalFinanceCategory(pfc);
            confidence = 0.9; // High confidence for Plaid categorization
          } else if (trx['category'] != null && trx['category'].isNotEmpty) {
            category = _mapPlaidLegacyCategory(trx['category']);
            confidence = 0.7; // Medium confidence for legacy categorization
          } else {
            category = _fallbackCategorizeTransaction(description);
            confidence = 0.3; // Low confidence for fallback
          }
          
          // Get merchant logo asynchronously
          String? logoUrl;
          String? website;
          try {
            logoUrl = await _getMerchantLogo(merchantName);
            // Extract domain from logo URL for website
            if (logoUrl != null && logoUrl.contains('clearbit.com/')) {
              website = logoUrl.split('clearbit.com/').last;
            }
          } catch (e) {
            print('Error getting logo for $merchantName: $e');
          }
          
          // Detect recurring transactions
          bool isRecurring = _detectRecurringTransaction(description, amount);
          
          final transaction = app_model.Transaction(
            id: trx['transaction_id'],
            date: date,
            description: merchantName,
            category: category,
            amount: amount.abs(),
            account: trx['account_owner'] ?? 'Unknown Account', 
            transactionType: amount > 0 ? 'Debit' : 'Credit',
            isPersonal: false,
            merchantName: merchantName,
            merchantLogoUrl: logoUrl,
            merchantWebsite: website,
            originalDescription: description,
            plaidCategory: trx['category']?.isNotEmpty == true ? trx['category'].join(', ') : null,
            confidence: confidence,
            isRecurring: isRecurring,
            paymentMethod: trx['payment_channel'],
            location: _extractLocation(trx),
            iso_currency_code: trx['iso_currency_code'],
            unofficial_currency_code: trx['unofficial_currency_code'],
          );
          
          processedTransactions.add(transaction);
        } catch (e) {
          print('Error processing transaction: $e');
          continue;
        }
      }
      
      print('Successfully processed ${processedTransactions.length} transactions with enhanced data');
      return processedTransactions;
    } catch (e) {
      print('Exception in fetchTransactions: $e');
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  // Map Plaid's personal finance categories to app categories
  String _mapPlaidPersonalFinanceCategory(Map<String, dynamic> pfc) {
    final primary = pfc['primary']?.toString().toLowerCase() ?? '';
    final detailed = pfc['detailed']?.toString().toLowerCase() ?? '';
    
    // Food and drink
    if (primary.contains('food_and_drink')) {
      if (detailed.contains('restaurant') || detailed.contains('fast_food') || 
          detailed.contains('coffee') || detailed.contains('bar')) {
        return 'Dining Out';
      }
      if (detailed.contains('groceries') || detailed.contains('supermarket')) {
        return 'Groceries';
      }
      return 'Dining Out';
    }
    
    // Transportation
    if (primary.contains('transportation')) {
      return 'Transportation';
    }
    
    // General merchandise/shopping
    if (primary.contains('general_merchandise') || primary.contains('shops')) {
      return 'Shopping';
    }
    
    // Healthcare
    if (primary.contains('medical') || primary.contains('healthcare')) {
      return 'Healthcare';
    }
    
    // Entertainment
    if (primary.contains('entertainment') || primary.contains('recreation')) {
      return 'Entertainment';
    }
    
    // Travel
    if (primary.contains('travel')) {
      return 'Transportation';
    }
    
    // Rent and utilities
    if (primary.contains('rent_and_utilities')) {
      if (detailed.contains('rent') || detailed.contains('mortgage')) {
        return 'Rent';
      }
      return 'Utilities';
    }
    
    // Subscription services
    if (detailed.contains('subscription') || detailed.contains('streaming') ||
        detailed.contains('software') || detailed.contains('membership')) {
      return 'Subscriptions';
    }
    
    // Insurance
    if (detailed.contains('insurance')) {
      return 'Insurance';
    }
    
    // Banking
    if (primary.contains('bank_fees') || primary.contains('loan_payments')) {
      return 'Banking';
    }
    
    return 'Miscellaneous';
  }

  // Map legacy Plaid categories
  String _mapPlaidLegacyCategory(List<dynamic> categories) {
    if (categories.isEmpty) return 'Miscellaneous';
    
    final primaryCategory = categories.first.toString().toLowerCase();
    final detailedCategory = categories.length > 1 ? categories.last.toString().toLowerCase() : '';
    
    if (primaryCategory.contains('food')) {
      if (detailedCategory.contains('restaurant') || detailedCategory.contains('fast food')) {
        return 'Dining Out';
      }
      if (detailedCategory.contains('grocery')) {
        return 'Groceries';
      }
      return 'Dining Out';
    }
    
    if (primaryCategory.contains('shop') || primaryCategory.contains('retail')) {
      return 'Shopping';
    }
    
    if (primaryCategory.contains('transport')) {
      return 'Transportation';
    }
    
    if (primaryCategory.contains('recreation') || primaryCategory.contains('entertainment')) {
      return 'Entertainment';
    }
    
    if (primaryCategory.contains('healthcare') || primaryCategory.contains('medical')) {
      return 'Healthcare';
    }
    
    if (primaryCategory.contains('service')) {
      if (detailedCategory.contains('utilities') || detailedCategory.contains('internet') ||
          detailedCategory.contains('phone') || detailedCategory.contains('cable')) {
        return 'Utilities';
      }
    }
    
    if (primaryCategory.contains('payment')) {
      if (detailedCategory.contains('rent') || detailedCategory.contains('mortgage')) {
        return 'Rent';
      }
      if (detailedCategory.contains('insurance')) {
        return 'Insurance';
      }
    }
    
    return 'Miscellaneous';
  }

  // Fallback categorization for transactions without Plaid categories
  String _fallbackCategorizeTransaction(String description) {
    final lowerDesc = description.toLowerCase();
    
    if (lowerDesc.contains('grocery') || lowerDesc.contains('market') || 
        lowerDesc.contains('food') && !lowerDesc.contains('restaurant')) {
      return 'Groceries';
    }
    
    if (lowerDesc.contains('restaurant') || lowerDesc.contains('coffee') ||
        lowerDesc.contains('starbucks') || lowerDesc.contains('mcdonald')) {
      return 'Dining Out';
    }
    
    if (lowerDesc.contains('gas') || lowerDesc.contains('uber') || 
        lowerDesc.contains('lyft') || lowerDesc.contains('parking')) {
      return 'Transportation';
    }
    
    if (lowerDesc.contains('amazon') || lowerDesc.contains('target') ||
        lowerDesc.contains('walmart') || lowerDesc.contains('shop')) {
      return 'Shopping';
    }
    
    if (lowerDesc.contains('netflix') || lowerDesc.contains('spotify') ||
        lowerDesc.contains('subscription') || lowerDesc.contains('monthly')) {
      return 'Subscriptions';
    }
    
    return 'Miscellaneous';
  }

  // Detect recurring transactions
  bool _detectRecurringTransaction(String description, double amount) {
    final lowerDesc = description.toLowerCase();
    
    // Check for subscription keywords
    if (lowerDesc.contains('subscription') || lowerDesc.contains('monthly') || 
        lowerDesc.contains('annual') || lowerDesc.contains('recurring')) {
      return true;
    }
    
    // Check for known subscription services
    final subscriptionServices = [
      'netflix', 'spotify', 'amazon prime', 'hulu', 'disney', 'apple music',
      'youtube premium', 'adobe', 'microsoft', 'google', 'dropbox'
    ];
    
    for (final service in subscriptionServices) {
      if (lowerDesc.contains(service)) {
        return true;
      }
    }
    
    // Check for utility patterns
    if (lowerDesc.contains('electric') || lowerDesc.contains('gas company') ||
        lowerDesc.contains('water') || lowerDesc.contains('internet') ||
        lowerDesc.contains('phone') || lowerDesc.contains('insurance')) {
      return true;
    }
    
    return false;
  }

  // Extract location information from transaction data
  String? _extractLocation(Map<String, dynamic> transaction) {
    final location = transaction['location'];
    if (location != null) {
      final city = location['city'];
      final region = location['region'];
      if (city != null && region != null) {
        return '$city, $region';
      } else if (city != null) {
        return city;
      }
    }
    return null;
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