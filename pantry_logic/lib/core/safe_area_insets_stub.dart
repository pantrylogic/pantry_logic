import 'package:flutter/widgets.dart';

/// Non-web platforms report safe areas through MediaQuery already.
EdgeInsets deviceSafeAreaInsets() => EdgeInsets.zero;
