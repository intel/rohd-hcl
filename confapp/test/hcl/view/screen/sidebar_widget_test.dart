// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sidebar_widget_test.dart
// Tests for the collapsible component taxonomy sidebar.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/cubit/component_cubit.dart';
import 'package:confapp/hcl/view/screen/sidebar_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';

Future<ComponentCubit> _pumpSidebar(
  WidgetTester tester,
  List<Configurator> components,
) async {
  final cubit = ComponentCubit(components);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(
          body: ComponentsSidebar(width: 300),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

Finder _group(String category, String subcategory) =>
    find.byKey(PageStorageKey<String>(
      'component-group-$category-$subcategory',
    ));

Future<void> _openArithmetic(WidgetTester tester) async {
  await tester.tap(find.text('Arithmetic'));
  await tester.pumpAndSettle();
  for (final label in ['Addition', 'Multiplication', 'Floating Point']) {
    final heading = find.text(label);
    if (heading.evaluate().isNotEmpty) {
      await tester.tap(heading);
      await tester.pumpAndSettle();
    }
  }
}

void main() {
  testWidgets('all categories and subcategories start collapsed',
      (tester) async {
    final registry = componentRegistry;
    await _pumpSidebar(tester, registry);
    final categories = registry.map((component) => component.category).toSet();
    for (final category in categories) {
      expect(find.text(category.label).hitTestable(), findsOneWidget);
    }
    for (final component in registry) {
      expect(find.byKey(ObjectKey(component)), findsNothing);
    }
    await tester.tap(find.text('Arithmetic'));
    await tester.pumpAndSettle();
    expect(find.text('Addition'), findsOneWidget);
    expect(
        find.byKey(ObjectKey(
          registry
              .firstWhere((component) => component.subcategory == 'addition'),
        )),
        findsNothing);
    expect(
      tester
          .widget<ExpansionTile>(_group('arithmetic', 'addition'))
          .initiallyExpanded,
      isFalse,
    );
  });

  testWidgets('groups existing metadata without empty categories or duplicates',
      (tester) async {
    final components = [
      RotateConfigurator(),
      RippleCarryAdderConfigurator(),
      FloatingPointAdderConfigurator(),
      CompoundAdderConfigurator(),
    ];
    await _pumpSidebar(tester, components);

    expect(find.text('Arithmetic'), findsOneWidget);
    expect(find.text('Bit Operations'), findsOneWidget);
    expect(find.text('Memory'), findsNothing);
    await _openArithmetic(tester);
    await tester.tap(find.text('Bit Operations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shifting'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(5));
    final addition = _group('arithmetic', 'addition');
    for (final component in components) {
      expect(find.text(component.name), findsOneWidget);
    }
    expect(
      find.descendant(
        of: addition,
        matching: find.text('Compound Adder'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Compound Adder')).dy,
      lessThan(tester.getTopLeft(find.text('Ripple Carry Adder')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Addition')).dy,
      lessThan(tester.getTopLeft(find.text('Floating Point')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapse and selection preserve group state and knob values',
      (tester) async {
    final adder = RippleCarryAdderConfigurator();
    final multiplier = MultiplierConfigurator();
    final before = adder.toJson();
    final cubit = await _pumpSidebar(tester, [adder, multiplier]);
    final addition = _group('arithmetic', 'addition');

    await _openArithmetic(tester);
    await tester.tap(find.text(adder.name));
    await tester.pumpAndSettle();
    expect(cubit.state, same(adder));
    await tester.tap(find.text('Addition'));
    await tester.pumpAndSettle();
    expect(find.text(adder.name).hitTestable(), findsNothing);
    expect(cubit.state, same(adder));

    await tester.tap(find.text(multiplier.name));
    await tester.pumpAndSettle();
    expect(cubit.state, same(multiplier));
    expect(find.text(adder.name).hitTestable(), findsNothing);
    expect(tester.widget<ExpansionTile>(addition).initiallyExpanded, isFalse);

    await tester.tap(find.text('Addition'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(adder.name));
    await tester.pumpAndSettle();
    expect(cubit.state, same(adder));
    expect(adder.toJson(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the full current registry is reachable in its declared groups',
      (tester) async {
    final registry = componentRegistry
      ..sort((a, b) {
        final category = a.category.index.compareTo(b.category.index);
        if (category != 0) {
          return category;
        }
        final subcategory = a.subcategory.compareTo(b.subcategory);
        return subcategory != 0
            ? subcategory
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    await _pumpSidebar(tester, registry);
    final scrollable = find.byType(Scrollable).first;
    ComponentCategory? openedCategory;
    String? openedSubcategory;
    for (final component in registry) {
      if (component.category != openedCategory) {
        final category = find.text(component.category.label);
        await tester.scrollUntilVisible(category, 200, scrollable: scrollable);
        await tester.pumpAndSettle();
        await tester.ensureVisible(category);
        await tester.pumpAndSettle();
        await tester.tap(category);
        await tester.pumpAndSettle();
        openedCategory = component.category;
        openedSubcategory = null;
      }
      final group = _group(component.category.id, component.subcategory);
      if (component.subcategory != openedSubcategory) {
        final header =
            find.descendant(of: group, matching: find.byType(ListTile)).first;
        await tester.scrollUntilVisible(header, 200, scrollable: scrollable);
        await tester.pumpAndSettle();
        await tester.ensureVisible(header);
        await tester.pumpAndSettle();
        await tester.tap(header);
        await tester.pumpAndSettle();
        openedSubcategory = component.subcategory;
      }
      final tile = find.byKey(ObjectKey(component));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: group, matching: tile),
        findsOneWidget,
      );
      await tester.tap(tile);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('category collapse preserves nested expansion and selection',
      (tester) async {
    final adder = RippleCarryAdderConfigurator();
    final multiplier = MultiplierConfigurator();
    final rotate = RotateConfigurator();
    final cubit = await _pumpSidebar(tester, [adder, multiplier, rotate]);
    final before = adder.toJson();

    await _openArithmetic(tester);
    await tester.tap(find.text('Addition'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arithmetic'));
    await tester.pumpAndSettle();
    expect(find.text('Multiplication').hitTestable(), findsNothing);
    expect(find.byKey(ObjectKey(multiplier)).hitTestable(), findsNothing);
    expect(cubit.state, same(adder));

    await tester.tap(find.text('Bit Operations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shifting'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ObjectKey(rotate)));
    await tester.pumpAndSettle();
    expect(cubit.state, same(rotate));
    await tester.tap(find.text('Arithmetic'));
    await tester.pumpAndSettle();
    expect(find.text('Multiplication').hitTestable(), findsOneWidget);
    expect(find.byKey(ObjectKey(adder)).hitTestable(), findsNothing);
    expect(find.byKey(ObjectKey(multiplier)).hitTestable(), findsOneWidget);
    expect(adder.toJson(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu headers and component rows use compact vertical spacing',
      (tester) async {
    final adder = CompoundAdderConfigurator();
    await _pumpSidebar(tester, [adder]);
    await _openArithmetic(tester);
    final categoryHeader = find
        .descendant(
          of: find.byKey(const PageStorageKey<String>(
            'component-category-arithmetic',
          )),
          matching: find.byType(ListTile),
        )
        .first;
    final subcategoryHeader = find
        .descendant(
          of: _group('arithmetic', 'addition'),
          matching: find.byType(ListTile),
        )
        .first;

    expect(tester.getSize(categoryHeader).height, lessThanOrEqualTo(36));
    expect(tester.getSize(subcategoryHeader).height, lessThanOrEqualTo(32));
    expect(tester.getSize(find.byKey(ObjectKey(adder))).height, 32);
    expect(tester.takeException(), isNull);
  });
}
