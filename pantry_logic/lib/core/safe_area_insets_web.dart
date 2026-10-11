import 'dart:js_interop';

import 'package:flutter/widgets.dart';

/// Defined in web/index.html: [top, right, bottom, left] in CSS px.
@JS('pantryLogicSafeArea')
external JSArray<JSNumber> _pantryLogicSafeArea();

/// The device's env(safe-area-inset-*) values, which Flutter web doesn't
/// report itself. Zero if index.html doesn't provide them.
EdgeInsets deviceSafeAreaInsets() {
  try {
    final v = _pantryLogicSafeArea().toDart.map((n) => n.toDartDouble).toList();
    if (v.length != 4) return EdgeInsets.zero;
    return EdgeInsets.fromLTRB(v[3], v[0], v[1], v[2]);
  } catch (_) {
    return EdgeInsets.zero;
  }
}
