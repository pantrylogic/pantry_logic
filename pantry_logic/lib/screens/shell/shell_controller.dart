import 'package:flutter/widgets.dart';

/// Bottom-nav tab indexes.
abstract final class ShellTab {
  static const home = 0;
  static const grocery = 1;
  static const stock = 2;
  static const meals = 3;
  static const calendar = 4;
}

/// Holds the selected bottom-nav tab. Children use it to switch tabs and to
/// learn when their own tab becomes active.
class ShellController extends ValueNotifier<int> {
  ShellController([super.initial = ShellTab.home]);

  void goTo(int tab) => value = tab;
}

/// Makes the [ShellController] available below MainShell. Lookups don't
/// register a dependency, so tab switches don't rebuild every tab — listen
/// to the controller instead (see [TabActivation]).
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ShellController controller;

  /// The nearest controller, or null outside MainShell (e.g. in tests).
  static ShellController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellScope>()?.controller;

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}

/// Calls [onTabActivated] whenever the bottom-nav switches to [tabIndex].
/// Tabs live in an IndexedStack, so initState runs only once; use this to
/// refresh data that would otherwise go stale.
mixin TabActivation<T extends StatefulWidget> on State<T> {
  int get tabIndex;

  void onTabActivated();

  ShellController? _shell;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = ShellScope.maybeOf(context);
    if (!identical(shell, _shell)) {
      _shell?.removeListener(_onShellChanged);
      _shell = shell?..addListener(_onShellChanged);
    }
  }

  void _onShellChanged() {
    if (mounted && _shell?.value == tabIndex) onTabActivated();
  }

  /// Switches the bottom-nav to [tab], if this widget is inside MainShell.
  void goToTab(int tab) => _shell?.goTo(tab);

  @override
  void dispose() {
    _shell?.removeListener(_onShellChanged);
    super.dispose();
  }
}
