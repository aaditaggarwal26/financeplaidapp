import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finsight/models/transaction.dart' as app_model;

// Import the new categorization service
// import 'package:finsight/services/merchant_categorization_service.dart';

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
  // final MerchantCategorizationService _categorizationService = MerchantCategorizationService();
  
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

  // Fetch transactions from Plaid with enhanced merchant categorization
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
      
      // Convert Plaid transactions to app's Transaction model with enhanced categorization
      final List<app_model.Transaction> processedTransactions = [];
      
      for (final trx in allTransactions) {
        try {
          final amount = trx['amount'] != null ? double.parse(trx['amount'].toString()) : 0.0;
          final merchantName = trx['merchant_name'] ?? trx['name'] ?? 'Unknown Transaction';
          final description = trx['name'] ?? 'Unknown Transaction';
          
          // Use enhanced categorization
          final category = await _enhancedCategorizeTransaction(
            merchantName, 
            description, 
            trx['category'],
            trx['personal_finance_category']
          );
          
          // Get merchant info for enhanced display
          final merchantInfo = await _getMerchantDisplayInfo(merchantName, description);
          
          final transaction = app_model.Transaction(
            id: trx['transaction_id'],
            date: DateTime.parse(trx['date']),
            description: merchantInfo['displayName'] ?? description,
            category: category,
            amount: amount.abs(),
            account: trx['account_owner'] ?? 'Unknown Account', 
            transactionType: amount > 0 ? 'Debit' : 'Credit',
            isPersonal: false,
            merchantName: merchantName,
            merchantLogoUrl: merchantInfo['logoUrl'],
            merchantWebsite: merchantInfo['website'],
            originalDescription: description,
            plaidCategory: trx['category']?.isNotEmpty == true ? trx['category'].join(', ') : null,
          );
          
          processedTransactions.add(transaction);
        } catch (e) {
          print('Error processing transaction: $e');
          continue;
        }
      }
      
      print('Successfully processed ${processedTransactions.length} transactions');
      return processedTransactions;
    } catch (e) {
      print('Exception in fetchTransactions: $e');
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  // Enhanced transaction categorization using comprehensive merchant database
  Future<String> _enhancedCategorizeTransaction(
    String merchantName, 
    String description, 
    List<dynamic>? plaidCategories,
    Map<String, dynamic>? personalFinanceCategory
  ) async {
    // Clean up merchant name and description
    final cleanMerchant = _cleanMerchantName(merchantName);
    final cleanDescription = _cleanMerchantName(description);
    
    // Try merchant database first (most accurate)
    final merchantCategory = _getMerchantCategory(cleanMerchant, cleanDescription);
    if (merchantCategory != null) {
      return merchantCategory;
    }

    // Try Plaid's personal finance category (newer, more accurate)
    if (personalFinanceCategory != null) {
      final pfcCategory = _mapPersonalFinanceCategory(personalFinanceCategory);
      if (pfcCategory != null) {
        return pfcCategory;
      }
    }

    // Try traditional Plaid categories
    if (plaidCategories != null && plaidCategories.isNotEmpty) {
      final plaidCategory = _mapPlaidCategories(plaidCategories);
      if (plaidCategory != null) {
        return plaidCategory;
      }
    }

    // Keyword-based classification as final fallback
    final keywordCategory = _classifyByAdvancedKeywords(cleanMerchant, cleanDescription);
    if (keywordCategory != null) {
      return keywordCategory;
    }

    return 'Miscellaneous';
  }

  String? _getMerchantCategory(String merchantName, String description) {
    final text = '$merchantName $description'.toLowerCase();
    
    // Comprehensive merchant patterns
    final merchantPatterns = {
      // Grocery Stores
      'Groceries': [
        'whole foods', 'trader joe', 'safeway', 'kroger', 'walmart supercenter',
        'target', 'costco', 'sams club', 'sam\'s club', 'publix', 'harris teeter',
        'food lion', 'giant', 'wegmans', 'aldi', 'fresh market', 'sprouts',
        'market basket', 'h-e-b', 'heb', 'meijer', 'albertsons', 'stop shop',
        'king soopers', 'fred meyer', 'ralphs', 'vons', 'pavilions', 'acme',
        'jewel osco', 'shaws', 'star market', 'tom thumb', 'randalls',
        'instacart', 'shipt', 'grocery', 'supermarket', 'market'
      ],
      
      // Dining Out
      'Dining Out': [
        'mcdonalds', 'mcdonald\'s', 'burger king', 'kfc', 'taco bell', 'subway',
        'chipotle', 'panera', 'chick-fil-a', 'chick fil a', 'in-n-out', 'five guys',
        'wendys', 'wendy\'s', 'arbys', 'arby\'s', 'popeyes', 'sonic', 'dairy queen',
        'white castle', 'jack in the box', 'starbucks', 'dunkin', 'dutch bros',
        'peets', 'caribou', 'pizza hut', 'dominos', 'domino\'s', 'papa johns',
        'papa john\'s', 'little caesars', 'papa murphy', 'olive garden', 'applebees',
        'applebee\'s', 'chilis', 'chili\'s', 'outback', 'red lobster', 'buffalo wild wings',
        'cracker barrel', 'texas roadhouse', 'ihop', 'dennys', 'denny\'s',
        'doordash', 'uber eats', 'grubhub', 'postmates', 'restaurant', 'cafe', 'diner'
      ],
      
      // Transportation
      'Transportation': [
        'shell', 'exxon', 'mobil', 'chevron', 'bp', 'sunoco', 'citgo', 'valero',
        'marathon', 'speedway', 'wawa', '7-eleven', 'circle k', 'caseys', 'casey\'s',
        'uber', 'lyft', 'delta', 'american airlines', 'united', 'southwest',
        'jetblue', 'spirit', 'frontier', 'alaska', 'hertz', 'enterprise', 'budget',
        'avis', 'national', 'thrifty', 'alamo', 'gas station', 'fuel', 'parking'
      ],
      
      // Shopping
      'Shopping': [
        'amazon', 'ebay', 'best buy', 'home depot', 'lowes', 'lowe\'s', 'macys',
        'macy\'s', 'nordstrom', 'kohls', 'kohl\'s', 'jcpenney', 'tj maxx', 'marshalls',
        'ross', 'bed bath beyond', 'bath body works', 'victoria secret', 'gap',
        'old navy', 'banana republic', 'h&m', 'zara', 'uniqlo', 'forever 21',
        'apple store', 'microsoft store', 'gamestop', 'barnes noble', 'costco',
        'shopping', 'retail', 'store', 'mall'
      ],
      
      // Healthcare
      'Healthcare': [
        'cvs', 'walgreens', 'rite aid', 'kaiser', 'blue cross', 'aetna', 'cigna',
        'humana', 'united health', 'anthem', 'molina', 'pharmacy', 'hospital',
        'clinic', 'medical', 'doctor', 'dentist', 'urgent care'
      ],
      
      // Utilities
      'Utilities': [
        'verizon', 'at&t', 'att', 'comcast', 'xfinity', 'spectrum', 't-mobile',
        'tmobile', 'sprint', 'cox', 'time warner', 'directv', 'dish', 'electric',
        'power', 'gas company', 'water', 'internet', 'cable', 'phone'
      ],
      
      // Subscriptions
      'Subscriptions': [
        'netflix', 'spotify', 'amazon prime', 'hulu', 'disney plus', 'disney+',
        'apple music', 'youtube premium', 'adobe', 'microsoft 365', 'office 365',
        'google one', 'dropbox', 'icloud', 'paramount', 'hbo max', 'peacock',
        'discovery+', 'subscription', 'membership'
      ],
      
      // Entertainment
      'Entertainment': [
        'planet fitness', 'la fitness', '24 hour fitness', 'anytime fitness',
        'equinox', 'soulcycle', 'orange theory', 'peloton', 'amc', 'regal',
        'cinemark', 'dave busters', 'dave & busters', 'gym', 'fitness', 'movie',
        'theater', 'cinema'
      ],
      
      // Insurance
      'Insurance': [
        'state farm', 'geico', 'progressive', 'allstate', 'farmers', 'liberty mutual',
        'usaa', 'nationwide', 'metlife', 'prudential', 'insurance'
      ],
      
      // Rent/Housing
      'Rent': [
        'apartment', 'property management', 'real estate', 'rent', 'rental',
        'lease', 'housing', 'mortgage'
      ]
    };

    for (final category in merchantPatterns.keys) {
      for (final pattern in merchantPatterns[category]!) {
        if (text.contains(pattern)) {
          return category;
        }
      }
    }

    return null;
  }

  String? _mapPersonalFinanceCategory(Map<String, dynamic> pfc) {
    final primary = pfc['primary']?.toString().toLowerCase() ?? '';
    final detailed = pfc['detailed']?.toString().toLowerCase() ?? '';
    
    if (primary.contains('food') || primary.contains('drink')) {
      if (detailed.contains('groceries')) return 'Groceries';
      if (detailed.contains('restaurant') || detailed.contains('fast_food')) return 'Dining Out';
    }
    
    if (primary.contains('transportation')) return 'Transportation';
    if (primary.contains('general_merchandise')) return 'Shopping';
    if (primary.contains('healthcare')) return 'Healthcare';
    if (primary.contains('entertainment')) return 'Entertainment';
    if (primary.contains('personal_care')) return 'Healthcare';
    if (primary.contains('government')) return 'Miscellaneous';
    if (primary.contains('travel')) return 'Transportation';
    if (primary.contains('rent')) return 'Rent';
    
    return null;
  }

  String? _mapPlaidCategories(List<dynamic> categories) {
    if (categories.isEmpty) return null;
    
    final primaryCategory = categories.first.toString().toLowerCase();
    final detailedCategory = categories.length > 1 ? categories.last.toString().toLowerCase() : '';
    
    if (primaryCategory.contains('food') && primaryCategory.contains('drink')) {
      if (detailedCategory.contains('restaurant') || detailedCategory.contains('fast food') || 
          detailedCategory.contains('cafe') || detailedCategory.contains('bar')) {
        return 'Dining Out';
      }
      if (detailedCategory.contains('grocery') || detailedCategory.contains('supermarket')) {
        return 'Groceries';
      }
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
    
    return null;
  }

  String? _classifyByAdvancedKeywords(String merchantName, String description) {
    final text = '$merchantName $description';
    
    final keywordPatterns = {
      'Subscriptions': ['recurring', 'monthly', 'annual', 'subscription', 'membership', 'premium', 'pro', 'plus'],
      'Utilities': ['utility', 'electric', 'power', 'energy', 'water', 'sewer', 'gas', 'internet', 'cable', 'phone'],
      'Healthcare': ['medical', 'health', 'hospital', 'clinic', 'pharmacy', 'doctor', 'dental'],
      'Transportation': ['parking', 'toll', 'gas', 'fuel', 'auto', 'car', 'vehicle'],
      'Entertainment': ['entertainment', 'recreation', 'sports', 'gym', 'fitness'],
      'Insurance': ['insurance', 'policy', 'coverage'],
      'Rent': ['rent', 'rental', 'lease', 'property'],
    };

    for (final category in keywordPatterns.keys) {
      for (final keyword in keywordPatterns[category]!) {
        if (text.toLowerCase().contains(keyword)) {
          return category;
        }
      }
    }

    return null;
  }

  Future<Map<String, String?>> _getMerchantDisplayInfo(String merchantName, String description) async {
    try {
      // For now, use simplified logic. In full implementation, would use MerchantCategorizationService
      final cleanName = _cleanMerchantName(merchantName);
      
      // Try to get logo from common sources
      String? logoUrl;
      String? website;
      
      // Map some common merchants to their logos
      final commonLogos = {
        'amazon': 'https://logo.clearbit.com/amazon.com',
        'apple': 'https://logo.clearbit.com/apple.com',
        'starbucks': 'https://logo.clearbit.com/starbucks.com',
        'mcdonalds': 'https://logo.clearbit.com/mcdonalds.com',
        'walmart': 'https://logo.clearbit.com/walmart.com',
        'target': 'https://logo.clearbit.com/target.com',
        'costco': 'https://logo.clearbit.com/costco.com',
        'uber': 'https://logo.clearbit.com/uber.com',
        'lyft': 'https://logo.clearbit.com/lyft.com',
        'netflix': 'https://logo.clearbit.com/netflix.com',
        'spotify': 'https://logo.clearbit.com/spotify.com',
        'google': 'https://logo.clearbit.com/google.com',
        'microsoft': 'https://logo.clearbit.com/microsoft.com',
      };
      
      for (final entry in commonLogos.entries) {
        if (cleanName.contains(entry.key)) {
          logoUrl = entry.value;
          website = entry.key + '.com';
          break;
        }
      }
      
      return {
        'displayName': _formatMerchantName(merchantName),
        'logoUrl': logoUrl,
        'website': website,
      };
    } catch (e) {
      print('Error getting merchant display info: $e');
      return {
        'displayName': merchantName,
        'logoUrl': null,
        'website': null,
      };
    }
  }

  String _cleanMerchantName(String name) {
    return name.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatMerchantName(String name) {
    // Clean up merchant names for better display
    return name
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '')
        .join(' ')
        .trim();
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