// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// bitwise_prefix_scan_test.dart
// Tests for configurable inclusive bitwise prefix scans.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/prefix_networks/parallel_prefix_operations.dart';
import 'package:test/test.dart';

import 'prefix_rtl_structure.dart';

final _generators = <String, ParallelPrefixGenerator<Logic>>{
  'ripple': Ripple<Logic>.new,
  'sklansky': Sklansky<Logic>.new,
  'koggeStone': KoggeStone<Logic>.new,
  'brentKung': BrentKung<Logic>.new,
};

int _reference(int value, int width, PrefixScanOperation operation,
    PrefixScanDirection direction) {
  var output = 0;
  for (var bit = 0; bit < width; bit++) {
    final first = direction == PrefixScanDirection.lowToHigh ? 0 : bit;
    final last = direction == PrefixScanDirection.lowToHigh ? bit : width - 1;
    var accum = operation == PrefixScanOperation.and ? 1 : 0;
    for (var i = first; i <= last; i++) {
      final input = (value >> i) & 1;
      switch (operation) {
        case PrefixScanOperation.and:
          accum &= input;
        case PrefixScanOperation.or:
          accum |= input;
        case PrefixScanOperation.xor:
          accum ^= input;
      }
    }
    output |= accum << bit;
  }
  return output;
}

class _ScanHarness extends Module {
  _ScanHarness(int width, {bool reverse = false})
      : super(definitionName: 'ScanHarness') {
    final inp = addInput('inp', Logic(width: width), width: width);
    final generators =
        reverse ? _generators.entries.toList().reversed : _generators.entries;
    for (final generator in generators) {
      for (final operation in PrefixScanOperation.values) {
        for (final direction in PrefixScanDirection.values) {
          final port = '${generator.key}_${operation.name}_${direction.name}';
          final scan = ParallelPrefixScan(inp,
              operation: operation,
              direction: direction,
              ppGen: generator.value);
          addOutput(port, width: width) <= scan.out;
        }
      }
    }
  }
}

String? _missingIcarus() {
  try {
    for (final tool in ['iverilog', 'vvp']) {
      if (Process.runSync(tool, ['-V']).exitCode != 0) {
        return '$tool unavailable';
      }
    }
    return null;
  } on ProcessException {
    return 'Icarus Verilog unavailable';
  }
}

void main() {
  tearDown(Simulator.reset);

  for (final reverse in [false, true]) {
    test('mixed RTL retains every selected topology, reverse=$reverse',
        () async {
      final harness = _ScanHarness(8, reverse: reverse);
      await harness.build();
      final modules = rtlModules(harness.dumpSystemVerilog());
      final top = modules['ScanHarness']!;
      for (final generator in _generators.keys) {
        for (final operation in PrefixScanOperation.values) {
          for (final direction in PrefixScanDirection.values) {
            final port = '${generator}_${operation.name}_${direction.name}';
            final scan = connectedDefinition(top, 'out', port);
            final symbol = switch (operation) {
              PrefixScanOperation.and => '&',
              PrefixScanOperation.or => '|',
              PrefixScanOperation.xor => '^',
            };
            expectScanTopology(modules, scan, generator, symbol,
                highToLow: direction == PrefixScanDirection.highToLow);
          }
        }
      }
    });
  }

  for (final width in [1, 2, 3, 5, 7, 8]) {
    for (final generator in _generators.entries) {
      for (final operation in PrefixScanOperation.values) {
        for (final direction in PrefixScanDirection.values) {
          test('$width ${generator.key} ${operation.name} ${direction.name}',
              () async {
            final input = Logic(width: width);
            final scan = ParallelPrefixScan(input,
                operation: operation,
                direction: direction,
                ppGen: generator.value);
            await scan.build();
            for (var value = 0; value < 1 << width; value++) {
              input.put(value);
              expect(scan.out.value.toInt(),
                  _reference(value, width, operation, direction),
                  reason: 'input=$value');
            }
          });
        }
      }
    }
  }

  for (final width in [1, 3, 5, 7, 8]) {
    test('generated RTL matches all scans at width $width', () async {
      final harness = _ScanHarness(width);
      await harness.build();
      final bench = StringBuffer('''
module testbench;
  reg [${width - 1}:0] inp;
''');
      for (final generator in _generators.keys) {
        for (final operation in PrefixScanOperation.values) {
          for (final direction in PrefixScanDirection.values) {
            bench.writeln('  wire [${width - 1}:0] '
                '${generator}_${operation.name}_${direction.name};');
          }
        }
      }
      bench
        ..writeln('  ScanHarness dut(.*);')
        ..writeln('  initial begin');
      for (var value = 0; value < 1 << width; value++) {
        bench.writeln("    inp = $width'd$value; #1;");
        for (final generator in _generators.keys) {
          for (final operation in PrefixScanOperation.values) {
            for (final direction in PrefixScanDirection.values) {
              final port = '${generator}_${operation.name}_${direction.name}';
              final expected = _reference(value, width, operation, direction);
              bench.writeln("    if ($port !== $width'd$expected) "
                  '\$fatal(1, "$port input=$value");');
            }
          }
        }
      }
      bench.writeln('    \$finish; end\nendmodule');
      final base =
          '.scan_icarus_${pid}_${DateTime.now().microsecondsSinceEpoch}';
      final source = File('$base.sv');
      final executable = File('$base.out');
      try {
        source.writeAsStringSync('${harness.dumpSystemVerilog()}\n$bench');
        final compile = await Process.run('iverilog',
            ['-g2012', '-s', 'testbench', '-o', executable.path, source.path]);
        expect(compile.exitCode, 0,
            reason: '${compile.stdout}\n${compile.stderr}');
        final run = await Process.run('vvp', [executable.path]);
        expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
      } finally {
        if (source.existsSync()) {
          source.deleteSync();
        }
        if (executable.existsSync()) {
          executable.deleteSync();
        }
      }
    }, skip: _missingIcarus());
  }
}
