import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Circular author avatar with anon-aware fallbacks:
/// image → anon icon (for anonymous) → orange initials.
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.isAnonymous = false,
    this.size = 40,
  });

  final String? imageUrl;
  final String? name;
  final bool isAnonymous;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    if (isAnonymous) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.group_outlined,
            size: size * 0.5, color: AppColors.textMuted),
      );
    }
    final initials = (name ?? '??').trim();
    final text = initials.isEmpty
        ? '??'
        : initials.substring(0, initials.length >= 2 ? 2 : 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFEDD5), Color(0xFFFFF7ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w900,
          color: AppColors.brand,
        ),
      ),
    );
  }
}
