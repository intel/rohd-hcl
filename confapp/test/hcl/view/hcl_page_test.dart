// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// hcl_page_test.dart
// Tests for the app
//
// 2023 December
// Author: Max Korbel <max.korbel@intel.com>

import 'package:confapp/hcl/cubit/component_cubit.dart';
import 'package:confapp/hcl/hcl.dart';
import 'package:confapp/hcl/view/screen/sidebar_widget.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' as flutter_widgets;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rohd/rohd.dart' show SourceTracer;
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';

String? observeOutput(WidgetTester tester) {
  final widget = tester.widget<TextField>(
    find.byKey(const Key('generatedSV')),
  );
  return widget.controller?.text;
}

List<Configurator> components = componentRegistry;

const _missingToggleGateAsset =
    'assets/rohd_src/clocking/gating/toggle_gate.dart';

class _MissingSourceAssetBundle extends CachingAssetBundle {
  _MissingSourceAssetBundle(this.missingAsset);

  final String missingAsset;

  @override
  Future<ByteData> load(String key) {
    if (key == missingAsset) {
      return Future<ByteData>.error(
        FlutterError('Unable to load asset: "$key".'),
      );
    }
    return rootBundle.load(key);
  }
}

Future<void> pumpHclPage(
  WidgetTester tester, {
  AssetBundle? assetBundle,
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: flutter_widgets.DefaultAssetBundle(
        bundle: assetBundle ?? rootBundle,
        child: HCLPage(
          components: components,
        ),
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

Future<void> tapSidebarComponent(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 300));
  final component =
      components.singleWhere((component) => component.name == name);
  final scrollable = find
      .descendant(
        of: find.byType(ComponentsSidebar),
        matching: find.byType(Scrollable),
      )
      .first;
  final category = find.byKey(PageStorageKey<String>(
    'component-category-${component.category.id}',
  ));
  await tester.scrollUntilVisible(category, 250, scrollable: scrollable);
  final group = find.byKey(PageStorageKey<String>(
    'component-group-${component.category.id}-${component.subcategory}',
  ));
  if (group.evaluate().isEmpty) {
    await tester.tap(
      find.descendant(of: category, matching: find.byType(ListTile)).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.ensureVisible(group);
  await tester.pump(const Duration(milliseconds: 300));
  final tile = find.byKey(ObjectKey(component));
  if (tile.evaluate().isEmpty) {
    await tester.tap(
      find.descendant(of: group, matching: find.byType(ListTile)).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.scrollUntilVisible(
    tile,
    250,
    scrollable: scrollable,
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(tile);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(tile);
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
  test('sorts components alphabetically without mutating the input', () {
    final input = <Configurator>[
      RotateConfigurator(),
      ApbCsrCompleterConfigurator(),
      CountConfigurator(),
    ];
    final originalOrder = input.map((component) => component.name).toList();
    final cubit = ComponentCubit(input);
    addTearDown(cubit.close);

    expect(
      cubit.components.map((component) => component.name),
      orderedEquals(['APB CSR Completer', 'Count', 'Rotate']),
    );
    expect(cubit.state, same(input.first));
    expect(
      input.map((component) => component.name),
      orderedEquals(originalOrder),
    );
  });

  testWidgets('should return message to click generate when page load',
      (tester) async {
    await pumpHclPage(tester);

    expect(
      find.text('Click "Generate" to see the ROHD schematic'),
      findsOneWidget,
    );
  });

  testWidgets('shows a popup when a ROHD source asset is missing',
      (tester) async {
    await pumpHclPage(
      tester,
      assetBundle: _MissingSourceAssetBundle(_missingToggleGateAsset),
    );
    await tester.tap(find.byTooltip('ROHD Schematic'));
    await tester.pump();
    await tapSidebarComponent(tester, 'Toggle Gate');
    await tester.pump();
    await tester.tap(find.byKey(const Key('generateRTL')));

    for (var i = 0; i < 100; i++) {
      if (tester.any(find.text('Missing source asset'))) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Missing source asset'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(_missingToggleGateAsset),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows component taxonomy categories and subcategories',
      (tester) async {
    await pumpHclPage(tester);

    expect(find.text('Arithmetic'), findsOneWidget);
    expect(find.text('Accumulation'), findsNothing);
    await tester.tap(find.text('Arithmetic'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Accumulation'), findsOneWidget);
  });

  testWidgets('uses a bundled monospace font for generated source',
      (tester) async {
    await pumpHclPage(tester);
    await showOnlyGeneratedSv(tester);

    await tester.tap(find.byKey(const Key('generateRTL')));
    await pumpUntilOutputContains(tester, 'module');

    final generatedSv = find.byKey(const Key('generatedSV'));
    final generatedSvField = tester.widget<TextField>(generatedSv);
    expect(generatedSvField.style?.fontFamily, 'RobotoMono');
    expect(generatedSvField.style?.fontFamilyFallback, contains('monospace'));

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

  testWidgets('retains nested source traces while the source tab is hidden',
      (tester) async {
    await pumpHclPage(tester);
    await showOnlyGeneratedSv(tester);
    await tapSidebarComponent(tester, 'Ripple Carry Adder');
    await tester.pump();

    await tester.tap(find.byKey(const Key('generateRTL')));
    await pumpUntilOutputContains(tester, 'RippleCarryAdder');
    expect(SourceTracer.isActive, isFalse);

    await tester.tap(find.byTooltip('ROHD Source'));
    for (var i = 0; i < 100; i++) {
      if (tester.any(find.text('adder.dart'))) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('adder.dart'), findsOneWidget);
    expect(find.text('ripple_carry_adder.dart'), findsOneWidget);
    expect(SourceTracer.isActive, isFalse);
    expect(tester.takeException(), isNull);
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

  testWidgets('integer parameters validate, step and generate with the edit',
      (tester) async {
    await pumpHclPage(tester);
    await showOnlyGeneratedSv(tester);
    await tapSidebarComponent(tester, 'Rotate');
    await tester.pump();
    final rotate =
        components.singleWhere((component) => component is RotateConfigurator)
            as RotateConfigurator;
    final field = find.descendant(
      of: find.byKey(const Key('Original Width')),
      matching: find.byType(TextFormField),
    );
    final original = rotate.originalWidthKnob.value;
    await tester.enterText(field, '0');
    await tester.pump();
    expect(rotate.originalWidthKnob.value, original);
    await tester.tap(find.byKey(const Key('generateRTL')));
    await tester.pump();
    expect(find.text('Must be at least 1'), findsOneWidget);

    await tester.enterText(field, '0x10');
    await tester.pump();
    expect(rotate.originalWidthKnob.value, 16);
    await tester.tap(find.byTooltip('Increase Original Width'));
    await tester.pump();
    expect(rotate.originalWidthKnob.value, 17);
    await tester.tap(find.byKey(const Key('generateRTL')));
    await pumpUntilOutputContains(tester, 'input logic [16:0]');
    expect(tester.takeException(), isNull);
  });

  testWidgets('output toolbar unpinned by lock icon slides in on hover',
      (tester) async {
    Finder tooltip(String message) => find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == message,
        );

    await pumpHclPage(tester);
    expect(tooltip('Unpin output toolbar'), findsOneWidget);
    final barTop = tester.getTopLeft(find.byType(AppBar).last).dy;
    final barCenterX = tester.getCenter(find.byType(AppBar).last).dx;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(Offset(barCenterX, barTop + 60));
    await tester.pump();

    await tester.tap(tooltip('Unpin output toolbar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tooltip('Pin output toolbar'), findsOneWidget);
    expect(tester.getTopLeft(tooltip('Pin output toolbar')).dy,
        lessThan(barTop - 20));

    await mouse.moveTo(Offset(barCenterX, barTop + 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(tooltip('Pin output toolbar')).dy,
        greaterThanOrEqualTo(barTop - 1));

    await mouse.moveTo(Offset(barCenterX, barTop + 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(tooltip('Pin output toolbar')).dy,
        lessThan(barTop - 20));
  });

  testWidgets('components menu unpinned by lock icon slides in on hover',
      (tester) async {
    Finder tooltip(String message) => find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == message,
        );

    await pumpHclPage(tester);
    expect(tooltip('Unpin components menu'), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(800, 450));
    await tester.pump();

    await tester.tap(tooltip('Unpin components menu'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tooltip('Pin components menu'), findsOneWidget);
    expect(tester.getTopLeft(tooltip('Pin components menu')).dx, lessThan(0));

    await mouse.moveTo(const Offset(4, 450));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        tester.getTopLeft(tooltip('Pin components menu')).dx, greaterThan(0));

    await mouse.moveTo(const Offset(800, 450));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(tooltip('Pin components menu')).dx, lessThan(0));

    await mouse.moveTo(const Offset(4, 450));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(tooltip('Pin components menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tooltip('Unpin components menu'), findsOneWidget);
    expect(
        tester.getTopLeft(tooltip('Unpin components menu')).dx, greaterThan(0));
  });

  testWidgets('shows stable labels for type-valued choices', (tester) async {
    await pumpHclPage(tester);

    await tapSidebarComponent(tester, 'One-hot Converter');
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

    final btnGenerateRTL = find.byKey(const Key('generateRTL'));

    // tap on the priority Arbiter located in the sidebar
    await tapSidebarComponent(tester, 'Priority Arbiter');

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
    await tapSidebarComponent(tester, 'Priority Arbiter');
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('generateRTL')));
    await pumpUntilOutputContains(tester, 'PriorityArbiter');

    expect(observeOutput(tester), contains('PriorityArbiter'));
  });
}
