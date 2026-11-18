// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// flc_trace_data.dart
// Reads source trace data embedded in a ROHD netlist.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:confapp/hcl/view/screen/browser_interop.dart'
    show loadCompiledSourceMap;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:rohd/rohd.dart'
    show
        DefinitionGenerationType,
        Module,
        SourceTracer,
        SystemVerilog,
        SystemVerilogService,
        TraceService;
// ROHD's public trace picker takes this type but does not export its
// constructor.
// ignore: implementation_imports
import 'package:rohd/src/synthesizers/utilities/synth_module_definition.dart';
import 'package:rohd_source_navigator/flc_data.dart';
import 'package:source_maps/source_maps.dart' as source_maps;

/// Generates source navigation for Confapp's bundled HCL sources.
///
/// The root is a logical namespace, not a filesystem directory. Explicit
/// package resolution avoids dart:io, while retaining the lib/src paths that
/// Confapp maps to its assets/rohd_src bundle. The same SV service supplies
/// both displayed text and file-global output positions.
Map<String, Object>? bundledSourceTrace(SystemVerilogService svService) {
  final rootTrace = SourceTracer.moduleTrace(svService.module);
  if (rootTrace != null && parseWasmStackFrames(rootTrace).isNotEmpty) {
    return _wasmSourceTrace(svService);
  }
  final trace = TraceService(
    svService.module,
    svService: svService,
    packageRoot: '/rohd_hcl',
    register: false,
  ).singleFileFlcHierarchy(
    '${svService.module.definitionName}.sv',
    packageMap: const {'rohd_hcl': '/rohd_hcl/lib'},
  );
  if (trace != null &&
      (trace['files']! as List).cast<String>().any(_isCompiledJavaScript)) {
    _restoreCompiledStacks(trace, svService);
  }
  return trace;
}

// ROHD's FLC encoder does not recognize Wasm stack frames and consequently
// drops their SV positions as well. Preserve both until the map is loaded.
Map<String, Object> _wasmSourceTrace(SystemVerilogService svService) {
  final files = <String>[];
  final indices = <String, int>{};
  final modules = <String, Object>{};
  final service = TraceService(svService.module,
      svService: svService, packageRoot: '/rohd_hcl', register: false);
  final positions = service.singleFileSvLineMapsByModule;

  List<String> framesFor(String? raw) {
    final frames = <String>[];
    for (final (file, offset) in parseWasmStackFrames(raw ?? '')) {
      final index = indices.putIfAbsent(file, () {
        files.add(file);
        return files.length - 1;
      });
      frames.add('$index:1:${offset + 1}');
    }
    return frames;
  }

  void collect(Module module) {
    final name = svService.synthBuilder.moduleInstanceTypes[module] ??
        module.definitionName;
    final modulePositions = positions[module] ?? const <String, List<String>>{};
    final moduleData = modules.putIfAbsent(
      name,
      () => <String, Object>{
        'outputFiles': {
          'sv': ['${svService.module.definitionName}.sv'],
        },
        'tree': <Object>[],
      },
    ) as Map<String, Object>;
    final tree = moduleData['tree']! as List<Object>;

    void add(String symbol, String? raw, {bool instance = false}) {
      final frames = framesFor(raw);
      final output = modulePositions[symbol];
      if (frames.isEmpty && (output == null || output.isEmpty)) {
        return;
      }
      final encoded = '${instance ? '*' : ''}$symbol'
          '${output == null ? '' : '@${output.map((p) => 'sv:$p').join(';')}'}';
      final reversed = (frames.isEmpty ? ['-1:1:1'] : frames).reversed;
      var branch = <dynamic>[reversed.first, encoded];
      for (final frame in reversed.skip(1)) {
        branch = <dynamic>[frame, branch];
      }
      tree.add(branch);
    }

    if (module is SystemVerilog &&
        module.generatedDefinitionType == DefinitionGenerationType.none) {
      for (final signal in module.signals) {
        add(signal.name, SourceTracer.signalTrace(signal));
      }
    } else {
      final definition = SynthModuleDefinition(module);
      final sources = SourceTracer.synthLogicSourceMap(module, definition);
      for (final signal in [
        ...definition.inputs,
        ...definition.outputs,
        ...definition.inOuts,
        ...definition.internalSignals,
      ]) {
        add(
            signal.name,
            SourceTracer.synthLogicTrace(module, signal,
                sourceLogics: sources));
      }
    }
    for (final child in module.subModules) {
      add(child.uniqueInstanceName, SourceTracer.moduleTrace(child),
          instance: true);
      collect(child);
    }
  }

  collect(svService.module);
  return {'version': 6, 'files': files, 'modules': modules};
}

