import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/core/theme.dart';
import 'package:pantry_logic/widgets/add_bar.dart';
import 'package:pantry_logic/widgets/app_snack_bar.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Column(children: [const Spacer(), child])),
    );

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

void main() {
  testWidgets('keeps focus and clears after each submit', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(_host(AddBar(
      hintText: 'Add…',
      autofocus: true,
      onSubmit: (t) async => submitted.add(t),
    )));
    await tester.pump();
    expect(_editable(tester).focusNode.hasFocus, isTrue);

    for (final item in ['milk', 'eggs']) {
      await tester.enterText(find.byType(TextField), item);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_editable(tester).focusNode.hasFocus, isTrue, reason: item);
      expect(_editable(tester).controller.text, isEmpty);
    }
    expect(submitted, ['milk', 'eggs']);
  });

  testWidgets('splitLines: a line break submits the whole text',
      (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(_host(AddBar(
      hintText: 'Add…',
      framed: false,
      splitLines: true,
      onSubmit: (t) async => submitted.add(t),
    )));
    await tester.enterText(find.byType(TextField), 'milk\neggs 2\n');
    await tester.pump();
    expect(submitted, ['milk\neggs 2']);
    expect(_editable(tester).controller.text, isEmpty);

    // A bare Enter on an empty field submits nothing.
    await tester.enterText(find.byType(TextField), '\n');
    await tester.pump();
    expect(submitted, hasLength(1));
  });

  testWidgets('framed: false renders a bare field at phone width (dark)',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(
      AddBar(hintText: 'Add step…', framed: false, onSubmit: (_) async {}),
      theme: AppTheme.dark,
    ));
    expect(find.byType(SafeArea), findsNothing);
    expect(find.text('Add step…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('undo snackbar can carry a second action', (tester) async {
    var undone = 0, added = 0;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showUndoSnackBar(
              ScaffoldMessenger.of(context),
              'Whole milk used up',
              onUndo: () => undone++,
              secondaryLabel: 'Add to list',
              onSecondary: () => added++,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Whole milk used up'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Add to list'));
    await tester.pumpAndSettle();
    expect(added, 1);
    expect(undone, 0);
    expect(find.text('Whole milk used up'), findsNothing);
  });

  testWidgets('two-action snackbar on a wide screen: Undo', (tester) async {
    var undone = 0;
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showUndoSnackBar(
              ScaffoldMessenger.of(context),
              'Eggs removed from stock.',
              onUndo: () => undone++,
              secondaryLabel: 'Add to list',
              onSecondary: () {},
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
  });
}
