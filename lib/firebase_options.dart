import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBHjiZf2LK1hYMjK0axauthDomain', 
    appId: '1:82476120378:web:40c5d1d6402432',
    messagingSenderId: '82476120378',
    projectId: 'livingbooks-universe',
    authDomain: 'livingbooks-universe.firebaseapp.com',
    storageBucket: 'livingbooks-universe.appspot.com',
    measurementId: 'G-PNS3PDF5YX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBHjiZf2LK1hYMjK0axauthDomain',
    appId: '1:82476120378:web:40c5d1d6402432', 
    messagingSenderId: '82476120378',
    projectId: 'livingbooks-universe',
    storageBucket: 'livingbooks-universe.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBHjiZf2LK1hYMjK0axauthDomain',
    appId: '1:82476120378:web:40c5d1d6402432',
    messagingSenderId: '82476120378',
    projectId: 'livingbooks-universe',
    storageBucket: 'livingbooks-universe.appspot.com',
  );
}
