import 'package:flutter/material.dart';

import '../services/user_service.dart';

/// Blue verified-style mark used to identify an active Premium subscriber.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tài khoản Premium',
      child: Icon(Icons.verified, size: size, color: const Color(0xFF3B82F6)),
    );
  }
}

/// Renders a user name and resolves their Premium status once per cached user.
///
/// Anonymous identities never expose the badge, even when their real account
/// owns an active subscription.
class PremiumUserName extends StatefulWidget {
  const PremiumUserName({
    super.key,
    required this.userId,
    required this.name,
    this.isAnonymous = false,
    this.isPremium,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.badgeSize = 16,
  });

  final String userId;
  final String name;
  final bool isAnonymous;
  final bool? isPremium;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final double badgeSize;

  @override
  State<PremiumUserName> createState() => _PremiumUserNameState();
}

class _PremiumUserNameState extends State<PremiumUserName> {
  bool _isPremium = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _resolvePremiumStatus();
  }

  @override
  void didUpdateWidget(covariant PremiumUserName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.isAnonymous != widget.isAnonymous ||
        oldWidget.isPremium != widget.isPremium) {
      _resolvePremiumStatus();
    }
  }

  void _resolvePremiumStatus() {
    final requestVersion = ++_requestVersion;
    final knownStatus = widget.isPremium;

    if (widget.isAnonymous || widget.userId.isEmpty || knownStatus != null) {
      final nextValue = !widget.isAnonymous && knownStatus == true;
      if (_isPremium != nextValue) {
        setState(() => _isPremium = nextValue);
      }
      return;
    }

    if (_isPremium) setState(() => _isPremium = false);
    UserService.instance
        .getUserPremium(widget.userId, username: widget.name)
        .then((value) {
          if (!mounted || requestVersion != _requestVersion) return;
          if (_isPremium != value) setState(() => _isPremium = value);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: widget.name),
          if (_isPremium) ...[
            const TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: PremiumBadge(size: widget.badgeSize),
            ),
          ],
        ],
      ),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      style: widget.style,
    );
  }
}
