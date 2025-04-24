// All the imports for our app
import 'package:finsight/screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Ensures Firebase and environment variables are initialized before launching.
Future<void> main() async {
  // Ensures that widget binding is set up before other async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for the app
  await Firebase.initializeApp();

  // Attempt to load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
    print("PLAID_CLIENT_ID: ${dotenv.env['PLAID_CLIENT_ID']}");
  } catch (e) {
    // Log any error encountered while loading the .env file
    print("Error loading .env file: $e");
  }

  // Launch the application
  runApp(MyApp());
}

/// Root widget of the application
class MyApp extends StatelessWidget {
  // Key used to manage navigation across the app
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Finsight',
      home: LoginScreen(), // First screen shown to the user, as soon as user opens the app. Prompts them to log-in
    );
  }
}
