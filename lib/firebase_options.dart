// File: lib/firebase_options.dart
// This file contains the Firebase configuration options for your app.
// To get these values:
// 1. Go to Firebase Console
// 2. Click on Project Settings (gear icon)
// 3. Under "Your apps", find your Android app
// 4. The values are in the google-services.json file

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Replace these values with your actual Firebase configuration
  // You can find these values in your google-services.json file
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDLeVHjD1kIfvXJW4R0TNQ0lKPE7R3Tiqg', // From google-services.json > client > api_key > current_key
    appId: '1:969690894666:android:ce89c87e7e6de788f4b1b3', // From google-services.json > client > client_info > mobilesdk_app_id
    messagingSenderId: '969690894666', // From google-services.json > project_info > project_number
    projectId: 'emergency-73ada', // From google-services.json > project_info > project_id
    databaseURL: 'https://emergency-73ada-default-rtdb.firebaseio.com/', // From Firebase Console > Realtime Database
    storageBucket: 'emergency-73ada.firebasestorage.app', // From google-services.json > project_info > storage_bucket
  );

  // These configurations are not needed for Android, but keeping them for future use
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR-WEB-API-KEY',
    appId: 'YOUR-WEB-APP-ID',
    messagingSenderId: 'YOUR-SENDER-ID',
    projectId: 'YOUR-PROJECT-ID',
    authDomain: 'YOUR-AUTH-DOMAIN',
    databaseURL: 'YOUR-DATABASE-URL',
    storageBucket: 'YOUR-STORAGE-BUCKET',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR-IOS-API-KEY',
    appId: 'YOUR-IOS-APP-ID',
    messagingSenderId: 'YOUR-SENDER-ID',
    projectId: 'YOUR-PROJECT-ID',
    databaseURL: 'YOUR-DATABASE-URL',
    storageBucket: 'YOUR-STORAGE-BUCKET',
    iosClientId: 'YOUR-IOS-CLIENT-ID',
    iosBundleId: 'YOUR-IOS-BUNDLE-ID',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR-MACOS-API-KEY',
    appId: 'YOUR-MACOS-APP-ID',
    messagingSenderId: 'YOUR-SENDER-ID',
    projectId: 'YOUR-PROJECT-ID',
    databaseURL: 'YOUR-DATABASE-URL',
    storageBucket: 'YOUR-STORAGE-BUCKET',
    iosClientId: 'YOUR-MACOS-CLIENT-ID',
    iosBundleId: 'YOUR-MACOS-BUNDLE-ID',
  );
} 