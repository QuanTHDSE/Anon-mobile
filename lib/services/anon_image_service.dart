import '../core/api_client.dart';
import '../models/anon_image.dart';

/// Port of src/services/anonImageService.ts (user-facing subset).
class AnonImageService {
  AnonImageService._();

  static final AnonImageService instance = AnonImageService._();

  ApiClient get _api => ApiClient.instance;

  /// Gallery of anonymous avatars. Filters to active-only client-side so the
  /// picker never offers an inactive image (assignment rejects it).
  Future<List<AnonImage>> getAnonImages({bool activeOnly = true}) async {
    final res = await _api.get('/api/v1/anon-images');
    List raw;
    if (res is List) {
      raw = res;
    } else if (res is Map<String, dynamic>) {
      raw = (res['items'] ??
          res['data'] ??
          res['results'] ??
          res['anonImages'] ??
          []) as List;
    } else {
      raw = const [];
    }
    final parsed = raw
        .whereType<Map<String, dynamic>>()
        .map(AnonImage.fromJson)
        .where((x) => x.id.isNotEmpty && x.imageUrl.isNotEmpty)
        .toList();
    return activeOnly ? parsed.where((x) => x.isActive).toList() : parsed;
  }

  /// Assign one of the gallery images as the current user's anonymous avatar.
  Future<void> setMyAnonImage(String anonImageId) async {
    await _api.patch('/api/v1/users/me/anon-image/$anonImageId');
  }
}
