// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// hcl_page_test.dart
// Tests for the app
//
// 2023 December
// Author: Max Korbel <max.korbel@intel.com>

import 'package:confapp/hcl/hcl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';

String? observeOutput(WidgetTester tester) {
  final widget = tester.widget<TextField>(
    find.byKey(const Key('generatedSV')),
  );
  return widget.controller?.text;
}

List<Configurator> components = componentRegistry;

Future<void> pumpHclPage(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: HCLPage(
        components: components,
      ),
    ),
  );
  await tester.pump();
}

Future<void> showOnlyGeneratedSv(WidgetTester tester) async {
  await tester.tap(find.byTooltip('ROHD Schematic'));
  await tester.pump();
  await tester.tap(find.byTooltip('ROHD Source'));
  await tester.pump();
}

Future<void> pumpUntilOutputContains(
  WidgetTester tester,
  String expected,
) async {
  for (var i = 0; i < 100; i++) {
    final output = find.byKey(const Key('generatedSV'));
    if (tester.any(output) &&
        tester.widget<TextField>(output).controller!.text.contains(expected)) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(observeOutput(tester), contains(expected));
}

void main() {
  testWidgets('should return message to click generate when page load',
      (tester) async {
    await pumpHclPage(tester);

    expect(
      find.text('Click "Generate" to see the ROHD schematic'),
      findsOneWidget,
    );
  });

  testWidgets('keeps horizontally scrolled source below its scrollbar',
      (tester) async {
    await pumpHclPage(tester);
    await showOnlyGeneratedSv(tester);

    await tester.tap(find.byKey(const Key('generateRTL')));
    await pumpUntilOutputContains(tester, 'module');

    final generatedSv = find.byKey(const Key('generatedSV'));
    final horizontalScrollbar = find.ancestor(
      of: generatedSv,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollbar &&
            widget.scrollbarOrientation == ScrollbarOrientation.top,
      ),
    );
    expect(horizontalScrollbar, findsOneWidget);

    final scrollbar = tester.widget<Scrollbar>(horizontalScrollbar);
    final scrollController = scrollbar.controller!;
    expect(scrollController.position.maxScrollExtent, greaterThan(0));

    scrollController.jumpTo(scrollController.position.maxScrollExtent / 2);
    await tester.pump();

    const materialScrollbarMargin = 2.0;
    const minimumContentGap = 2.0;
    final minimumClearance =
        scrollbar.thickness! + materialScrollbarMargin + minimumContentGap;
    final actualClearance = tester.getTopLeft(generatedSv).dy -
        tester.getTopLeft(horizontalScrollbar).dy;

    expect(actualClearance, greaterThanOrEqualTo(minimumClearance));
  });

  testWidgets('should return changes when fields is manipulated',
      (tester) async {
    await pumpHclPage(tester);
    await showOnlyGeneratedSv(tester);

    final directionKnob = find.byKey(const Key('Direction'));
    final btnGenerateRTL = find.byKey(const Key('generateRTL'));

    // tap on the rotate direction field
    await tester.tap(directionKnob);
    await tester.pump(const Duration(milliseconds: 300));

    // change the text to left
    final rightButton = find.text('left').last;
    await tester.tap(rightButton);
    await tester.pump(const Duration(milliseconds: 300));

    // tap on the generate RTL button
    await tester.tap(btnGenerateRTL);

    await pumpUntilOutputContains(tester, 'RotateLeft');

    expect(observeOutput(tester), contains('RotateLeft'));
  });

  testWidgets('shows stable labels for type-valued choices', (tester) async {
    await pumpHclPage(tester);

    await tester.tap(find.text('One-hot Converter'));
    await tester.pump();

    final directionKnob = find.byKey(const Key('Direction'));
    expect(
      find.descendant(
        of: directionKnob,
        matching: find.text('OneHotToBinary'),
      ),
      findsOneWidget,
    );

    await tester.tap(directionKnob);
    await tester.pump();

    expect(find.text('BinaryToOneHot').last, findsOneWidget);
  });

  testWidgets('should transit to another component when clicked on sidebar',
      (tester) async {
    await pumpHclPage(tester);
    await showOnlyGeneratedSv(tester);

    final sidebarPriorityArbiter = find.text('Priority Arbiter');
    final btnGenerateRTL = find.byKey(const Key('generateRTL'));

    // tap on the priority Arbiter located in the sidebar
    await tester.tap(sidebarPriorityArbiter);

    await tester.pump();

    // tap on the generate RTL button
    await tester.tap(btnGenerateRTL);

    await pumpUntilOutputContains(tester, 'PriorityArbiter');

    expect(observeOutput(tester), contains('PriorityArbiter'));
  });

  testWidgets('discards generation when the selected component changes',
      (tester) async {
    await pumpHclPage(tester);
    await showOnlyGeneratedSv(tester);

    await tester.tap(find.byKey(const Key('generateRTL')));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.text('Priority Arbiter'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('generateRTL')));
    await pumpUntilOutputContains(tester, 'PriorityArbiter');

    expect(observeOutput(tester), contains('PriorityArbiter'));
  });
}
