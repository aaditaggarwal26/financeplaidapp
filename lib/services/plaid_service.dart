import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaidService {
  final String baseUrl = 'http://localhost:3003/api'; 

  Future<String?> createLinkToken() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/create_link_token'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['link_token'];
      } else {
        print('Error creating link token: ${response.body}');
      }
    } catch (e) {
      print('Exception creating link token: $e');
    }
    return null;
  }

  Future<String?> exchangePublicToken(String publicToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/exchange_public_token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'public_token': publicToken}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      } else {
        print('Error exchanging public token: ${response.body}');
      }
    } catch (e) {
      print('Exception exchanging public token: $e');
    }
    return null;
  }

  Future<List<dynamic>?> getTransactions(String accessToken, String startDate, String endDate) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'access_token': accessToken,
          'start_date': startDate,
          'end_date': endDate,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print('Error fetching transactions: ${response.body}');
      }
    } catch (e) {
      print('Exception fetching transactions: $e');
    }
    return null;
  }
}
