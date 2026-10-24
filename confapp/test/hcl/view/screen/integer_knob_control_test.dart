// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// integer_knob_control_test.dart
// Tests for the integer knob stepper control.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/view/screen/integer_knob_control.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

Future<void> _pump(
  WidgetTester tester,
  TextConfigKnob<int?> knob, {
  VoidCallback? onChanged,
  GlobalKey<FormState>? formKey,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: IntegerKnobControl(
            label: 'Width',
            knob: knob,
            onChanged: onChanged ?? () {},
          ),
        ),
      ),
    ));

void main() {
  testWidgets('retains the configured default and steps by one',
      (tester) async {
    final knob = PositiveIntConfigKnob(value: 8);
    var changes = 0;
    await _pump(tester, knob, onChanged: () => changes++);
    expect(find.text('8'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase Width'));
    await tester.pump();
    expect(knob.value, 9);
    expect(find.text('9'), findsOneWidget);
    await tester.tap(find.byTooltip('Decrease Width'));
    await tester.pump();
    expect(knob.value, 8);
    expect(changes, 2);
  });

  for (final minimum in [0, 1]) {
    testWidgets('decrement stops at $minimum', (tester) async {
      final knob = minimum == 0
          ? NonNegativeIntConfigKnob(value: 0)
          : PositiveIntConfigKnob(value: 1);
      await _pump(tester, knob);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate((widget) =>
                  widget is IconButton && widget.tooltip == 'Decrease Width'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextFormField), '${minimum - 1}');
      await tester.pump();
      expect(find.text('Must be at least $minimum'), findsOneWidget);
      expect(knob.value, minimum);
    });
  }

  testWidgets('invalid edits block form submission without changing the knob',
      (tester) async {
    final knob = PositiveIntConfigKnob(value: 8);
    final formKey = GlobalKey<FormState>();
    var changes = 0;
    await _pump(tester, knob, formKey: formKey, onChanged: () => changes++);
    for (final text in ['abc', '1.5', '', '0x', '-']) {
      await tester.enterText(find.byType(TextFormField), text);
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
      expect(knob.value, 8);
      expect(changes, 0);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate((widget) =>
                  widget is IconButton && widget.tooltip == 'Increase Width'),
            )
            .onPressed,
        isNull,
      );
    }
    await tester.enterText(find.byType(TextFormField), '0x100');
    await tester.pump();
    expect(knob.value, 256);
    expect(formKey.currentState!.validate(), isTrue);
    expect(changes, 1);
    await tester.tap(find.byTooltip('Increase Width'));
    await tester.pump();
    expect(knob.value, 257);
    expect(find.text('257'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed values can step below zero', (tester) async {
    final knob = IntConfigKnob(value: 0);
    await _pump(tester, knob);
    await tester.tap(find.byTooltip('Decrease Width'));
    await tester.pump();
    expect(knob.value, -1);
    await tester.enterText(find.byType(TextFormField), '-0x10');
    await tester.pump();
    expect(knob.value, -16);
  });

  testWidgets('optional integers can be cleared and reject invalid input',
      (tester) async {
    final knob = IntOptionalConfigKnob(value: 8);
    await _pump(tester, knob);
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();
    expect(knob.value, isNull);
    expect(find.text('Automatic'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.pump();
    expect(find.text('Enter a valid integer'), findsOneWidget);
    expect(knob.value, isNull);
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();
    await tester.tap(find.byTooltip('Increase Width'));
    await tester.pump();
    expect(knob.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replaced knobs and external value changes refresh the text',
      (tester) async {
    final first = IntConfigKnob(value: 8);
    await _pump(tester, first);
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.pump();
    final second = PositiveIntConfigKnob(value: 3);
    await _pump(tester, second);
    expect(find.text('3'), findsOneWidget);
    second.value = 5;
    await _pump(tester, second);
    expect(find.text('5'), findsOneWidget);
  });
}
