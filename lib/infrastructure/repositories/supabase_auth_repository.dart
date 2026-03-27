import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final _client = supabase.Supabase.instance.client;

  @override
  Stream<UserModel?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) {
        final session = data.session;
        if (session == null) return null;
        final user = session.user;
        return UserModel(
          id: user.id,
          email: user.email ?? '',
          fullName: user.userMetadata?['full_name'],
          avatarUrl: user.userMetadata?['avatar_url'],
          membershipTier: user.userMetadata?['membership_tier'] ?? 'GUEST',
          createdAt: DateTime.parse(user.createdAt),
        );
      });

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      fullName: user.userMetadata?['full_name'],
      avatarUrl: user.userMetadata?['avatar_url'],
      membershipTier: user.userMetadata?['membership_tier'] ?? 'GUEST',
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'membership_tier': 'GUEST'},
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    // For Web, we use Supabase's native OAuth flow to avoid google_sign_in package limitations
    if (kIsWeb) {
      await _client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
      return;
    }

    // For Mobile (Android/iOS), we use the google_sign_in package to get an ID token
    // IMPORTANT: This must be the WEB Client ID from Google Cloud Console
    const webClientId =
        '479159267751-2eqs8j7duq4bma30pmg6vdd2g4mk2m58.apps.googleusercontent.com';

    // google_sign_in 7.0+ uses initialize() for configuration
    await GoogleSignIn.instance.initialize(serverClientId: webClientId);

    final googleUser = await GoogleSignIn.instance.authenticate();

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    // Retrieve accessToken via authorizationClient in version 7.x
    final clientAuth = await googleUser.authorizationClient.authorizeScopes([]);
    final accessToken = clientAuth.accessToken;

    if (idToken == null) {
      throw 'No ID Token found.';
    }

    await _client.auth.signInWithIdToken(
      provider: supabase.OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
