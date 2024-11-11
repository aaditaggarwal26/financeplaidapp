import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlaidIntegrationService {
  static const String _plaidClientId = '67214ae1946242001a565c22';
  static const String _plaidSecret = 'ad0125a2ad3c2a8844fa781568053e';
  static const String _plaidEnv =
      'sandbox'; // 'sandbox', 'development', or 'production'

  static const String _plaidBaseUrl = 'https://sandbox.plaid.com';

  // Step 1: Create Link Token
  static Future<String?> createLinkToken() async {
    final url = Uri.parse('$_plaidBaseUrl/link/token/create');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = json.encode({
      'client_id': _plaidClientId,
      'secret': _plaidSecret,
      'user': {
        'client_user_id': 'aaditaggarwal2008',
      },
      'client_name': 'transactions',
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
      }
    } catch (error) {
      print('Error creating link token: $error');
    }
    return null;
  }

  // Step 2: Exchange Public Token for Access Token
  static Future<String?> exchangePublicToken(String publicToken) async {
    final url = Uri.parse('$_plaidBaseUrl/item/public_token/exchange');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = json.encode({
      'client_id': _plaidClientId,
      'secret': _plaidSecret,
      'public_token': publicToken,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      } else {
        print('Failed to exchange public token: ${response.statusCode}');
      }
    } catch (error) {
      print('Error exchanging public token: $error');
    }
    return null;
  }

  // Step 3: Fetch Transactions
  static Future<void> fetchTransactions(String accessToken) async {
    final url = Uri.parse('$_plaidBaseUrl/transactions/get');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = json.encode({
      'client_id': _plaidClientId,
      'secret': _plaidSecret,
      'access_token': accessToken,
      'start_date': '2022-01-01',
      'end_date': '2024-12-31',
      'options': {
        'count': 100,
        'offset': 0,
      },
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Transactions: ${data['transactions']}');
      } else {
        print('Failed to fetch transactions: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching transactions: $error');
    }
  }
}
/*
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final linkToken = await PlaidIntegrationService.createLinkToken();
  if (linkToken != null) {
    print('Link Token: $linkToken');

    // Simulate user linking their account to obtain a public token
    // This part should involve the Plaid Link integration, which is done via the frontend.
    // Assuming you have successfully obtained a public token, let's exchange it.

    final publicToken = linkToken; // Replace with your real public token obtained via Plaid Link
    final accessToken = await PlaidIntegrationService.exchangePublicToken(publicToken);
    if (accessToken != null) {
      print('Access Token: $accessToken');
      await PlaidIntegrationService.fetchTransactions(accessToken);
    }
  }
}
*/