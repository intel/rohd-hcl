import 'package:confapp_flutter/hcl/hcl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String? observeOutput(WidgetTester tester) {
  final selectableTextFinder = find.byType(SelectableText);
  final widget = tester.widget<SelectableText>(selectableTextFinder);
  return widget.data;
}

void main() {
  testWidgets('should return initial RTL when page load', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HCLPage(),
      ),
    );

    await tester.pumpAndSettle();

    final selectableTextFinder = find.byType(SelectableText);
    expect(selectableTextFinder, findsOneWidget);

    final widget = tester.widget<SelectableText>(selectableTextFinder);
    final textOutput = widget.data;

    expect(textOutput?.contains('RotateRight'), true);
  });

  testWidgets('should return changes when fields is manipulated',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HCLPage(),
      ),
    );

    await tester.pumpAndSettle();

    final directionKnob = find.byKey(const Key('rotateDirectionKnob'));
    final btnGenerateRTL = find.byKey(const Key('generateRTL'));

    // tap on the rotate direction field
    await tester.tap(directionKnob);

    // change the text to left
    await tester.enterText(directionKnob, 'left');

    // tap on the generate RTL button
    await tester.tap(btnGenerateRTL);

    // wait for widget to rebuild by pump
    await tester.pump();

    expect(observeOutput(tester)?.contains('RotateLeft'), true);
  });

  testWidgets('should transit to another component when clicked on sidebar',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HCLPage(),
      ),
    );

    await tester.pumpAndSettle();

    final sidebarPriorityArbiter = find.text('Priority Arbiter');
    final btnGenerateRTL = find.byKey(const Key('generateRTL'));

    // tap on the priority Arbiter located in the sidebar
    await tester.tap(sidebarPriorityArbiter);

    await tester.pump();

    // tap on the generate RTL button
    await tester.tap(btnGenerateRTL);

    // wait for changes
    await tester.pump();

    expect(observeOutput(tester)?.contains('PriorityArbiter'), true);
  });
}
