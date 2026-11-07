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
import 'package:flutter_test/flutter_test.dart';
import 'package:rohd_source_navigator/flc_data.dart';

void main() {
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
