// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// hcl_page_test.dart
// Tests for the app
//
// 2023 December

import 'package:confapp/hcl/hcl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';

String? observeOutput(WidgetTester tester) {
  final selectableTextFinder = find.byType(SelectableText);
  final widget = tester.widget<SelectableText>(selectableTextFinder);
  return widget.data;
}

List<Configurator> components = componentRegistry;

void main() {
  testWidgets('should return message to click generate when page load',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HCLPage(
          components: components,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final selectableTextFinder = find.byType(SelectableText);
    expect(selectableTextFinder, findsOneWidget);

    final widget = tester.widget<SelectableText>(selectableTextFinder);
    final textOutput = widget.data;

    expect(textOutput?.contains('Click'), true);
  });

  testWidgets('should return changes when fields is manipulated',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HCLPage(
          components: components,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final directionKnob = find.byKey(const Key('Direction'));
    final btnGenerateRTL = find.byKey(const Key('generateRTL'));

    // tap on the rotate direction field
    await tester.tap(directionKnob);
    await tester.pumpAndSettle();

    // change the text to left
    final rightButton = find.text('left').last;
    await tester.tap(rightButton);
    await tester.pumpAndSettle();

    // tap on the generate RTL button
    await tester.tap(btnGenerateRTL);

    // wait for widget to rebuild by pump
    await tester.pumpAndSettle();

    expect(observeOutput(tester)?.contains('RotateLeft'), true);
  });

  testWidgets('should transit to another component when clicked on sidebar',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HCLPage(
          components: components,
        ),
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
    await tester.pumpAndSettle();

    expect(observeOutput(tester)?.contains('PriorityArbiter'), true);
  });
}
