import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Tappable section header with a title, an item count and a chevron that
/// rotates to show whether the section is expanded.
class CollapsibleSectionHeader extends StatelessWidget {
  const CollapsibleSectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Semantics(
      button: true,
      expanded: expanded,
      label: '$title, $count item${count == 1 ? '' : 's'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: nsSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: p.accentLight.withValues(alpha: p.isDark ? 1 : 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: nsSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.isDark ? p.textPrimary : p.primary,
                  ),
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: expanded ? 0 : -0.25,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 22,
                  color: p.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
