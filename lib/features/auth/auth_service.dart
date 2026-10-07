import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates an account, saves [name] as displayName, then signs out.
  ///
  /// Returns `true` on success. Does **not** leave an active session — the
  /// user must log in explicitly afterwards.
  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = result.user;
      if (user == null) return false;

      await user.updateDisplayName(name.trim());
      await user.reload();

      // Firebase signs in on create — clear session so AuthGate stays on Login.
      await _auth.signOut();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('REGISTER ERROR: ${e.message}');
      // Ensure we never leave a half-created session if something failed mid-way.
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
      return false;
    }
  }

  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Ensure displayName / profile fields are fresh before UI reads them.
      await result.user?.reload();
      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      debugPrint('LOGIN ERROR: ${e.message}');
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Profile updates (e.g. displayName) — preferred over [authStateChanges].
  Stream<User?> userChanges() => _auth.userChanges();

  /// Reloads Firebase user and returns a non-empty display name when available.
  Future<String?> resolveDisplayName() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      await user.reload();
    } catch (e) {
      debugPrint('USER RELOAD ERROR: $e');
    }

    final refreshed = _auth.currentUser;
    final name = refreshed?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }
}
