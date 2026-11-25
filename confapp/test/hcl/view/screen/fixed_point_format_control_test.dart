// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_format_control_test.dart
// Tests for compact, labeled format editing and responsive layout.
//
// 2026 November 24
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/view/screen/fixed_point_format_control.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

void main() {
  for (final width in [600.0, 240.0, 200.0]) {
    testWidgets('format editor is compact without overflow at width $width',
        (tester) async {
      final knob = InferenceFixedPointFormatKnob(fractionBits: 4);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: FixedPointFormatControl(
              label: 'Score Format',
              knob: knob,
              onChanged: () {},
            ),
          ),
        ),
      ));
      expect(find.text('Score Format'), findsOneWidget);
      final total = tester.getSize(find.byType(Wrap)).width;
      expect(total, lessThanOrEqualTo(320));
      final bits = find.byKey(ObjectKey(knob.widthKnob));
      final fraction = find.byKey(ObjectKey(knob.fractionBitsKnob));
      final bitsPosition = tester.getTopLeft(bits);
      final fractionPosition = tester.getTopLeft(fraction);
      if (width >= 240) {
        expect(fractionPosition.dy, bitsPosition.dy);
        expect(fractionPosition.dx, greaterThan(bitsPosition.dx));
      } else {
        expect(fractionPosition.dy, greaterThan(bitsPosition.dy));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('distinct role labels retain independent validated edits',
      (tester) async {
    final query = InferenceFixedPointFormatKnob(width: 4);
    final score = InferenceFixedPointFormatKnob(width: 6);
    var changes = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            for (final entry in {'Query/Key': query, 'Score': score}.entries)
              FixedPointFormatControl(
                label: '${entry.key} Format',
                knob: entry.value,
                onChanged: () => changes++,
              ),
          ],
        ),
      ),
    ));
    expect(find.text('Query/Key Format'), findsOneWidget);
    expect(find.text('Score Format'), findsOneWidget);
    final scoreWidth = find.byKey(ObjectKey(score.widthKnob));
    await tester.enterText(scoreWidth, '-1');
    await tester.pump();
    expect(find.text('Must be at least 1'), findsOneWidget);
    expect(score.widthKnob.value, 6);
    expect(changes, 0);
    await tester.enterText(scoreWidth, '8');
    await tester.pump();
    expect(score.widthKnob.value, 8);
    expect(query.widthKnob.value, 4);
    expect(changes, 1);
    expect(tester.takeException(), isNull);
  });
}
