// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dart_syntax_code_controller.dart
// Syntax-highlighting controllers for read-only generated source.
//
// 2026 September 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:highlight/highlight_core.dart' show Highlight, Mode, Node;
import 'package:material_ui/material_ui.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

/// A text controller with source-line navigation support.
abstract class SyntaxCodeController extends TextEditingController {
  /// Creates a controller containing [text].
  SyntaxCodeController({required String text}) : super(text: text);

  late List<TextRange> _lineRanges = _computeLineRanges(text);

  /// The number of source lines.
  int get lineCount => _lineRanges.length;

  /// Returns the text range for zero-based [lineIndex].
  TextRange? lineRangeAt(int lineIndex) =>
      lineIndex >= 0 && lineIndex < _lineRanges.length
          ? _lineRanges[lineIndex]
          : null;

  /// Replaces the displayed source while keeping this controller attached.
  void replaceSource(String source) {
    if (source == text) {
      return;
    }

    _lineRanges = _computeLineRanges(source);
    value = TextEditingValue(text: source);
  }

  static List<TextRange> _computeLineRanges(String source) {
    final ranges = <TextRange>[];
    var start = 0;
    for (final match in '\n'.allMatches(source)) {
      ranges.add(TextRange(start: start, end: match.start));
      start = match.end;
    }
    ranges.add(TextRange(start: start, end: source.length));
    return ranges;
  }
}

/// Highlights source using a language from `package:highlight`.
class HighlightCodeController extends SyntaxCodeController {
  /// Creates a controller for [text] written in [language].
  HighlightCodeController({
    required String text,
    required String languageName,
    required Mode language,
  })  : _languageName = languageName,
        _language = language,
        super(text: text) {
    _highlighter.registerLanguage(_languageName, _language);
    _nodes = _parse(text);
  }

  final String _languageName;
  final Mode _language;
  final Highlight _highlighter = Highlight();
  late List<Node> _nodes;

  static const _lightStyles = <String, TextStyle>{
    'root': TextStyle(color: Color(0xFF333333)),
    'comment': TextStyle(color: Color(0xFF6A737D)),
    'quote': TextStyle(color: Color(0xFF6A737D)),
    'keyword': TextStyle(color: Color(0xFF005CC5)),
    'literal': TextStyle(color: Color(0xFF005CC5)),
    'type': TextStyle(color: Color(0xFF6F42C1)),
    'number': TextStyle(color: Color(0xFF005CC5)),
    'string': TextStyle(color: Color(0xFF032F62)),
    'title': TextStyle(color: Color(0xFF6F42C1)),
    'built_in': TextStyle(color: Color(0xFF005CC5)),
    'meta': TextStyle(color: Color(0xFF6A737D)),
    'variable': TextStyle(color: Color(0xFFE36209)),
    'attr': TextStyle(color: Color(0xFF22863A)),
  };

  static const _darkStyles = <String, TextStyle>{
    'root': TextStyle(color: Color(0xFFDCDCDC)),
    'comment': TextStyle(color: Color(0xFF6A9955)),
    'quote': TextStyle(color: Color(0xFF6A9955)),
    'keyword': TextStyle(color: Color(0xFF569CD6)),
    'literal': TextStyle(color: Color(0xFF569CD6)),
    'type': TextStyle(color: Color(0xFF4EC9B0)),
    'number': TextStyle(color: Color(0xFFB5CEA8)),
    'string': TextStyle(color: Color(0xFFCE9178)),
    'title': TextStyle(color: Color(0xFFDCDCAA)),
    'built_in': TextStyle(color: Color(0xFF4EC9B0)),
    'meta': TextStyle(color: Color(0xFF9B9B9B)),
    'variable': TextStyle(color: Color(0xFFC586C0)),
    'attr': TextStyle(color: Color(0xFF9CDCFE)),
  };

  List<Node> _parse(String source) =>
      _highlighter.parse(source, language: _languageName).nodes ??
      <Node>[Node(value: source)];

  @override
  void replaceSource(String source) {
    if (source == text) {
      return;
    }
    _nodes = _parse(source);
    super.replaceSource(source);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }) {
    final styles = Theme.of(context).brightness == Brightness.dark
        ? _darkStyles
        : _lightStyles;
    return TextSpan(
      style: (styles['root'] ?? const TextStyle()).merge(style),
      children: _convertNodes(_nodes, styles),
    );
  }

  static List<InlineSpan> _convertNodes(
    List<Node> nodes,
    Map<String, TextStyle> styles,
  ) =>
      [
        for (final node in nodes)
          TextSpan(
            text: node.value,
            style: node.className == null ? null : styles[node.className],
            children: node.children == null
                ? null
                : _convertNodes(node.children!, styles),
          ),
      ];
}

/// Loads and applies the TextMate grammar used for Dart source highlighting.
class DartSyntaxHighlighter {
  DartSyntaxHighlighter._({
    required Highlighter lightHighlighter,
    required Highlighter darkHighlighter,
  })  : _lightHighlighter = lightHighlighter,
        _darkHighlighter = darkHighlighter;

  static Future<DartSyntaxHighlighter>? _loadFuture;

  final Highlighter _lightHighlighter;
  final Highlighter _darkHighlighter;

  /// Loads the Dart grammar and the bundled light and dark themes once.
  static Future<DartSyntaxHighlighter> load() =>
      _loadFuture ??= _loadHighlighters();

  static Future<DartSyntaxHighlighter> _loadHighlighters() async {
    await Highlighter.initialize(['dart']);
    final themes = await Future.wait([
      HighlighterTheme.loadLightTheme(),
      HighlighterTheme.loadDarkTheme(),
    ]);

    return DartSyntaxHighlighter._(
      lightHighlighter: Highlighter(language: 'dart', theme: themes[0]),
      darkHighlighter: Highlighter(language: 'dart', theme: themes[1]),
    );
  }

  /// Highlights [source] for the requested display [brightness].
  TextSpan highlight(String source, Brightness brightness) {
    final highlighted = brightness == Brightness.dark
        ? _darkHighlighter.highlight(source)
        : _lightHighlighter.highlight(source);
    final flatSpans = <TextSpan>[];

    void flatten(TextSpan span, TextStyle inheritedStyle) {
      final effectiveStyle = inheritedStyle.merge(span.style);
      final text = span.text;
      if (text != null && text.isNotEmpty) {
        flatSpans.add(
          TextSpan(
            text: text,
            style: TextStyle(
              color: effectiveStyle.color,
              decoration: effectiveStyle.decoration,
              decorationColor: effectiveStyle.decorationColor,
              decorationStyle: effectiveStyle.decorationStyle,
              decorationThickness: effectiveStyle.decorationThickness,
            ),
          ),
        );
      }

      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is! TextSpan) {
          throw StateError(
            'Dart syntax highlighting produced a non-text inline span.',
          );
        }
        flatten(child, effectiveStyle);
      }
    }

    flatten(highlighted, const TextStyle());
    return TextSpan(children: flatSpans);
  }
}

/// A read-only controller backed by the Dart TextMate grammar.
class DartSyntaxCodeController extends SyntaxCodeController {
  /// Creates a controller for [text] using [syntaxHighlighter].
  DartSyntaxCodeController({
    required super.text,
    required DartSyntaxHighlighter syntaxHighlighter,
  }) : _syntaxHighlighter = syntaxHighlighter;

  final DartSyntaxHighlighter _syntaxHighlighter;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }) =>
      TextSpan(
        style: style,
        children: [
          _syntaxHighlighter.highlight(
            text,
            Theme.of(context).brightness,
          ),
        ],
      );
}