// ROHD's FLC root-boundary heuristic can mistake an inherited method for the
// module constructor in dart2js stacks. Recover the already-captured raw
// stacks before resolving their JavaScript locations through the source map.
void _restoreCompiledStacks(
  Map<String, Object> trace,
  SystemVerilogService svService,
) {
  final traces = <String, Map<String, String>>{};

  void collect(Module module) {
    final name = svService.synthBuilder.moduleInstanceTypes[module] ??
        module.definitionName;
    final entries = traces.putIfAbsent(name, () => {});
    if (module is SystemVerilog &&
        module.generatedDefinitionType == DefinitionGenerationType.none) {
      for (final signal in module.signals) {
        final raw = SourceTracer.signalTrace(signal);
        if (raw != null) {
          entries[signal.name] = raw;
        }
      }
    } else {
      final definition = SynthModuleDefinition(module);
      final sources = SourceTracer.synthLogicSourceMap(module, definition);
      for (final signal in [
        ...definition.inputs,
        ...definition.outputs,
        ...definition.inOuts,
        ...definition.internalSignals,
      ]) {
        final raw =
            SourceTracer.synthLogicTrace(module, signal, sourceLogics: sources);
        if (raw != null) {
          entries[signal.name] = raw;
        }
      }
    }
    for (final child in module.subModules) {
      final raw = SourceTracer.moduleTrace(child);
      if (raw != null) {
        entries['*${child.uniqueInstanceName}'] = raw;
      }
      collect(child);
    }
  }

  collect(svService.module);
  restoreCompiledTraceFrames(trace, traces);
}

/// Restores captured JavaScript stacks to FLC leaves before source mapping.
@visibleForTesting
void restoreCompiledTraceFrames(
  Map<String, Object> trace,
  Map<String, Map<String, String>> traces,
) {
  final files = (trace['files']! as List).cast<String>();
  final indices = <String, int>{
    for (var i = 0; i < files.length; i++) files[i]: i,
  };
  List<String> encode(String raw) {
    final frames = <String>[];
    for (final line in raw.split('\n')) {
      final match = SourceTracer.v8FrameRe.firstMatch(line);
      final anonymous =
          match == null ? _anonymousV8Frame.firstMatch(line) : null;
      if (match == null && anonymous == null) {
        continue;
      }
      final file = match?.group(2) ?? anonymous!.group(1)!;
      final index = indices.putIfAbsent(file, () {
        files.add(file);
        return files.length - 1;
      });
      final row = match?.group(3) ?? anonymous!.group(2)!;
      final column = match?.group(4) ?? anonymous?.group(3) ?? '1';
      frames.add('$index:$row:$column');
    }
    return frames.reversed.toList();
  }

  final modules = trace['modules']! as Map;
  for (final entry in modules.entries) {
    final module = entry.value as Map;
    final tree = module['tree'] as List?;
    final moduleTraces = traces[entry.key];
    if (tree == null || moduleTraces == null) {
      continue;
    }
    final replacement = <List<dynamic>>[];
    void walk(List<dynamic> node, List<String> path) {
      final current = [...path, node.first as String];
      for (final child in node.skip(1)) {
        if (child is List) {
          walk(child, current);
        } else if (child is String) {
          final delimiter = child.indexOf(RegExp('[@~]'));
          final symbol = delimiter < 0 ? child : child.substring(0, delimiter);
          final raw = moduleTraces[symbol];
          final frames = raw == null ? current : encode(raw);
          final reversed = (frames.isEmpty ? current : frames).reversed;
          var branch = <dynamic>[reversed.first, child];
          for (final frame in reversed.skip(1)) {
            branch = <dynamic>[frame, branch];
          }
          replacement.add(branch);
        }
      }
    }

    for (final node in tree) {
      walk(node as List<dynamic>, []);
    }
    module['tree'] = replacement;
  }
}

final _sourceMaps = <String, Future<source_maps.Mapping>>{};
final _anonymousV8Frame = RegExp(r'^\s*at\s+(.+):(\d+):(\d+)\s*$');
final _wasmFrame = RegExp(
    r'^\s*at\s+.*?\(([^()\s]+\.wasm(?:\?[^()\s]*)?):'
    r'wasm-function\[\d+\]:0x([0-9a-fA-F]+)\)',
    multiLine: true);

/// Extracts Wasm file URLs and byte offsets from V8 stack frames.
@visibleForTesting
List<(String, int)> parseWasmStackFrames(String raw) => [
      for (final match in _wasmFrame.allMatches(raw))
        (match.group(1)!, int.parse(match.group(2)!, radix: 16)),
    ];

source_maps.Mapping _parseSourceMap(String file, String source) {
  try {
    return source_maps.parse(source);
  } on Object catch (error) {
    throw FormatException('Invalid source map for $file: $error');
  }
}

Future<source_maps.Mapping> _loadMapping(String file) =>
    _sourceMaps.putIfAbsent(file, () async {
      try {
        return _parseSourceMap(file, await loadCompiledSourceMap(file));
      } on Object {
        unawaited(_sourceMaps.remove(file));
        rethrow;
      }
    });

