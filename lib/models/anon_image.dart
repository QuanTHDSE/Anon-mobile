import '../core/config.dart';

String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

/// Anonymous avatar gallery item (port of web anonImageService's AnonImage).
class AnonImage {
  AnonImage({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.fileKey,
    required this.isActive,
    required this.isExclusive,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String fileKey;
  final bool isActive;

  /// Premium-only image: only subscribers may assign it.
  final bool isExclusive;

  factory AnonImage.fromJson(Map<String, dynamic> json) => AnonImage(
        id: _str(json['id']) ?? _str(json['anonImageId']) ?? '',
        name: _str(json['name']) ?? _str(json['title']) ?? '',
        imageUrl: toAbsoluteMediaUrl(_str(json['fileUrl']) ??
                _str(json['imageUrl']) ??
                _str(json['url'])) ??
            '',
        fileKey: _str(json['fileKey']) ?? '',
        isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
        isExclusive: json['isExclusive'] == true,
      );
}
