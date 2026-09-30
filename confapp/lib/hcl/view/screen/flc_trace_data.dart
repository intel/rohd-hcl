// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// flc_trace_data.dart
// Reads source trace data embedded in a ROHD netlist.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';

import 'package:rohd_source_navigator/flc_data.dart';

/// Returns source trace data embedded in [netlistJson], when present.
///
/// ROHD 0.6.11 does not emit `rohd.src_trace` attributes. Trace-enabled future
/// ROHD releases can provide them without requiring a Confapp API change.
FlcData? embeddedFlcDataFromNetlistJson(String netlistJson) {
  final decoded = jsonDecode(netlistJson);
  if (decoded is! Map) {
    throw const FormatException('ROHD netlist JSON must contain an object.');
  }

  final flcData = FlcData.fromNetlistJson(
    Map<String, dynamic>.from(decoded),
  );
  return flcData.isEmpty ? null : flcData;
}

/// Adapts [FlcData] to the source-query contract used by schematic viewer
/// 0.2.0.
class EmbeddedFlcSourceNavigation {
  /// Creates source navigation backed by [flcData].
  const EmbeddedFlcSourceNavigation(
    this.flcData, {
    this.primaryModule,
  });

  /// Parsed embedded source trace data, if the netlist supplied any.
  final FlcData? flcData;

  /// Definition name to use when the viewer reports an instance-based name.
  final String? primaryModule;

  /// Whether this trace can receive schematic cross-probe selections.
  bool get isAvailable => flcData != null && !flcData!.isEmpty;

  /// Returns source format identifiers available for [module].
  Set<String> formatsForModule(
    String module, {
    List<String>? instancePath,
  }) {
    var formats = _formatsForModule(module);
    if (formats.isNotEmpty) {
      return formats;
    }

    if (instancePath != null) {
      final instanceName = instancePath.lastWhere(
        (segment) => segment.isNotEmpty,
        orElse: () => '',
      );
      if (instanceName.isNotEmpty && instanceName != module) {
        formats = _formatsForModule(instanceName);
        if (formats.isNotEmpty) {
          return formats;
        }
      }
    }

    final fallbackModule = primaryModule;
    if (fallbackModule != null && fallbackModule != module) {
      return _formatsForModule(fallbackModule);
    }

    return const {};
  }

  /// Returns source frames for schematic [signals], optionally filtered by
  /// [format].
  List<Map<String, dynamic>> lookupSignalFrames({
    required List<Map<String, String>> signals,
    String? format,
  }) {
    final data = flcData;
    if (data == null) {
      return const [];
    }

    final frames = <Map<String, dynamic>>[];
    for (final signal in signals) {
      final requestedModule = signal['module'];
      final name = signal['name'];
      if (name == null) {
        continue;
      }

      FlcEntry? entry;
      if (requestedModule != null && requestedModule.isNotEmpty) {
        entry = data.lookupSignalEntry(requestedModule, name) ??
            data.lookupInstanceEntry(requestedModule, name);
      }
      final fallbackModule = primaryModule;
      if (entry == null && fallbackModule != null) {
        entry = data.lookupSignalEntry(fallbackModule, name) ??
            data.lookupInstanceEntry(fallbackModule, name);
      }
      if (entry == null) {
        continue;
      }
      frames.addAll(_sourceFrameMaps(entry, signalName: name));
    }

    if (format == null) {
      return frames;
    }
    return frames.where((frame) => frame['type'] == format).toList();
  }

  Set<String> _formatsForModule(String moduleName) {
    final data = flcData;
    if (data == null) {
      return const {};
    }

    final formats = <String>{};

    void addEntryFormats(FlcEntry? entry) {
      if (entry == null) {
        return;
      }
      if (entry.frames.isNotEmpty) {
        formats.add('rohd');
      }
      for (final outputFrame in entry.outputFrames) {
        if (outputFrame.type.isNotEmpty) {
          formats.add(outputFrame.type);
        }
      }
    }

    for (final signal in data.signalNamesFor(moduleName)) {
      addEntryFormats(data.lookupSignalEntry(moduleName, signal));
    }
    for (final instance in data.instanceNamesFor(moduleName)) {
      addEntryFormats(data.lookupInstanceEntry(moduleName, instance));
    }
    return formats;
  }

  static List<Map<String, dynamic>> _sourceFrameMaps(
    FlcEntry entry, {
    required String signalName,
  }) => [
        for (final frame in entry.frames.reversed)
          _sourceFrameMap(frame, signalName),
        for (final frame in entry.outputFrames)
          _sourceFrameMap(frame, signalName),
      ];

  static Map<String, dynamic> _sourceFrameMap(
    FlcFrame frame,
    String signalName,
  ) =>
      {
        'file': frame.file,
        'line': frame.line,
        'col': frame.column,
        'desc': signalName,
        'type': frame.type,
      };
}
