import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper over Firebase Authentication.
///
/// The original app used the Firebase *Admin* SDK with a service-account key
/// shipped inside the app, created users with an already-hashed password and
/// compared SHA-256 hashes stored in the database. Anyone with the app could
/// extract that key and get full admin access to the project. Here the client
/// only uses the public client SDK; Firebase handles password storage.
class AuthService {
  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User> signUp({required String email, required String password}) async {
    final cred = await _guard(
      () => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password),
    );
    return cred.user!;
  }

  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() => _guard(() => _auth.currentUser!.delete());

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  static String _messageFor(String code) => switch (code) {
        'email-already-in-use' => 'This email is already registered.',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' => 'Password is too weak.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Invalid email or password.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'network-request-failed' => 'No internet connection.',
        'requires-recent-login' => 'Please log out and log in again, then retry.',
        _ => 'Something went wrong ($code).',
      };
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
