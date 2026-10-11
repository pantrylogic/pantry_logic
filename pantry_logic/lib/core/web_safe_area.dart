import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'safe_area_insets_stub.dart'
    if (dart.library.js_interop) 'safe_area_insets_web.dart';
import 'theme.dart';

/// Adds the device safe-area insets to MediaQuery on web, where Flutter
/// reports zero padding even though the app draws under the iOS status bar
/// (viewport-fit=cover + black-translucent). With this in place SafeArea,
/// AppBar and NavigationBar keep content clear of the clock, notch and home
/// indicator.
///
/// Also paints a band over exactly the top inset in the "I'm Hungry" button
/// colour ([AppPalette.primary]), so iOS's white status-bar text always sits
/// on green in both light and dark mode. The band is painted above the
/// routes, so it covers that strip on every screen (AppBar or not) without
/// changing layout. No-op on other platforms.
class WebSafeArea extends StatelessWidget {
  const WebSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Depends on MediaQuery, so this rebuilds (and re-reads the insets) on
    // resize and rotation.
    final mq = MediaQuery.of(context);
    final device = deviceSafeAreaInsets();
    if (device == EdgeInsets.zero) return child;

    final viewPadding = EdgeInsets.fromLTRB(
      math.max(mq.viewPadding.left, device.left),
      math.max(mq.viewPadding.top, device.top),
      math.max(mq.viewPadding.right, device.right),
      math.max(mq.viewPadding.bottom, device.bottom),
    );
    // Like the engine does: the on-screen keyboard consumes bottom padding.
    final padding = viewPadding.copyWith(
      bottom: math.max(0.0, viewPadding.bottom - mq.viewInsets.bottom),
    );

    final content = MediaQuery(
      data: mq.copyWith(viewPadding: viewPadding, padding: padding),
      child: child,
    );
    if (viewPadding.top == 0) return content;

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        content,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: viewPadding.top,
          child: IgnorePointer(
            child: ColoredBox(color: AppPalette.of(context).primary),
          ),
        ),
      ],
    );
  }
}
