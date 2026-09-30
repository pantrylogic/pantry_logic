import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/core/routes.dart';

/// Regression test for the Restock "Done" button, which used to look for
/// route names that no route actually set — so it always popped to the root.
void main() {
  Widget page(String label, {VoidCallback? onDone}) => Builder(
        builder: (context) => Scaffold(
          body: Column(children: [
            Text(label),
            if (onDone != null)
              TextButton(onPressed: onDone, child: const Text('Done')),
          ]),
        ),
      );

  Future<NavigatorState> pumpRoot(WidgetTester tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      home: page('root'),
    ));
    return key.currentState!;
  }

  void push(NavigatorState nav, String label, [String? name]) {
    nav.push(MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (context) => page(
        label,
        onDone: label == 'restock' ? () => popToRestockOrigin(context) : null,
      ),
    ));
  }

  testWidgets('Done from meal detail returns to meal detail', (tester) async {
    final nav = await pumpRoot(tester);
    push(nav, 'meal detail', AppRoutes.mealDetail);
    await tester.pumpAndSettle();
    push(nav, 'restock', AppRoutes.restock);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('meal detail'), findsOneWidget);
    expect(find.text('restock'), findsNothing);
  });

  testWidgets('Done from the Hungry flow returns to the category picker',
      (tester) async {
    final nav = await pumpRoot(tester);
    push(nav, 'hungry category', AppRoutes.hungryCategory);
    await tester.pumpAndSettle();
    push(nav, 'suggestion', AppRoutes.hungrySuggestion);
    await tester.pumpAndSettle();
    push(nav, 'restock', AppRoutes.restock);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('hungry category'), findsOneWidget);
    expect(find.text('suggestion'), findsNothing);
  });

  testWidgets('Done from Home/Calendar (root) returns to the root',
      (tester) async {
    final nav = await pumpRoot(tester);
    push(nav, 'restock', AppRoutes.restock);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    expect(find.text('restock'), findsNothing);
  });

  testWidgets('Done from a meal opened via Home Tonight returns to the meal',
      (tester) async {
    final nav = await pumpRoot(tester);
    push(nav, 'hungry category', AppRoutes.hungryCategory);
    await tester.pumpAndSettle();
    push(nav, 'meal detail', AppRoutes.mealDetail);
    await tester.pumpAndSettle();
    push(nav, 'restock', AppRoutes.restock);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    // Stops at the nearest origin, not the first one pushed.
    expect(find.text('meal detail'), findsOneWidget);
  });
}
