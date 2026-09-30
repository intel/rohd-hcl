// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// schematic_page_test.dart
// Tests the standalone documentation schematic page.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:schematic_viewer/main.dart';

Widget _testApp({
  required Uri location,
  required SchematicJsonLoader loadJson,
  SchematicContentBuilder? schematicBuilder,
}) =>
    MaterialApp(
      home: SchematicPage(
        location: location,
        loadJson: loadJson,
        schematicBuilder: schematicBuilder ??
            (context, schematicJson, themeMode) =>
                Text('Rendered $schematicJson'),
      ),
    );

void main() {
  testWidgets('shows guidance when the json parameter is missing',
      (tester) async {
    var loadCount = 0;
    await tester.pumpWidget(
      _testApp(
        location: Uri.parse('https://example.com/viewer/'),
        loadJson: (uri) async {
          loadCount++;
          return '{}';
        },
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('No schematic specified.'),
      findsOneWidget,
    );
    expect(loadCount, 0);
  });

  testWidgets('loads and renders the selected schematic', (tester) async {
    final response = Completer<String>();
    Uri? requestedUri;
    const schematicJson = '{"modules":{"Example":{}}}';

    await tester.pumpWidget(
      _testApp(
        location: Uri.parse(
          'https://example.com/viewer/?json=../schematics/Example.rohd.json',
        ),
        loadJson: (uri) {
          requestedUri = uri;
          return response.future;
        },
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(schematicJson);
    await tester.pumpAndSettle();

    expect(
      requestedUri,
      Uri.parse('https://example.com/schematics/Example.rohd.json'),
    );
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('Rendered $schematicJson'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an error for malformed JSON', (tester) async {
    await tester.pumpWidget(
      _testApp(
        location: Uri.parse(
          'https://example.com/viewer/?json=broken.rohd.json',
        ),
        loadJson: (uri) async => '{not json',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load broken.rohd.json:'),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsOneWidget);
    expect(find.textContaining('Rendered'), findsNothing);
  });

  testWidgets('shows an error when the HTTP load fails', (tester) async {
    await tester.pumpWidget(
      _testApp(
        location: Uri.parse(
          'https://example.com/viewer/?json=missing.rohd.json',
        ),
        loadJson: (uri) async => throw http.ClientException(
          'HTTP 404',
          uri,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load missing.rohd.json:'),
      findsOneWidget,
    );
    expect(find.textContaining('HTTP 404'), findsOneWidget);
    expect(find.textContaining('Rendered'), findsNothing);
  });
}
