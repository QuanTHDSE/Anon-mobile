import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/subscription.dart';

/// Port of src/services/subscriptionService.ts (user-facing subset).
class SubscriptionService {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  ApiClient get _api => ApiClient.instance;

  Future<List<SubscriptionPlan>> getPlans() async {
    final res =
        await _api.get('/api/v1/subscription-plans?isActive=true&pageSize=50');
    List raw;
    if (res is List) {
      raw = res;
    } else if (res is Map<String, dynamic>) {
      raw = (res['subscriptionPlans'] ??
          res['items'] ??
          res['plans'] ??
          res['data'] ??
          []) as List;
    } else {
      raw = const [];
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPlan.fromJson)
        .toList();
  }

  Future<OrderInfo> createOrder(String planId) async {
    final res = await _api
        .post('/api/v1/payments/create-order', {'planId': planId});
    return OrderInfo(
        res is Map<String, dynamic> ? res : const <String, dynamic>{});
  }

  Future<OrderInfo> getOrder(String orderId) async {
    final res = await _api.get('/api/v1/payments/orders/$orderId');
    return OrderInfo(
        res is Map<String, dynamic> ? res : const <String, dynamic>{});
  }

  Future<List<UserSubscription>> getUserSubscriptions(String userId,
      {int page = 1, int pageSize = 10}) async {
    final res = await _api.get(
        '/api/v1/user-subscriptions/user/$userId?page=$page&pageSize=$pageSize');
    if (res is! Map<String, dynamic>) return const [];
    return (res['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UserSubscription.fromJson)
        .toList();
  }

  /// Premium check without side-effects — any active, unexpired subscription.
  Future<bool> fetchPremiumStatus(String userId) async {
    try {
      final subs = await getUserSubscriptions(userId, pageSize: 10);
      return subs.any((s) => s.isActive);
    } catch (_) {
      return false;
    }
  }

  static String formatPrice(num price) =>
      '${NumberFormat.decimalPattern('vi_VN').format(price)}đ';
}
