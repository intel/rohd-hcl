// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// prefix_rtl_structure.dart
// Helpers for checking instantiated prefix structures in generated RTL.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:test/test.dart';

/// Parses the generated RTL's named module definitions.
Map<String, String> rtlModules(String rtl) => {
      for (final match
          in RegExp(r'module\s+(\w+)\s*\(.*?endmodule\s*:\s*\w+', dotAll: true)
              .allMatches(rtl))
        match[1]!: match[0]!,
    };

/// Finds the definition instantiated with [port] connected to [signal].
String connectedDefinition(String module, String port, String signal) {
  final expression = RegExp(
      r'^\s*(\w+)\s+\w+\s*\([^;\n]*\.' +
          RegExp.escape(port) +
          r'\(' +
          RegExp.escape(signal) +
          r'\)[^;\n]*\);',
      multiLine: true);
  final matches = expression.allMatches(module).toList();
  expect(matches, hasLength(1), reason: 'Connection .$port($signal)');
  return matches.single[1]!;
}

/// Checks both the definition selected by a scan and its network structure.
void expectScanTopology(Map<String, String> modules, String scanDefinition,
    String topology, String operationSymbol,
    {required bool highToLow}) {
  final scan = modules[scanDefinition]!;
  expect(scan, contains('.i0((inp[${highToLow ? 7 : 0}]))'));
  final network =
      connectedDefinition(scan, 'o7', highToLow ? 'out[0]' : 'out[7]');
  final expectedName = {
    'ripple': 'Ripple',
    'sklansky': 'Skanskly',
    'koggeStone': 'KoggeStone',
    'brentKung': 'BrentKung',
  }[topology]!;
  expect(network, matches(RegExp('^$expectedName(?:_\\d+)?\$')),
      reason: 'Expected $topology inside $scanDefinition');
  final body = modules[network]!;
  expect(body, contains(' $operationSymbol '));
  switch (topology) {
    case 'ripple':
      expect(body, contains('assign o7 = o6 $operationSymbol i7;'));
    case 'sklansky':
      expect(RegExp(r'\bSkanskly(?:_\d+)?\s+sklansky').allMatches(body),
          hasLength(2));
    case 'koggeStone':
      expect(body, contains('ks_skip4_i7'));
      expect(body, contains('ks_skip2_i7'));
    case 'brentKung':
      expect(body, contains('reduce_7'));
      expect(body, contains('prefix_5'));
      expect(body, contains('final_6'));
  }
}
