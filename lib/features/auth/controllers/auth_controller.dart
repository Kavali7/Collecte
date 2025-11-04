import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_state.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final firebaseAuth = ref.watch(firebaseAuthProvider);
    return AuthController(firebaseAuth);
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(FirebaseAuth auth)
    : _auth = auth,
      super(const AuthState.initial()) {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSubscription;

  Future<void> signInWithGoogle() async {
    // Google sign-in est desactive pour cette application.
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // La mise a jour de l'etat sera faite par authStateChanges().
    } on FirebaseAuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseError(error),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur inattendue: $error',
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _auth.signOut();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de se deconnecter: $error',
      );
    }
  }

  void _onAuthStateChanged(User? user) {
    final displayName = user?.displayName ??
        (user?.email?.isNotEmpty == true ? user!.email!.split('@').first : null);

    state = state.copyWith(
      isAuthenticated: user != null,
      userId: user?.uid,
      displayName: displayName,
      isLoading: false,
      errorMessage: null,
    );
  }

  String _mapFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'user-disabled':
        return 'Ce compte est desactive.';
      case 'user-not-found':
        return 'Aucun utilisateur trouve avec cet email.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Email ou mot de passe incorrect.';
      case 'too-many-requests':
        return 'Trop de tentatives. Reessaie plus tard.';
      default:
        return error.message ?? 'Erreur de connexion.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
