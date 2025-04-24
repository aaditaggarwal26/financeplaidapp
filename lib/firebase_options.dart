// All the imports for our app
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

// Configuration class that returns platform-specific FirebaseOptions.
// This is required to initialize Firebase correctly on each target (web, Android, iOS).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // If the app is running on the web, use the web options
    if (kIsWeb) {
      return web;
    }

    // Return platform-specific Firebase configuration
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS is not configured for Firebase.');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows is not configured for Firebase.');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not configured for Firebase.');
      default:
        throw UnsupportedError('This platform is not supported.');
    }
  }

  // Web-specific Firebase configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDqt6zVKSFKiSqO2RT7JESQmDc0nKGwqyI',
    appId: '1:946317225084:web:a4ca32040bfe6cc6532df9',
    messagingSenderId: '946317225084',
    projectId: 'finsight-a5027',
    authDomain: 'finsight-a5027.firebaseapp.com',
    storageBucket: 'finsight-a5027.firebasestorage.app',
  );

  // Android-specific Firebase configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDSZDGnASb2dk2M4ELcK4oYkBIb6N_gmGo',
    appId: '1:946317225084:android:c280be2f0cc26ea0532df9',
    messagingSenderId: '946317225084',
    projectId: 'finsight-a5027',
    storageBucket: 'finsight-a5027.firebasestorage.app',
  );

  // iOS-specific Firebase configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAN21HLuyTbioRl-LVwiBPnIgkPLgW9DQI',
    appId: '1:946317225084:ios:16e009db05c4bb13532df9',
    messagingSenderId: '946317225084',
    projectId: 'finsight-a5027',
    storageBucket: 'finsight-a5027.firebasestorage.app',
    iosClientId: '946317225084-t8flbvdpepob3sc998vtg8dg3ehab8io.apps.googleusercontent.com',
    iosBundleId: 'com.finsight.finsight',
  );
}
