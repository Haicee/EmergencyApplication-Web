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
    apiKey: 'AIzaSyBj2sRvc6yMkFo1BjdUENAAO1YmOYR61AE', // google-services.json > client > api_key > current_key
    appId: '1:984771585091:android:69f47d1fc2a527f40e20f6', // google-services.json > client > client_info > mobilesdk_app_id
    messagingSenderId: '984771585091', // google-services.json > project_info > project_number
    projectId: 'resmeapp-1', // google-services.json > project_info > project_id
    databaseURL: 'https://resmeapp-1-default-rtdb.firebaseio.com', // Firebase Console > Realtime Database
    storageBucket: 'resmeapp-1.firebasestorage.app', // google-services.json > project_info > storage_bucket
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