// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// main.dart
// Standalone web entry point for viewing generated ROHD schematic netlists.
//
// 2026 September 13
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rohd_schematic_viewer/schematic_viewer.dart';
import 'package:web/web.dart' as web;

void main() {
  runApp(const SchematicViewerApp());
}

class SchematicViewerApp extends StatelessWidget {
  const SchematicViewerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ROHD Schematic',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: const SchematicPage(),
      );
}

class SchematicPage extends StatefulWidget {
  const SchematicPage({super.key});

  @override
  State<SchematicPage> createState() => _SchematicPageState();
}

class _SchematicPageState extends State<SchematicPage> {
  String? _jsonData;
  String? _error;
  String _title = 'ROHD Schematic';

  @override
  void initState() {
    super.initState();
    _loadSchematic();
  }

  Future<void> _loadSchematic() async {
    final jsonPath =
        Uri.parse(web.window.location.href).queryParameters['json'];
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
      final response = await http.read(Uri.base.resolve(jsonPath));
      jsonDecode(response);
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
        (_, final jsonData?) => EmbeddedSchematicViewer(
            schematicJson: jsonData,
            initialThemeMode:
                isDark ? SchematicThemeMode.dark : SchematicThemeMode.light,
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
