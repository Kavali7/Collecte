import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions n\'est pas configure pour la plateforme web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions n\'est pas configure pour cette plateforme.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB5iI1h-mg7200qyT1xx5z3AOx8QihiAGs',
    appId: '1:1047550427679:android:da1c072ecf7cc2b12ecb2a',
    messagingSenderId: '1047550427679',
    projectId: 'collecte-9b6e1',
    storageBucket: 'collecte-9b6e1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBRR8E5EiXVKFXWl5PCmihVgHPpQzjv3dI',
    appId: '1:1047550427679:ios:406eb5a7b61c7ab82ecb2a',
    messagingSenderId: '1047550427679',
    projectId: 'collecte-9b6e1',
    storageBucket: 'collecte-9b6e1.firebasestorage.app',
    iosBundleId: 'com.example.collecteRevendeurs',
  );
}
