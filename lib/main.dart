import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

Future<void> main() async {
  await dotenv.load();  // Load the .env file
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FBLA Finance App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WebViewController _controller;

  String getPlaidLinkInitializationUrl() {
    final clientId = dotenv.env['PLAID_CLIENT_ID']!;
    final secret = dotenv.env['PLAID_SECRET']!;
    final environment = dotenv.env['PLAID_ENV']!;
    return "https://sandbox.plaid.com/link/?client_id=$clientId&secret=$secret";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Link Bank Account")),
      body: WebView(
        initialUrl: getPlaidLinkInitializationUrl(),
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (WebViewController webViewController) {
          _controller = webViewController;
        },
        navigationDelegate: (NavigationRequest request) {
          if (request.url.contains("https://myapp.com/auth/callback")) {
            // Simulate fetching data from Plaid and save it as CSV
            fetchDataAndSaveAsCSV();

            // Prevent the WebView from navigating to the redirect URL
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );
  }

  Future<void> fetchDataAndSaveAsCSV() async {
    // Mock data to simulate fetched transaction data from Plaid
    List<List<dynamic>> data = [
      ["Account ID", "Amount", "Date", "Category"],
      ["acc_1234", 150.0, "2023-10-01", "Groceries"],
      ["acc_5678", 75.5, "2023-10-02", "Dining"],
      ["acc_91011", 200.75, "2023-10-03", "Shopping"],
    ];

    // Convert data to CSV format
    String csvData = const ListToCsvConverter().convert(data);

    // Get the app's document directory
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/transaction_data.csv';

    // Write the CSV data to a file
    final file = File(path);
    await file.writeAsString(csvData);

    // Notify the user where the file is saved
    print("CSV file saved at: $path");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("CSV file saved at: $path")),
    );
  }
}