bool _isCompiledJavaScript(String file) {
  final path = Uri.tryParse(file)?.path ?? file;
  final name = path.split('/').last;
  return name == 'main.js' ||
      name == 'main.dart.js' ||
      RegExp(r'^main\.dart\.js_.*\.part\.js$').hasMatch(name);
}

bool _isCompiledWasm(String file) =>
    (Uri.tryParse(file)?.path ?? file).endsWith('.wasm');

String? _wasmSourceRoot(source_maps.Mapping map) {
  if (map is! source_maps.SingleMapping) {
    throw const FormatException('Unsupported Wasm source map structure.');
  }
  // This registry is always included in Confapp and identifies the package
  // root without assuming the checkout directory's name.
  const suffix = '/lib/src/component_config/components/component_registry.dart';
  for (final source in map.urls) {
    final uri = Uri.tryParse('${map.sourceRoot ?? ''}$source');
    final path = uri?.path;
    if (path != null && path.endsWith(suffix)) {
      return path.substring(0, path.length - suffix.length);
    }
  }
  if (map.urls.any((source) => source.startsWith('package:rohd_hcl/src/'))) {
    return null;
  }
  throw const FormatException(
    'Wasm source map does not identify the ROHD-HCL source root.',
  );
}

String? _bundledDartPath(Uri? uri, {String? wasmSourceRoot}) {
  if (uri == null) {
    return null;
  }
  final path = uri.toString();
  const packagePrefix = 'package:rohd_hcl/src/';
  if (path.startsWith(packagePrefix)) {
    return 'lib/src/${path.substring(packagePrefix.length)}';
  }
  if (uri.scheme == 'file' &&
      wasmSourceRoot != null &&
      uri.path.startsWith('$wasmSourceRoot/lib/src/')) {
    return uri.path.substring(wasmSourceRoot.length + 1);
  }
  final relative = RegExp(r'^(?:\.\./)+lib/src/(.+\.dart)$').firstMatch(path);
  return relative == null ? null : 'lib/src/${relative.group(1)}';
}

/// Resolves compiled JavaScript or Wasm frames before exposing navigation.
///
/// Unmapped JavaScript frames are omitted, while their generated output
/// positions and any mapped ancestors remain available.
Future<FlcData?> decodeBundledSourceTrace(
  Map<String, Object>? trace, {
  Future<String> Function(String file)? loadSourceMap,
}) async {
  if (trace == null) {
    return null;
  }
  final files = (trace['files']! as List).cast<String>().toList();
  final maps = <int, source_maps.Mapping>{};
  for (var i = 0; i < files.length; i++) {
    if (_isCompiledJavaScript(files[i]) || _isCompiledWasm(files[i])) {
      maps[i] = loadSourceMap == null
          ? await _loadMapping(files[i])
          : _parseSourceMap(files[i], await loadSourceMap(files[i]));
    }
  }

  if (maps.isNotEmpty) {
    final wasmRoots = <int, String?>{
      for (final entry in maps.entries)
        if (_isCompiledWasm(files[entry.key]))
          entry.key: _wasmSourceRoot(entry.value),
    };
    final indices = <String, int>{
      for (var i = 0; i < files.length; i++) files[i]: i,
    };
    String translate(String frame) {
      final parts = frame.split(':');
      final index = int.parse(parts[0]);
      final map = maps[index];
      if (map == null) {
        return frame;
      }
      final line = int.parse(parts[1]);
      final column = parts.length > 2 ? int.parse(parts[2]) : 1;
      if (line < 1 || column < 1) {
        return '-1:1:1';
      }
      final location = map.spanFor(line - 1, column - 1)?.start;
      final path = _bundledDartPath(
        location?.sourceUrl,
        wasmSourceRoot: wasmRoots[index],
      );
      if (path == null || location == null) {
        return '-1:1:1';
      }
      final fileIndex = indices.putIfAbsent(path, () {
        files.add(path);
        return files.length - 1;
      });
      return '$fileIndex:${location.line + 1}:${location.column + 1}';
    }

    void translateNode(List<dynamic> node) {
      node[0] = translate(node[0] as String);
      for (final child in node.skip(1)) {
        if (child is List) {
          translateNode(child);
        }
      }
    }

    final modules = trace['modules']! as Map;
    for (final module in modules.values) {
      final tree = (module as Map)['tree'] as List?;
      if (tree != null) {
        for (final node in tree) {
          translateNode(node as List<dynamic>);
        }
      }
    }
  }
  final data = FlcData.fromJson({...trace, 'files': files});
  return data.isEmpty ? null : data;
}

/// Returns source trace data embedded in [netlistJson], when present.
///
/// ROHD emits `rohd.src_trace` attributes when source tracing is active during
/// module construction and netlist synthesis is configured to include traces.
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

/// Adapts [FlcData] to the schematic viewer's source-query contract.
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
  }) =>
      [
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
