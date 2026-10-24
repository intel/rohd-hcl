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
      final flcData = bundledSourceFlcData(svService);
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
      bundledSourceFlcData(SystemVerilogService(module, register: false)),
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
      final flcData = bundledSourceFlcData(svService)!;

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
