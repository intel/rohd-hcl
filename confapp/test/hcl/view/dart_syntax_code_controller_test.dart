// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dart_syntax_code_controller_test.dart
// Tests for Dart syntax highlighting in the confapp source viewer.
//
// 2026 September 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/view/screen/dart_syntax_code_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/verilog.dart' as highlight_verilog;
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DartSyntaxHighlighter syntaxHighlighter;

  setUpAll(() async {
    syntaxHighlighter = await DartSyntaxHighlighter.load();
  });

  testWidgets('ROHD source uses rich Dart token styles', (tester) async {
    const source = r'''
/// Counts input pulses.
@immutable
class PulseCounter extends Module {
  final int width = 8;

  String label(bool enabled) => enabled ? 'count: $width' : 'off';
}
''';
    final controller = DartSyntaxCodeController(
      text: source,
      syntaxHighlighter: syntaxHighlighter,
    );
    addTearDown(controller.dispose);

    late TextSpan highlighted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            highlighted = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontFamily: 'monospace'),
              withComposing: false,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(highlighted.toPlainText(), source);

    final segments = _flatten(highlighted);
    final tokenColors = {
      _colorFor(segments, '/// Counts input pulses.'),
      _colorFor(segments, 'class'),
      _colorFor(segments, 'PulseCounter'),
      _colorFor(segments, 'label'),
      _colorFor(segments, '8'),
      _colorFor(segments, r"'count: $"),
    };

    expect(tokenColors, isNot(contains(null)));
    expect(
      tokenColors.length,
      greaterThanOrEqualTo(5),
      reason: 'Comments, keywords, types, functions, numbers, and strings '
          'should not collapse to the old basic styling.',
    );
  });

  testWidgets('ROHD source highlighting follows app brightness',
      (tester) async {
    const source = 'class Counter { String name = "counter"; }';
    final controller = DartSyntaxCodeController(
      text: source,
      syntaxHighlighter: syntaxHighlighter,
    );
    addTearDown(controller.dispose);

    Future<Color?> classColor(Brightness brightness) async {
      late TextSpan highlighted;
      await tester.pumpWidget(
        Theme(
          data: ThemeData(brightness: brightness),
          child: Builder(
            builder: (context) {
              highlighted = controller.buildTextSpan(
                context: context,
                withComposing: false,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return _colorFor(_flatten(highlighted), 'Counter');
    }

    final lightColor = await classColor(Brightness.light);
    final darkColor = await classColor(Brightness.dark);

    expect(lightColor, isNotNull);
    expect(darkColor, isNotNull);
    expect(darkColor, isNot(lightColor));
  });

  testWidgets('syntax colors do not change monospace layout', (tester) async {
    const source =
        '.rotate(RotateDirection.left, amount: 8, width: originalWidth)';
    final controller = DartSyntaxCodeController(
      text: source,
      syntaxHighlighter: syntaxHighlighter,
    );
    addTearDown(controller.dispose);

    const baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.5,
    );
    late TextSpan highlighted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            highlighted = controller.buildTextSpan(
              context: context,
              style: baseStyle,
              withComposing: false,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    final plainPainter = TextPainter(
      text: const TextSpan(text: source, style: baseStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final highlightedPainter = TextPainter(
      text: highlighted,
      textDirection: TextDirection.ltr,
    )..layout();

    expect(highlighted.toPlainText(), source);
    expect(highlightedPainter.width, plainPainter.width);
    expect(highlightedPainter.height, plainPainter.height);

    for (final child in highlighted.children ?? const <InlineSpan>[]) {
      final tokenStyle = child.style;
      expect(tokenStyle?.fontFamily, isNull);
      expect(tokenStyle?.fontSize, isNull);
      expect(tokenStyle?.fontWeight, isNull);
      expect(tokenStyle?.fontStyle, isNull);
      expect(tokenStyle?.letterSpacing, isNull);
      expect(tokenStyle?.wordSpacing, isNull);
      expect(tokenStyle?.height, isNull);
      expect(tokenStyle?.backgroundColor, isNull);
    }
  });

  testWidgets('modern TextField renders highlighted code without a bridge',
      (tester) async {
    final controller = HighlightCodeController(
      text: 'module counter;',
      languageName: 'verilog',
      language: highlight_verilog.verilog,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            readOnly: true,
            maxLines: null,
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('source line ranges update with generated text', () {
    final controller = HighlightCodeController(
      text: 'module counter;\nendmodule',
      languageName: 'verilog',
      language: highlight_verilog.verilog,
    );
    addTearDown(controller.dispose);

    expect(controller.lineCount, 2);
    expect(controller.lineRangeAt(1), const TextRange(start: 16, end: 25));

    controller.replaceSource('logic a;');

    expect(controller.lineCount, 1);
    expect(controller.lineRangeAt(0), const TextRange(start: 0, end: 8));
  });
}

List<({String text, TextStyle style})> _flatten(TextSpan root) {
  final segments = <({String text, TextStyle style})>[];

  void visit(TextSpan span, TextStyle inheritedStyle) {
    final style =
        span.style == null ? inheritedStyle : inheritedStyle.merge(span.style);
    final text = span.text;
    if (text != null && text.isNotEmpty) {
      segments.add((text: text, style: style));
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (child is TextSpan) {
        visit(child, style);
      }
    }
  }

  visit(root, const TextStyle());
  return segments;
}

Color? _colorFor(
  List<({String text, TextStyle style})> segments,
  String token,
) =>
    segments.firstWhere((segment) => segment.text.contains(token)).style.color;
