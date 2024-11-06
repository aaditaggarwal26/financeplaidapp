import 'package:fbla_coding_programming_app/screens/login_screen.dart';
import 'package:fbla_coding_programming_app/screens/spending_screen.dart';
import 'package:fbla_coding_programming_app/tabs.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  try {
    // Load the .env file from the root of the project
    await dotenv.load(fileName: ".env");
    print("PLAID_CLIENT_ID: \${dotenv.env['PLAID_CLIENT_ID']}");
  } catch (e) {
    // Handle error if .env file cannot be loaded
    print("Error loading .env file: $e");
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FBLA Finance App',
      theme: ThemeData(primarySwatch: Colors.purple),
      home: LoginScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _accessToken;
  Map<String, dynamic>? _transactionsJson;
  String? _csvPath;

  // Step 1: Get the public token and exchange it for an access token
  Future<void> getAccessToken() async {
    final clientId = dotenv.env['PLAID_CLIENT_ID'];
    final secret = dotenv.env['PLAID_SECRET'];

    if (clientId == null || secret == null) {
      print("Error: PLAID_CLIENT_ID or PLAID_SECRET not found in .env");
      return;
    }

    // Step 1a: Create a sandbox public token
    final publicTokenResponse = await http.post(
      Uri.parse('https://sandbox.plaid.com/sandbox/public_token/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_id': clientId,
        'secret': secret,
        'institution_id': 'ins_109508', // Sandbox institution ID
        'initial_products': ['transactions']
      }),
    );

    if (publicTokenResponse.statusCode == 200) {
      final publicToken = jsonDecode(publicTokenResponse.body)['public_token'];

      // Step 1b: Exchange public token for access token
      final accessTokenResponse = await http.post(
        Uri.parse('https://sandbox.plaid.com/item/public_token/exchange'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'client_id': clientId,
          'secret': secret,
          'public_token': publicToken,
        }),
      );

      if (accessTokenResponse.statusCode == 200) {
        setState(() {
          _accessToken = jsonDecode(accessTokenResponse.body)['access_token'];
        });
        print("Access token obtained: $_accessToken");
      } else {
        print("Failed to exchange public_token: \${accessTokenResponse.body}");
      }
    } else {
      print("Failed to create public_token: \${publicTokenResponse.body}");
    }
  }

  // Step 2: Fetch transactions data using access token and save as CSV
  Future<void> fetchTransactionsAndSaveAsCSV() async {
    final clientId = dotenv.env['PLAID_CLIENT_ID'];
    final secret = dotenv.env['PLAID_SECRET'];

    if (_accessToken == null) {
      print("Access token not found, calling getAccessToken()");
      await getAccessToken();
      if (_accessToken == null) {
        print("Failed to obtain access token");
        return;
      }
    }

    // Fetch transactions using the access token
    final response = await http.post(
      Uri.parse('https://sandbox.plaid.com/transactions/get'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_id': clientId,
        'secret': secret,
        'access_token': _accessToken,
        'start_date': '2024-01-01',
        'end_date': '2024-12-31',
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      print("Transactions JSON:\n\${jsonEncode(jsonResponse)}");

      setState(() {
        _transactionsJson = jsonResponse; // Store the JSON data for display
      });

      // Process transactions and save as CSV
      final transactions = jsonResponse['transactions'];
      List<List<dynamic>> csvData = [
        ["Transaction ID", "Date", "Amount", "Name", "Category"]
      ];

      for (var transaction in transactions) {
        csvData.add([
          transaction["transaction_id"],
          transaction["date"],
          transaction["amount"],
          transaction["name"],
          (transaction["category"] as List<dynamic>).join(", ")
        ]);
      }

      String csvString = const ListToCsvConverter().convert(csvData);

      // Save the CSV file locally
      final directory = await getApplicationDocumentsDirectory();
      final path = '\${directory.path}/transactions.csv';
      final file = File(path);
      await file.writeAsString(csvString);

      setState(() {
        _csvPath = path; // Store the path of the CSV
      });

      // Notify user of success
      print("CSV file saved at: $path");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("CSV file saved at: $path")),
      );
    } else {
      print("Failed to fetch transactions: \${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.pink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Text('Welcome Back', style: TextStyle(color: Colors.white)),
            Spacer(),
            IconButton(
              icon: Icon(Icons.settings, color: Colors.white),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.purple.shade100,
                child: ListTile(
                  title: Text('Current spend this month',
                      style: TextStyle(color: Colors.black)),
                  subtitle: Text('Up X% above last month',
                      style: TextStyle(color: Colors.red)),
                  trailing: Icon(Icons.trending_up, color: Colors.red),
                ),
              ),
              SizedBox(height: 16.0),
              Card(
                child: ListTile(
                  leading: Icon(Icons.attach_money, color: Colors.green),
                  title: Text('Payday in 5 days'),
                ),
              ),
              SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Accounts',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {},
                    child: Text('Add Account',
                        style: TextStyle(color: Colors.purple)),
                  ),
                ],
              ),
              _buildAccountSection('Checking', Icons.account_balance_wallet),
              _buildAccountSection('Card Balance', Icons.credit_card),
              _buildAccountSection('Net Cash', Icons.monetization_on),
              _buildAccountSection('Savings', Icons.savings),
              _buildAccountSection('Investments', Icons.trending_up),
              SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: fetchTransactionsAndSaveAsCSV,
                  child: Text("Fetch and Save Transactions as CSV"),
                ),
              ),
              if (_transactionsJson != null) ...[
                SizedBox(height: 16),
                Text(
                  "Transactions JSON:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  jsonEncode(_transactionsJson),
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
              ],
              if (_csvPath != null) ...[
                SizedBox(height: 16),
                Text(
                  "CSV File Path: $_csvPath",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => OpenFile.open(_csvPath),
                  child: Text("Open CSV File"),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.schedule), label: 'Recurring'),
          BottomNavigationBarItem(icon: Icon(Icons.money), label: 'Spending'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list), label: 'Transactions'),
        ],
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Widget _buildAccountSection(String title, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.purple),
        title: Text(title),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'screens/dashboard_screen.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'FinSight',
//       theme: ThemeData(
//         brightness: Brightness.light,
//         scaffoldBackgroundColor: Colors.white,
//         primaryColor: const Color(0xFF2B3A55),
//         colorScheme: ColorScheme.light(
//           primary: const Color(0xFF2B3A55),
//           secondary: const Color(0xFFE5BA73),
//           tertiary: const Color(0xFFE5BA73),
//         ),
//         cardTheme: CardTheme(
//           color: Colors.white,
//           elevation: 2,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//         ),
//         textTheme: const TextTheme(
//           bodyLarge: TextStyle(color: Colors.black87),
//           bodyMedium: TextStyle(color: Colors.black87),
//           titleLarge: TextStyle(color: Colors.black87),
//           titleMedium: TextStyle(color: Colors.black87),
//           labelMedium: TextStyle(color: Colors.grey),
//         ),
//         iconTheme: const IconThemeData(
//           color: Color(0xFF2B3A55),
//         ),
//         appBarTheme: const AppBarTheme(
//           color: Colors.transparent,
//           elevation: 0,
//           iconTheme: IconThemeData(color: Colors.white),
//           titleTextStyle: TextStyle(
//             color: Colors.white,
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//       home: const DashboardScreen(),
//     );
//   }
// }
