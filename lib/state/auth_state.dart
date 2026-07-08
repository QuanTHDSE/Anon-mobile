import 'package:flutter/foundation.dart';

import 'dart:math';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/google_auth.dart';
import '../services/subscription_service.dart';
import '../services/user_service.dart';

/// App-wide auth/session state — port of the web AuthContext.
class AuthState extends ChangeNotifier {
  AppUser? user;
  UserProfile? profile;
  bool isPremium = false;

  bool get isLoggedIn => user != null;

  String? get userAvatarUrl => profile?.avatarUrl;

  /// Restore session from storage and refresh profile/premium.
  Future<void> restore() async {
    user = AuthService.instance.getCurrentUser();
    notifyListeners();
    if (user != null) await refreshProfile();
  }

  Future<void> login(String email, String password) async {
    user = await AuthService.instance.login(email, password);
    notifyListeners();
    await refreshProfile();
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String anonAlias,
  }) async {
    final res = await AuthService.instance.register(
      username: username,
      email: email,
      password: password,
      anonAlias: anonAlias,
    );
    user = AuthService.instance.getCurrentUser();
    notifyListeners();
    if (user != null) await refreshProfile();
    return res;
  }

  /// Native Google Sign-In → exchange the ID token for an app session.
  /// The backend generates the account on first login; we pass a random anon
  /// alias like the web does (`ghost_xxxx`).
  Future<void> loginWithGoogle() async {
    final idToken = await GoogleAuth.instance.signInIdToken();
    final suffix = Random().nextInt(1 << 20).toRadixString(36);
    user = await AuthService.instance.loginWithGoogle(idToken, 'ghost_$suffix');
    notifyListeners();
    await refreshProfile();
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    await GoogleAuth.instance.signOut();
    user = null;
    profile = null;
    isPremium = false;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      profile = await UserService.instance.getMe();
    } catch (_) {
      // Keep the session on transient errors; don't force re-login.
    }
    final id = user?.id ?? profile?.id ?? '';
    if (id.isNotEmpty) {
      var premium = profile?.isPremium == true;
      if (!premium) {
        premium =
            await SubscriptionService.instance.fetchPremiumStatus(id);
      }
      isPremium = premium;
    }
    notifyListeners();
  }
}
