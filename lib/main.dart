// All the imports for our app
import 'package:finsight/screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:finsight/firebase_options.dart';

// Ensures Firebase and environment variables are initialized before launching.
Future<void> main() async {
  print("=== 1. MAIN FUNCTION STARTED ===");
  
  // Ensures that widget binding is set up before other async operations
  WidgetsFlutterBinding.ensureInitialized();
  print("=== 2. WIDGET BINDING COMPLETE ===");

  // Initialize Firebase for the app
  try {
    print("=== 3. STARTING FIREBASE INIT ===");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("=== 4. FIREBASE INITIALIZED SUCCESSFULLY ===");
  } catch (e) {
    print("=== FIREBASE ERROR: $e ===");
    print("=== FIREBASE STACK TRACE: ${StackTrace.current} ===");
  }

  // Attempt to load environment variables from .env file
  try {
    print("=== 5. LOADING ENV FILE ===");
    await dotenv.load(fileName: ".env");
    print("=== 6. ENV FILE LOADED SUCCESSFULLY ===");
    print("PLAID_CLIENT_ID: ${dotenv.env['PLAID_CLIENT_ID']}");
    print("PLAID_ENV: ${dotenv.env['PLAID_ENV']}");
    print("PLAID_PRODUCTS: ${dotenv.env['PLAID_PRODUCTS']}");
  } catch (e) {
    // Log any error encountered while loading the .env file
    print("=== ENV ERROR: $e ===");
    print("Will use default Plaid configuration");
  }

  print("=== 7. ABOUT TO LAUNCH APP ===");
  // Launch the application
  runApp(MyApp());
  print("=== 8. APP LAUNCHED ===");
}

/// Root widget of the application
class MyApp extends StatelessWidget {
  // Key used to manage navigation across the app
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  MyApp() {
    print("=== 9. MyApp CONSTRUCTOR CALLED ===");
  }

  @override
  Widget build(BuildContext context) {
    print("=== 10. MyApp BUILD METHOD CALLED ===");
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Finsight',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Builder(
        builder: (context) {
          print("=== 11. ABOUT TO SHOW LOGIN SCREEN ===");
          return LoginScreen();
        },
      ),
    );
  }
}