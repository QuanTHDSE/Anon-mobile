String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;
int _int(dynamic v, [int fallback = 0]) =>
    v is num ? v.toInt() : fallback;

/// Subscription plan — mirrors web subscriptionService's SubscriptionPlan.
class SubscriptionPlan {
  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.price,
    required this.durationDays,
    this.features,
    this.maxPostsPerDay,
    this.maxPostImageCount,
    this.canUploadPostFiles,
    this.canUseExclusiveAnonImages,
    this.canUsePremiumFeatures,
    required this.isActive,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final int price;
  final int durationDays;
  final String? features;
  final int? maxPostsPerDay;
  final int? maxPostImageCount;
  final bool? canUploadPostFiles;
  final bool? canUseExclusiveAnonImages;
  final bool? canUsePremiumFeatures;
  final bool isActive;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: _str(json['id']) ?? '',
        name: _str(json['name']) ?? '',
        slug: _str(json['slug']) ?? '',
        description: _str(json['description']),
        price: _int(json['price']),
        durationDays: _int(json['durationDays'], 30),
        features: json['features']?.toString(),
        maxPostsPerDay: json['maxPostsPerDay'] is num
            ? (json['maxPostsPerDay'] as num).toInt()
            : null,
        maxPostImageCount: json['maxPostImageCount'] is num
            ? (json['maxPostImageCount'] as num).toInt()
            : null,
        canUploadPostFiles: json['canUploadPostFiles'] as bool?,
        canUseExclusiveAnonImages: json['canUseExclusiveAnonImages'] as bool?,
        canUsePremiumFeatures: json['canUsePremiumFeatures'] as bool?,
        isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      );
}

class UserSubscription {
  UserSubscription({
    required this.id,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.planName,
  });

  final String id;
  final int status; // 0 = Active
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? planName;

  bool get isActive =>
      status == 0 &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now());

  factory UserSubscription.fromJson(Map<String, dynamic> json) =>
      UserSubscription(
        id: _str(json['id']) ?? '',
        status: _int(json['status']),
        startedAt: DateTime.tryParse(_str(json['startedAt']) ?? ''),
        expiresAt: DateTime.tryParse(_str(json['expiresAt']) ?? ''),
        planName: _str(json['planName']),
      );
}

/// SePay bank info parsed from the order's `qrUrl` (port of parseSepayQrUrl).
class ParsedBankInfo {
  ParsedBankInfo({
    required this.accountNumber,
    required this.bankCode,
    required this.bankName,
    required this.amount,
    required this.transferContent,
    required this.qrImageUrl,
  });

  final String accountNumber;
  final String bankCode;
  final String bankName;
  final int amount;
  final String transferContent;
  final String qrImageUrl;
}

const Map<String, String> _bankNames = {
  'TPB': 'TPBank (Ngân hàng Tiên Phong)',
  'VCB': 'Vietcombank',
  'TCB': 'Techcombank',
  'MB': 'MB Bank',
  'VPB': 'VPBank',
  'ACB': 'ACB',
  'BIDV': 'BIDV',
  'VTB': 'Vietinbank',
  'STB': 'Sacombank',
  'HDB': 'HDBank',
  'OCB': 'OCB',
  'MSB': 'MSB',
  'SHB': 'SHB',
  'EIB': 'Eximbank',
  'NAB': 'Nam A Bank',
  'BAB': 'Bac A Bank',
  'CAKE': 'CAKE by VPBank',
  'UBANK': 'Ubank by VPBank',
};

ParsedBankInfo? parseSepayQrUrl(String url) {
  try {
    final u = Uri.parse(url);
    final acc = u.queryParameters['acc'] ?? '';
    if (acc.isEmpty) return null;
    final bank = (u.queryParameters['bank'] ?? '').toUpperCase();
    return ParsedBankInfo(
      accountNumber: acc,
      bankCode: bank,
      bankName: _bankNames[bank] ?? bank,
      amount: int.tryParse(u.queryParameters['amount'] ?? '0') ?? 0,
      transferContent: u.queryParameters['des'] ?? '',
      qrImageUrl: url,
    );
  } catch (_) {
    return null;
  }
}

/// Create-order response — tolerant field extraction like the web app.
class OrderInfo {
  OrderInfo(this.raw);

  final Map<String, dynamic> raw;

  String get orderId =>
      _str(raw['orderId']) ??
      _str(raw['id']) ??
      _str(raw['orderCode']) ??
      _str(raw['referenceCode']) ??
      '';

  int amountOr(int fallback) =>
      raw['amount'] is num ? (raw['amount'] as num).toInt() : fallback;

  String? get qrUrl =>
      _str(raw['qrUrl']) ?? _str(raw['qrCodeUrl']) ?? _str(raw['qrImage']);

  dynamic get status => raw['status'];

  /// True if payment/subscription status means "paid/active".
  bool get isPaid {
    final s = status;
    if (s == 0 || s == 1) return true;
    if (s is String) {
      const paid = [
        'paid', 'completed', 'success', 'active', 'approved', 'confirmed',
        '0', '1',
      ];
      return paid.contains(s.toLowerCase());
    }
    return false;
  }
}
