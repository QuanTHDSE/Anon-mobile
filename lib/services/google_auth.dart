import 'package:google_sign_in/google_sign_in.dart';

import '../core/config.dart';

/// Thrown when the user cancels the Google account chooser.
class GoogleSignInCancelled implements Exception {}

/// Native Google Sign-In helper. Returns the ID token that the backend
/// (`POST /api/v1/auth/google`) verifies against [googleServerClientId].
class GoogleAuth {
  GoogleAuth._();

  static final GoogleAuth instance = GoogleAuth._();

  final GoogleSignIn _google = GoogleSignIn(
    // Matches the web `VITE_GOOGLE_CLIENT_ID` so the ID token's audience is
    // accepted by the backend.
    serverClientId: googleServerClientId,
    scopes: const ['email', 'profile'],
  );

  /// Opens the Google account chooser and returns a fresh ID token.
  /// Throws [GoogleSignInCancelled] if the user backs out.
  Future<String> signInIdToken() async {
    // Sign out first so the chooser always appears (avoids a stuck session).
    await _google.signOut();
    final account = await _google.signIn();
    if (account == null) throw GoogleSignInCancelled();
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Không lấy được Google ID token. Vui lòng thử lại.');
    }
    return idToken;
  }

  Future<void> signOut() => _google.signOut();
}
