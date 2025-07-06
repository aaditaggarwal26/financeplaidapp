// All the imports for our app
import 'package:finsight/screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:finsight/firebase_options.dart';

// Ensures Firebase and environment variables are initialized before launching.
Future<void> main() async {
  // Ensures that widget binding is set up before other async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for the app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Attempt to load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
    print("Successfully loaded .env file");
    print("PLAID_CLIENT_ID: ${dotenv.env['PLAID_CLIENT_ID']}");
    print("PLAID_ENV: ${dotenv.env['PLAID_ENV']}");
    print("PLAID_PRODUCTS: ${dotenv.env['PLAID_PRODUCTS']}");
  } catch (e) {
    // Log any error encountered while loading the .env file
    print("Error loading .env file: $e");
    print("Will use default Plaid configuration");
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
      debugShowCheckedModeBanner: false,
      title: 'Finsight',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LoginScreen(), // First screen shown to the user, as soon as user opens the app. Prompts them to log-in
    );
  }
}