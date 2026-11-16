import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Replace with your actual Firebase project credentials from Firebase Console.
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
    apiKey: 'AIzaSyDemoDummyApiKey_ReplaceWithActual',
    appId: '1:100000000000:web:abcdef123456',
    messagingSenderId: '100000000000',
    projectId: 'examprep-upsc-tnpsc',
    authDomain: 'examprep-upsc-tnpsc.firebaseapp.com',
    storageBucket: 'examprep-upsc-tnpsc.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDemoDummyApiKey_ReplaceWithActual',
    appId: '1:100000000000:android:abcdef123456',
    messagingSenderId: '100000000000',
    projectId: 'examprep-upsc-tnpsc',
    storageBucket: 'examprep-upsc-tnpsc.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDemoDummyApiKey_ReplaceWithActual',
    appId: '1:100000000000:ios:abcdef123456',
    messagingSenderId: '100000000000',
    projectId: 'examprep-upsc-tnpsc',
    storageBucket: 'examprep-upsc-tnpsc.appspot.com',
    iosBundleId: 'com.examprep.app',
  );
}

