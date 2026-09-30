// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// main.dart
// Standalone web entry point for viewing generated ROHD schematic netlists.
//
// 2026 September 13
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:rohd_schematic_viewer/schematic_viewer.dart';
import 'package:schematic_viewer/browser_location.dart';

/// Loads schematic JSON from [uri].
typedef SchematicJsonLoader = Future<String> Function(Uri uri);

/// Builds the rendered schematic after its JSON has been loaded and validated.
typedef SchematicContentBuilder = Widget Function(
  BuildContext context,
  String schematicJson,
  SchematicThemeMode themeMode,
);

/// Runs the standalone schematic viewer application.
void main() {
  runApp(const SchematicViewerApp());
}

/// The root application for the standalone schematic viewer.
class SchematicViewerApp extends StatelessWidget {
  /// Creates the standalone schematic viewer application.
  const SchematicViewerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ROHD Schematic',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: const SchematicPage(),
      );
}

/// Loads and displays the schematic selected by the `json` query parameter.
class SchematicPage extends StatefulWidget {
  /// Creates a page for the selected schematic.
  const SchematicPage({
    this.location,
    this.loadJson,
    this.schematicBuilder,
    super.key,
  });

  /// Page location containing the `json` query parameter.
  ///
  /// Defaults to the current browser location.
  final Uri? location;

  /// Loads the selected schematic JSON.
  ///
  /// Defaults to an HTTP read.
  final SchematicJsonLoader? loadJson;

  /// Builds the schematic content after a successful load.
  ///
  /// Defaults to [EmbeddedSchematicViewer].
  final SchematicContentBuilder? schematicBuilder;

  @override
  State<SchematicPage> createState() => _SchematicPageState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Uri>('location', location))
      ..add(ObjectFlagProperty<SchematicJsonLoader>.has('loadJson', loadJson))
      ..add(
        ObjectFlagProperty<SchematicContentBuilder>.has(
          'schematicBuilder',
          schematicBuilder,
        ),
      );
  }
}

class _SchematicPageState extends State<SchematicPage> {
  String? _jsonData;
  String? _error;
  String _title = 'ROHD Schematic';

  @override
  void initState() {
    super.initState();
    unawaited(_loadSchematic());
  }

  Future<void> _loadSchematic() async {
    final location = widget.location ?? currentBrowserLocation();
    final jsonPath = location.queryParameters['json'];
    if (jsonPath == null || jsonPath.isEmpty) {
      setState(() {
        _error = 'No schematic specified. '
            'Use ?json=../schematics/ComponentName.rohd.json';
      });
      return;
    }

    final filename = jsonPath.split('/').last.replaceAll('.rohd.json', '');
    setState(() {
      _title = filename;
    });

    try {
      final loader = widget.loadJson ?? http.read;
      final response = await loader(location.resolve(jsonPath));
      final decoded = jsonDecode(response);
      if (decoded is! Map) {
        throw const FormatException(
          'Schematic JSON must contain an object.',
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _jsonData = response;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to load $jsonPath: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(_title), toolbarHeight: 36),
      body: switch ((_error, _jsonData)) {
        (final error?, _) => Center(
            child: Text(error, style: const TextStyle(fontSize: 16)),
          ),
        (_, final jsonData?) => (widget.schematicBuilder ??
              (
                context,
                schematicJson,
                themeMode,
              ) =>
                  EmbeddedSchematicViewer(
                    schematicJson: schematicJson,
                    initialThemeMode: themeMode,
                  ))(
            context,
            jsonData,
            isDark ? SchematicThemeMode.dark : SchematicThemeMode.light,
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
