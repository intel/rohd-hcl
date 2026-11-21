// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// flc_trace_data_test.dart
// Tests source trace data embedded in ROHD netlists.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';

import 'package:confapp/hcl/view/screen/flc_trace_data.dart';
import 'package:rohd/rohd.dart'
    show
        Const,
        Logic,
        Module,
        NetlistSynthesizer,
        Simulator,
        SourceTracer,
        SystemVerilogService;
import 'package:rohd_hcl/rohd_hcl.dart'
    show
        CompoundAdderConfigurator,
        Compressor4Configurator,
        SerializationConfigurator;
import 'package:rohd_hcl/src/arithmetic/addition/adder.dart' show NativeAdder;
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';
import 'package:rohd_schematic_viewer/schematic_connectivity.dart';
import 'package:rohd_source_navigator/flc_data.dart';
import 'package:test/test.dart';

class _AdderWrapper extends Module {
  _AdderWrapper() {
    final a = addInput('a', Const(0, width: 2), width: 2);
    final b = addInput('b', Const(0, width: 2), width: 2);
    final first = NativeAdder(a, b);
    final second = NativeAdder(first.sum, Const(1, width: first.sum.width));
    addOutput('sum', width: second.sum.width) <= second.sum;
  }
}

void main() {
  test('maps HCL traces to bundled sources and displayed SV without IO',
      () async {
    final tracer = SourceTracer.activate();
    try {
      final module = NativeAdder(Logic(), Logic());
      await module.build();
      final svService = SystemVerilogService(module, register: false);
      final svText = svService.output;
      final flcData =
          await decodeBundledSourceTrace(bundledSourceTrace(svService));
      final netlistJson = NetlistSynthesizer().synthesizeToJson(module);

      expect(embeddedFlcDataFromNetlistJson(netlistJson), isNull);
      expect(flcData, isNotNull);
      expect(flcData!.isEmpty, isFalse);
      expect(flcData.files, contains('lib/src/arithmetic/addition/adder.dart'));
      final entry = flcData.lookupSignalEntry(module.definitionName, 'sum');
      expect(entry, isNotNull);
      expect(
        entry!.frames.where(
          (frame) => frame.file == 'lib/src/arithmetic/addition/adder.dart',
        ),
        isNotEmpty,
      );
      expect(entry.svFrame, isNotNull);
      expect(
        svText.split('\n')[entry.svFrame!.line - 1],
        contains('sum'),
      );
      final navigation = EmbeddedFlcSourceNavigation(
        flcData,
        primaryModule: module.definitionName,
      );
      expect(navigation.isAvailable, isTrue);
      expect(
          navigation.formatsForModule(module.definitionName), {'rohd', 'sv'});
    } finally {
      SourceTracer.clearIfCurrent(tracer);
    }
  });

  test('generated Serializer input connectivity and names match its FLC',
      () async {
    final tracer = SourceTracer.activate();
    try {
      final module = SerializationConfigurator().createModule();
      await module.build();
      final svService = SystemVerilogService(module, register: false);
      final data =
          (await decodeBundledSourceTrace(bundledSourceTrace(svService)))!;
      final netlistJson = NetlistSynthesizer().synthesizeToJson(module);
      final netlist = jsonDecode(netlistJson) as Map<String, dynamic>;
      final definitions = netlist['modules'] as Map<String, dynamic>;
      final definition =
          definitions[module.definitionName] as Map<String, dynamic>;
      final ports = definition['ports'] as Map<String, dynamic>;
      final netnames = definition['netnames'] as Map<String, dynamic>;
      final inputBits =
          (ports['deserialized'] as Map<String, dynamic>)['bits'] as List;
      expect((netnames['dataOutput'] as Map<String, dynamic>)['bits'],
          orderedEquals(inputBits));
      final slices = (definition['cells'] as Map<String, dynamic>)
          .values
          .cast<Map<String, dynamic>>()
          .where((cell) => cell['synthetic_origin'] == 'arraySlice');
      expect(slices, isNotEmpty);
      for (final slice in slices) {
        expect((slice['connections'] as Map<String, dynamic>)['A'],
            orderedEquals(inputBits));
      }
      final schematic = NetlistSchematicConnectivity.fromJson(netlistJson);
      final input = schematic.hierarchy.root.signals
          .singleWhere((signal) => signal.name == 'deserialized');
      expect(
        schematic.fanout(input).map((endpoint) => endpoint.nodePath),
        contains(endsWith('/array_slice')),
      );
      final navigation = EmbeddedFlcSourceNavigation(
        data,
        primaryModule: module.definitionName,
      );

      final entry =
          navigation.lookupEntry(module.definitionName, 'dataOutput')!;
      expect(navigation.lookupEntry(module.definitionName, 'deserialized'),
          isNotNull);
      expect(
        entry.frames.map((frame) => frame.file),
        contains('lib/src/dataflow/serialization/serializer.dart'),
      );
      expect(entry.svFrame, isNotNull);
      expect(
        svService.output.split('\n')[entry.svFrame!.line - 1],
        contains('dataOutput'),
      );
      const elementName = 'dataOutput[0]';
      expect(netnames, contains(elementName));
      expect(
        schematic.hierarchy.root.signals.map((signal) => signal.name),
        contains(elementName),
      );
      final element =
          navigation.lookupEntry(module.definitionName, elementName);
      expect(element, isNotNull);
      expect(element!.frames, isNotEmpty);
      expect(element.svFrame, isNotNull);
      expect(
        svService.output.split('\n')[element.svFrame!.line - 1],
        contains(elementName),
      );
    } finally {
      SourceTracer.clearIfCurrent(tracer);
    }
  },
      // The fix is not yet available in the released ROHD dependency.
      // ignore: do_not_use_environment
      skip: !const bool.fromEnvironment('ROHD_LOCAL_NETLIST_TEST')
          ? 'ROHD release with corrected array connectivity is required'
          : false);

  test('Serializer slices reach the selector without dangling concats',
      () async {
    for (final flopped in [false, true]) {
      final config = SerializationConfigurator();
      config.flopInputKnob.value = flopped;
      final module = config.createModule();
      await module.build();
      final netlist = jsonDecode(NetlistSynthesizer().synthesizeToJson(module))
          as Map<String, dynamic>;
      final definition =
          (netlist['modules'] as Map<String, dynamic>)[module.definitionName]
              as Map<String, dynamic>;
      final ports = definition['ports'] as Map<String, dynamic>;
      final cells = (definition['cells'] as Map<String, dynamic>)
          .values
          .cast<Map<String, dynamic>>()
          .toList();
      final input = (ports['deserialized'] as Map<String, dynamic>)['bits']
          as List<dynamic>;
      final slices = cells
          .where((cell) => cell['synthetic_origin'] == 'arraySlice')
          .toList();
      final selector =
          cells.singleWhere((cell) => cell['type'] == 'Combinational');
      final selectorConnections =
          selector['connections'] as Map<String, dynamic>;

      expect(slices, hasLength(16), reason: 'flopped=$flopped');
      final offsets = <int>{};
      for (final slice in slices) {
        final parameters = slice['parameters'] as Map<String, dynamic>;
        final connections = slice['connections'] as Map<String, dynamic>;
        final offset = parameters['OFFSET'] as int;
        final index = offset ~/ 8;
        offsets.add(offset);
        expect(offset, index * 8);
        expect(connections['A'], orderedEquals(input));
        final output = connections['Y'] as List;
        final selectorInput = selectorConnections['dataOutput[$index]'] as List;
        if (flopped) {
          final flop = cells.singleWhere((cell) {
            final connections = cell['connections'] as Map<String, dynamic>;
            final d = connections['D'];
            return cell['type'] == r'$sdffe' &&
                d is List &&
                d.length == output.length &&
                d.indexed.every((entry) => entry.$2 == output[entry.$1]);
          });
          expect((flop['connections'] as Map<String, dynamic>)['Q'],
              orderedEquals(selectorInput));
        } else {
          expect(output, orderedEquals(selectorInput));
        }
      }
      expect(offsets, {for (var index = 0; index < 16; index++) index * 8});
      final outputConcat = cells.singleWhere(
          (cell) => cell['synthetic_origin'] == 'outputArrayConcat');
      final outputConnections =
          outputConcat['connections'] as Map<String, dynamic>;
      expect(outputConnections['[7:0]'],
          orderedEquals(selectorConnections['selectFrom'] as List));
      expect(
          outputConnections['Y'],
          orderedEquals(
              (ports['serialized'] as Map<String, dynamic>)['bits'] as List));
      expect(
        cells.where((cell) => cell['synthetic_origin'] == 'arrayConcat'),
        isEmpty,
        reason: 'Unconsumed array concat should be removed, flopped=$flopped',
      );
      final netnames = definition['netnames'] as Map<String, dynamic>;
      expect(netnames.containsKey('latchTheInput'), flopped);
      if (!flopped) {
        expect(cells.where((cell) => cell['type'] == r'$and'), isEmpty);
      }
      if (flopped) {
        final latchBits =
            (netnames['latchTheInput'] as Map<String, dynamic>)['bits'] as List;
        final latchDriver = cells.singleWhere((cell) {
          final connections = cell['connections'] as Map<String, dynamic>;
          final output = connections['Y'];
          return cell['type'] == r'$and' &&
              output is List &&
              output.length == latchBits.length &&
              output.indexed.every((entry) => entry.$2 == latchBits[entry.$1]);
        });
        final latchOutput =
            (latchDriver['connections'] as Map<String, dynamic>)['Y'] as List;
        final dataFlops = cells.where((cell) => cell['type'] == r'$sdffe');
        expect(dataFlops, hasLength(16));
        for (final flop in dataFlops) {
          expect((flop['connections'] as Map<String, dynamic>)['EN'],
              orderedEquals(latchOutput));
        }
      }
    }
  },
      // The fix is not yet available in the released ROHD dependency.
      // ignore: do_not_use_environment
      skip: !const bool.fromEnvironment('ROHD_LOCAL_NETLIST_TEST')
          ? 'ROHD release with corrected array connectivity is required'
          : false);

  test('inherited compound adder output retains source and SV trace', () async {
    final tracer = SourceTracer.activate();
    try {
      final module = CompoundAdderConfigurator().createModule();
      await module.build();
      final svService = SystemVerilogService(module, register: false);
      final data =
          (await decodeBundledSourceTrace(bundledSourceTrace(svService)))!;
      final entry = data.lookupSignalEntry(module.definitionName, 'sumP1');
      expect(entry, isNotNull);
      expect(
        entry!.frames.map((frame) => frame.file),
        contains('lib/src/arithmetic/addition/compound_adder.dart'),
      );
      expect(entry.svFrame, isNotNull);
      expect(
        svService.output.split('\n')[entry.svFrame!.line - 1],
        contains('sumP1'),
      );
    } finally {
      SourceTracer.clearIfCurrent(tracer);
    }
  },
      // The fix is not yet available in the released ROHD dependency.
      // ignore: do_not_use_environment
      skip: !const bool.fromEnvironment('ROHD_LOCAL_NETLIST_TEST')
          ? 'ROHD release with corrected source traces is required'
          : false);

  test('FLC retains generated locations without a Dart source frame', () async {
    final tracer = SourceTracer.activate();
    try {
      final module = _AdderWrapper();
      await module.build();
      final svService = SystemVerilogService(module, register: false);
      final data = FlcData.fromJson(SourceTracer.traceJsonForHierarchy(
        module,
        packageRoot: '/rohd_hcl',
        skipPatterns: [''],
        svLineMaps: svService.singleFileSvLineMaps,
        svFileMap: {module.definitionName: 'generated.sv'},
      )!);
      final entry = data.lookupSignalEntry(module.definitionName, 'sum');
      expect(entry, isNotNull);
      expect(entry!.frames, isEmpty);
      expect(entry.svFrame, isNotNull);
      expect(
        svService.output.split('\n')[entry.svFrame!.line - 1],
        contains('sum'),
      );
    } finally {
      SourceTracer.clearIfCurrent(tracer);
    }
  },
      // The fix is not yet available in the released ROHD dependency.
      // ignore: do_not_use_environment
      skip: !const bool.fromEnvironment('ROHD_LOCAL_NETLIST_TEST')
          ? 'ROHD release with output-only FLC entries is required'
          : false);

  test('FLC output locations handle multiline instance connections', () async {
    final tracer = SourceTracer.activate();
    try {
      final module = Compressor4Configurator().createModule();
      await module.build();
      final svService = SystemVerilogService(module, register: false);
      final data =
          (await decodeBundledSourceTrace(bundledSourceTrace(svService)))!;
      for (final name in ['sum', 'carry']) {
        final frame =
            data.lookupSignalEntry(module.definitionName, name)!.svFrame!;
        final line = svService.output.split('\n')[frame.line - 1];
        expect(line.substring(frame.column - 1), startsWith(name));
      }
    } finally {
      SourceTracer.clearIfCurrent(tracer);
    }
  },
      // The fix is not yet available in the released ROHD dependency.
      // ignore: do_not_use_environment
      skip: !const bool.fromEnvironment('ROHD_LOCAL_NETLIST_TEST')
          ? 'ROHD release with corrected FLC output positions is required'
          : false);

  test('default catalog netlist names and SV FLC positions agree', () async {
    for (final config in componentRegistry) {
      final tracer = SourceTracer.activate();
      try {
        final module = config.createModule();
        await module.build();
        final sv = SystemVerilogService(module, register: false);
        final data = (await decodeBundledSourceTrace(bundledSourceTrace(sv)))!;
        final netlist =
            jsonDecode(NetlistSynthesizer().synthesizeToJson(module)) as Map;
        final lines = sv.output.split('\n');
        final modules = netlist['modules'] as Map;
        for (final moduleEntry in modules.entries) {
          final moduleName = moduleEntry.key as String;
          final definition = moduleEntry.value as Map;
          final names = definition['netnames'] as Map;
          final canonicalNames = data.signalNamesFor(moduleName).toSet();
          for (final entry in names.entries) {
            final name = entry.key as String;
            final net = entry.value as Map;
            if (net['hide_name'] == 1 ||
                (net['attributes'] as Map?)?['computed'] == 1) {
              continue;
            }
            final context = '${config.name}: $moduleName/$name';
            expect(canonicalNames, contains(name), reason: context);
            final trace = data.lookupSignalEntry(moduleName, name)!;
            for (final frame
                in trace.outputFrames.where((frame) => frame.type == 'sv')) {
              expect(frame.line, inInclusiveRange(1, lines.length),
                  reason: context);
              final line = lines[frame.line - 1];
              expect(frame.column, inInclusiveRange(1, line.length),
                  reason: context);
              expect(line.substring(frame.column - 1), startsWith(name),
                  reason: context);
            }
          }
        }
      } finally {
        SourceTracer.clearIfCurrent(tracer);
        await Simulator.reset();
      }
    }
  },
      // The fix is not yet available in the released ROHD dependency.
      // ignore: do_not_use_environment
      skip: !const bool.fromEnvironment('ROHD_LOCAL_NETLIST_TEST')
          ? 'ROHD release with canonical FLC names is required'
          : false,
      timeout: const Timeout(Duration(minutes: 10)));

  test('source lookup stays scoped to its owning module', () {
    final data = FlcData.fromJson({
      'version': 5,
      'files': ['lib/src/example.dart'],
      'modules': {
        'Top': {
          'svFile': 'Top.sv',
          'tree': [
            ['0:1:1', 'shared@sv:2:1'],
            ['0:2:1', 'missing@sv:3:1'],
          ],
        },
        'Child': {
          'svFile': 'Top.sv',
          'tree': [
            ['0:3:1', 'shared@sv:4:1'],
          ],
        },
      },
    });
    final navigation = EmbeddedFlcSourceNavigation(
      data,
      primaryModule: 'Top',
    );
    expect(navigation.lookupEntry('Top', 'shared')!.svFrame!.line, 2);
    expect(navigation.lookupEntry('Child', 'shared')!.svFrame!.line, 4);
    expect(
      navigation.lookupSignalFrames(
        signals: const [
          {'module': 'Child', 'name': 'missing'},
        ],
      ),
      isEmpty,
    );
  });

  test('returns no generated trace when tracing was not activated', () async {
    final module = NativeAdder(Logic(), Logic());
    await module.build();
    expect(
      await decodeBundledSourceTrace(
        bundledSourceTrace(SystemVerilogService(module, register: false)),
      ),
      isNull,
    );
  });

  test('preserves nested HCL source paths and single-file SV positions',
      () async {
    final tracer = SourceTracer.activate();
    try {
      final module = _AdderWrapper();
      await module.build();
      final svService = SystemVerilogService(module, register: false);
      final svLines = svService.output.split('\n');
      final flcData =
          (await decodeBundledSourceTrace(bundledSourceTrace(svService)))!;

      expect(
        flcData.files,
        contains('lib/src/arithmetic/addition/adder.dart'),
      );
      expect(module.subModules.whereType<NativeAdder>(), hasLength(2));
      for (final child in module.subModules.whereType<NativeAdder>()) {
        final entry = flcData.lookupSignalEntry(child.definitionName, 'sum');
        expect(entry, isNotNull);
        expect(entry!.svFrame, isNotNull);
        expect(svLines[entry.svFrame!.line - 1], contains('sum'));
      }
    } finally {
      SourceTracer.clearIfCurrent(tracer);
    }
  });

  test('maps JavaScript frames to bundled Dart while preserving SV', () async {
    final trace = <String, Object>{
      'version': 5,
      'files': ['https://example.test/app/main.dart.js', 'lib/src/other.dart'],
      'modules': {
        'Example': {
          'svFile': 'Example.sv',
          'tree': [
            [
              '1:8:2',
              ['0:1:1', 'result@sv:8:3'],
              ['0:2:1', 'unmapped@sv:9:1'],
            ],
          ],
        },
      },
    };
    final flc = (await decodeBundledSourceTrace(
      trace,
      loadSourceMap: (file) async => jsonEncode({
        'version': 3,
        'sources': ['../../../../../lib/src/arithmetic/addition/adder.dart'],
        'names': <String>[],
        'mappings': 'AAUE;A',
      }),
    ))!;
    final result = flc.lookupSignalEntry('Example', 'result')!;
    expect(result.frames.first.file, 'lib/src/arithmetic/addition/adder.dart');
    expect(result.frames.first.line, 11);
    expect(result.frames.first.column, 3);
    expect(result.frames.last.file, 'lib/src/other.dart');
    expect(result.svFrame!.line, 8);
    final unmapped = flc.lookupSignalEntry('Example', 'unmapped')!;
    expect(unmapped.frames.map((frame) => frame.file), ['lib/src/other.dart']);
    expect(unmapped.svFrame!.line, 9);
  });

  test('extracts Wasm offsets after parenthesized function names', () {
    expect(
      parseWasmStackFrames('''
    at M (http://localhost/main.dart.wasm:wasm-function[12]:0x3fb21)
    at constructor body (http://localhost/main.dart.wasm:wasm-function[9]:0xab)
    at Foo (constructor body) (http://localhost/main.dart.wasm:wasm-function[5]:0x10)
    at helper (http://localhost/main.dart.mjs:5:4)
'''),
      [
        ('http://localhost/main.dart.wasm', 0x3fb21),
        ('http://localhost/main.dart.wasm', 0xab),
        ('http://localhost/main.dart.wasm', 0x10),
      ],
    );
  });

  test('maps Wasm byte offsets to bundled Dart and preserves SV', () async {
    final trace = <String, Object>{
      'version': 6,
      'files': ['https://example.test/main.dart.wasm'],
      'modules': {
        'Rotate': {
          'outputFiles': {
            'sv': ['Rotate.sv'],
          },
          'tree': [
            ['0:1:6', 'rotated@sv:8:3'],
            ['0:1:1', 'original@sv:9:3'],
          ],
        },
      },
    };
    final flc = (await decodeBundledSourceTrace(
      trace,
      loadSourceMap: (_) async => jsonEncode({
        'version': 3,
        'sources': [
          'file:///other/lib/src/bit_operations/shifting/rotate.dart',
          'file:///build/hcl/lib/src/bit_operations/shifting/rotate.dart',
          'file:///build/hcl/lib/src/component_config/components/component_registry.dart',
        ],
        'names': <String>[],
        'mappings': 'AAAA,KCUE',
      }),
    ))!;
    final entry = flc.lookupSignalEntry('Rotate', 'rotated')!;
    expect(entry.frames.single.file,
        'lib/src/bit_operations/shifting/rotate.dart');
    expect(entry.frames.single.line, 11);
    expect(entry.frames.single.column, 3);
    expect(entry.svFrame!.line, 8);
    final other = flc.lookupSignalEntry('Rotate', 'original')!;
    expect(other.frames, isEmpty);
    expect(other.svFrame!.line, 9);
    expect(
      EmbeddedFlcSourceNavigation(flc).formatsForModule('Rotate'),
      {'rohd', 'sv'},
    );
  });

  test('reports a Wasm source map without the HCL source root', () async {
    await expectLater(
      decodeBundledSourceTrace(
        <String, Object>{
          'version': 6,
          'files': ['main.dart.wasm'],
          'modules': <String, Object>{},
        },
        loadSourceMap: (_) async => jsonEncode({
          'version': 3,
          'sources': ['file:///other/lib/src/example.dart'],
          'names': <String>[],
          'mappings': 'AAAA',
        }),
      ),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains('ROHD-HCL source root'),
      )),
    );
  });

  test('recovers frames truncated at an inherited method in dart2js', () async {
    final trace = <String, Object>{
      'version': 6,
      'files': <String>['main.dart.js'],
      'modules': <String, Object>{
        'Adder': <String, Object>{
          'outputFiles': <String, Object>{
            'sv': ['Adder.sv'],
          },
          'tree': <Object>[
            <Object>['0:1:1', 'sum@sv:8:3'],
          ],
        },
      },
    };
    restoreCompiledTraceFrames(trace, {
      'Adder': {
        'sum': '''
    at NativeAdder.addOutput (main.dart.js:1:1)
    at main.dart.js:2:1
''',
      },
    });
    final flc = (await decodeBundledSourceTrace(
      trace,
      loadSourceMap: (_) async => jsonEncode({
        'version': 3,
        'sources': [
          'package:rohd/src/module.dart',
          '../../../../../lib/src/arithmetic/addition/adder.dart',
        ],
        'names': <String>[],
        'mappings': 'AAAA;ACUE',
      }),
    ))!;
    final entry = flc.lookupSignalEntry('Adder', 'sum')!;
    expect(entry.frames.single.file, 'lib/src/arithmetic/addition/adder.dart');
    expect(entry.frames.single.line, 11);
    expect(entry.frames.single.column, 3);
    expect(entry.svFrame!.line, 8);
    expect(
      EmbeddedFlcSourceNavigation(flc).lookupSignalFrames(
        signals: const [
          {'module': 'Adder', 'name': 'sum'},
        ],
        format: 'rohd',
      ),
      [
        {
          'file': 'lib/src/arithmetic/addition/adder.dart',
          'line': 11,
          'col': 3,
          'desc': 'sum',
          'type': 'rohd',
        },
      ],
    );
  });

  test('reports missing JavaScript source maps', () async {
    final trace = <String, Object>{
      'version': 5,
      'files': ['main.dart.js'],
      'modules': <String, Object>{},
    };
    await expectLater(
      decodeBundledSourceTrace(
        trace,
        loadSourceMap: (_) async =>
            throw const FormatException('map unavailable'),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      decodeBundledSourceTrace(trace, loadSourceMap: (_) async => '<html>'),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains('Invalid source map for main.dart.js'),
      )),
    );
  });

  test('returns source trace data embedded in a netlist', () {
    final flcData = embeddedFlcDataFromNetlistJson(
      jsonEncode({
        'files': ['lib/src/example.dart'],
        'modules': {
          'Example': {
            'attributes': {
              'rohd.src_trace': {
                'signals': {
                  'result': ['0:42:7'],
                },
                'instances': <String, Object>{},
              },
            },
          },
        },
      }),
    );

    final entry = flcData!.lookupSignalEntry('Example', 'result');
    expect(entry, isNotNull);
    expect(entry!.frames.single.file, 'lib/src/example.dart');
    expect(entry.frames.single.line, 42);
    expect(entry.frames.single.column, 7);

    final navigation = EmbeddedFlcSourceNavigation(
      flcData,
      primaryModule: 'Example',
    );
    expect(navigation.isAvailable, isTrue);
    expect(
      navigation.formatsForModule('GeneratedExample'),
      {'rohd'},
    );
    expect(
      navigation.lookupSignalFrames(
        signals: const [
          {'module': 'GeneratedExample', 'name': 'result'},
        ],
        format: 'rohd',
      ),
      [
        {
          'file': 'lib/src/example.dart',
          'line': 42,
          'col': 7,
          'desc': 'result',
          'type': 'rohd',
        },
      ],
    );
  });

  test('returns null when the netlist has no embedded trace data', () {
    final flcData = embeddedFlcDataFromNetlistJson(
      jsonEncode({
        'modules': {
          'Example': {
            'attributes': {'top': 1},
          },
        },
      }),
    );

    expect(flcData, isNull);

    const navigation = EmbeddedFlcSourceNavigation(null);
    expect(navigation.isAvailable, isFalse);
    expect(navigation.formatsForModule('Example'), isEmpty);
    expect(
      navigation.lookupSignalFrames(
        signals: const [
          {'module': 'Example', 'name': 'result'},
        ],
      ),
      isEmpty,
    );
  });

  test('exposes output-language frames from FLC data', () {
    final navigation = EmbeddedFlcSourceNavigation(
      FlcData.fromJson({
        'version': 5,
        'files': ['lib/src/example.dart'],
        'modules': {
          'Example': {
            'svFile': 'Example.sv',
            'tree': [
              ['0:42:7', 'result@sv:8:3'],
            ],
          },
        },
      }),
      primaryModule: 'Example',
    );

    expect(
      navigation.formatsForModule('Example'),
      {'rohd', 'sv'},
    );
    expect(
      navigation.lookupSignalFrames(
        signals: const [
          {'module': 'Example', 'name': 'result'},
        ],
        format: 'sv',
      ),
      [
        {
          'file': 'Example.sv',
          'line': 8,
          'col': 3,
          'desc': 'result',
          'type': 'sv',
        },
      ],
    );
  });
}
