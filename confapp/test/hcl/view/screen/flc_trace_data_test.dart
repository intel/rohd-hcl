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
        SourceTracer,
        SystemVerilogService;
import 'package:rohd_hcl/src/arithmetic/addition/adder.dart' show NativeAdder;
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
