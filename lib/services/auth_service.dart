import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Firebase Auth for the two auth flows the app needs:
/// - anonymous sign-in for regular guests (so Firestore/Storage security
///   rules can require `request.auth != null` without guests seeing a
///   login screen)
/// - email/password sign-in for the couple's admin area
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Ensures the current visitor has an (anonymous) Firebase auth session.
  /// Call this once on app startup.
  Future<void> ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  bool get isAdmin => _auth.currentUser != null && !_auth.currentUser!.isAnonymous;

  Future<UserCredential> signInAdmin({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOutAdmin() async {
    await _auth.signOut();
    // Restore an anonymous session so guest features keep working.
    await ensureSignedIn();
  }
}
