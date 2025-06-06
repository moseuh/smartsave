// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        return windows;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBPJj4gkst0Sv8qFP0ZfvkCdtWpkD4E13Y',
    appId: '1:1019218679560:web:2066a133990646354e3ebd',
    messagingSenderId: '1019218679560',
    projectId: 'save-d84c2',
    authDomain: 'save-d84c2.firebaseapp.com',
    storageBucket: 'save-d84c2.firebasestorage.app',
    measurementId: 'G-M0B9SFW8XJ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDB5hs-T5WvHRU-VuDzQzkRAlRSIa6ygIM',
    appId: '1:1019218679560:android:be7c9c4f485026284e3ebd',
    messagingSenderId: '1019218679560',
    projectId: 'save-d84c2',
    storageBucket: 'save-d84c2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA7YpB5yCfZUgLKytU6o_WcocD6nxZSMA4',
    appId: '1:1019218679560:ios:ce7a8e83a56596434e3ebd',
    messagingSenderId: '1019218679560',
    projectId: 'save-d84c2',
    storageBucket: 'save-d84c2.firebasestorage.app',
    iosBundleId: 'com.example.saves',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA7YpB5yCfZUgLKytU6o_WcocD6nxZSMA4',
    appId: '1:1019218679560:ios:ce7a8e83a56596434e3ebd',
    messagingSenderId: '1019218679560',
    projectId: 'save-d84c2',
    storageBucket: 'save-d84c2.firebasestorage.app',
    iosBundleId: 'com.example.saves',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBPJj4gkst0Sv8qFP0ZfvkCdtWpkD4E13Y',
    appId: '1:1019218679560:web:f3b733372f0a73f14e3ebd',
    messagingSenderId: '1019218679560',
    projectId: 'save-d84c2',
    authDomain: 'save-d84c2.firebaseapp.com',
    storageBucket: 'save-d84c2.firebasestorage.app',
    measurementId: 'G-CVTSP1CC1V',
  );

}