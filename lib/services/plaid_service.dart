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
  
  // Step 1: Create Link Token
  Future<String?> createLinkToken() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo-user';
    
    final url = Uri.parse('$_plaidBaseUrl/link/token/create');
    final headers = {'Content-Type': 'application/json'};
    
    final body = json.encode({
      'client_id': _plaidClientId,
      'secret': _plaidSecret,
      'user': {
        'client_user_id': userId,
      },
      'client_name': 'FinSight',
      'products': ['transactions'],
      'country_codes': ['US'],
      'language': 'en',
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
        
        // Save access token locally (instead of Firestore)
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

  // Save access token locally using SharedPreferences
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
    // Default to last 30 days if dates not provided
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final end = endDate ?? now;
    
    // Format dates as YYYY-MM-DD
    final formattedStartDate = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final formattedEndDate = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    
    // Get access token
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      if (context.mounted) {
        _showErrorDialog(
          context, 
          'Bank Connection Required', 
          'Please connect your bank account first to fetch transactions.'
        );
      }
      return [];
    }
    
    // Show loading indicator
    if (context.mounted) {
      _showLoadingDialog(context, 'Fetching transactions...');
    }
    
    try {
      final url = Uri.parse('$_plaidBaseUrl/transactions/get');
      final headers = {'Content-Type': 'application/json'};
      
      final body = json.encode({
        'client_id': _plaidClientId,
        'secret': _plaidSecret,
        'access_token': accessToken,
        'start_date': formattedStartDate,
        'end_date': formattedEndDate,
        'options': {
          'count': 100,
          'offset': 0,
        },
      });

      final response = await http.post(url, headers: headers, body: body);
      
      // Close loading dialog
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> plaidTransactions = data['transactions'] ?? [];
        
        // Convert Plaid transactions to app's Transaction model
        final transactions = plaidTransactions.map((trx) {
          // Determine transaction type based on amount
          final amount = trx['amount'] != null ? double.parse(trx['amount'].toString()) : 0.0;
          final isPositive = amount <= 0; // Plaid uses negative for inflow (credit)
          
          return app_model.Transaction(
            id: trx['transaction_id'],
            date: DateTime.parse(trx['date']),
            description: trx['name'] ?? 'Unknown',
            category: trx['category'] != null && (trx['category'] as List).isNotEmpty 
                ? (trx['category'] as List).last.toString() 
                : 'Uncategorized',
            amount: amount.abs(), // Store as positive
            account: trx['account_name'] ?? 'Unknown Account',
            transactionType: isPositive ? 'income' : 'expense',
            isPersonal: true,
          );
        }).toList();
        
        return transactions;
      } else {
        print('Failed to fetch transactions: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        if (context.mounted) {
          _showErrorDialog(
            context, 
            'Error Fetching Transactions', 
            'Failed to retrieve transactions. Please try again later.'
          );
        }
        return [];
      }
    } catch (e) {
      print('Exception in fetchTransactions: $e');
      
      // Close loading dialog if still showing
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (context.mounted) {
        _showErrorDialog(
          context, 
          'Error Fetching Transactions', 
          'An unexpected error occurred. Please try again later.'
        );
      }
      return [];
    }
  }

  // Get access token (from cache or storage)
  Future<String?> _getAccessToken() async {
    // Check if we already have it cached
    if (_accessToken != null) {
      return _accessToken;
    }
    
    try {
      // Try to get from SharedPreferences
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
      if (context.mounted) {
        _showErrorDialog(
          context, 
          'Bank Connection Required', 
          'Please connect your bank account first to fetch account info.'
        );
      }
      return [];
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
        
        return accounts.map<Map<String, dynamic>>((account) => {
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
          'institution': data['item']['institution_id'],
        }).toList();
      } else {
        print('Failed to fetch accounts: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        if (context.mounted) {
          _showErrorDialog(
            context, 
            'Error Fetching Accounts', 
            'Failed to retrieve account information. Please try again later.'
          );
        }
        return [];
      }
    } catch (e) {
      print('Exception in getAccounts: $e');
      
      if (context.mounted) {
        _showErrorDialog(
          context, 
          'Error Fetching Accounts', 
          'An unexpected error occurred. Please try again later.'
        );
      }
      return [];
    }
  }

  // Disconnect a Plaid institution
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
        
        // Clear cached token
        _accessToken = null;
        
        return true;
      } else {
        print('Failed to disconnect institution: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        if (context.mounted) {
          _showErrorDialog(
            context, 
            'Error Disconnecting Account', 
            'Failed to disconnect bank account. Please try again later.'
          );
        }
        return false;
      }
    } catch (e) {
      print('Exception in disconnectInstitution: $e');
      
      if (context.mounted) {
        _showErrorDialog(
          context, 
          'Error Disconnecting Account', 
          'An unexpected error occurred. Please try again later.'
        );
      }
      return false;
    }
  }

  // Check if a user has connected to Plaid
  Future<bool> hasPlaidConnection() async {
    final accessToken = await _getAccessToken();
    return accessToken != null;
  }

  // Helper Methods
  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5BA73)),
              ),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFF2B3A55)),
              ),
            ),
          ],
        );
      },
    );
  }
}