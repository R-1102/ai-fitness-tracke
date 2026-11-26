// PLACEHOLDER — this file is replaced when you run:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// It is listed in .gitignore so your own project config never ends up on
// GitHub. See README.md → "Firebase setup".

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured yet. Run `flutterfire configure` '
        '(see README.md → Firebase setup).',
      );
}
