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
  });
}
