import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The AnonWork brand logo (same eye mark used on the web app).
/// Renders the shared `assets/logo.svg` at [size] × [size] (natural
/// aspect ratio is ~54:45, so it's letterboxed inside a square box).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/logo.svg',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Logo followed by the "AnonWork" wordmark — used in headers/app bars.
class AppLogoWithText extends StatelessWidget {
  const AppLogoWithText({super.key, this.logoSize = 30, this.fontSize = 20});

  final double logoSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize),
        const SizedBox(width: 8),
        Text(
          'AnonWork',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFF15B29),
          ),
        ),
      ],
    );
  }
}
