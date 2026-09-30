import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The Pantry Logic jar logo.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64});

  /// Width in logical pixels (height follows the logo's aspect ratio).
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/logo_small.png',
      width: size,
      semanticLabel: 'Pantry Logic',
      filterQuality: FilterQuality.medium,
    );
  }
}

/// A Material icon in a soft circular badge, used for illustrative
/// moments (empty states, onboarding headers).
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.size = 64});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.accentLight.withValues(alpha: p.isDark ? 1 : 0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * 0.5, color: p.primary),
    );
  }
}
