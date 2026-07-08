/// Global configuration — same production API the web app (EXE101) uses.
const String apiBaseUrl = 'https://api.anonwork.site';

/// R2/CDN host serving uploaded media (avatars, post images, anon images).
const String cdnBaseUrl = 'https://cdn.anonwork.site';

/// Brand color used across the web app.
const int brandColorValue = 0xFFF15B29;

/// Google OAuth "web" client ID — the same one the web app (EXE101) uses as
/// `VITE_GOOGLE_CLIENT_ID`. On mobile this is passed as `serverClientId` so the
/// returned ID token's audience matches what the backend verifies.
const String googleServerClientId =
    '268572852860-fqqqs3bssn6pnq6lf9bqvcae6idglvu0.apps.googleusercontent.com';

/// Turn a relative R2 key into an absolute URL; leave absolute URLs as-is.
/// Mirrors `toAbsoluteMediaUrl` in the web app (src/shared/utils/mediaUrl.ts).
String? toAbsoluteMediaUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final key = value.startsWith('/') ? value.substring(1) : value;
  return '$cdnBaseUrl/$key';
}
