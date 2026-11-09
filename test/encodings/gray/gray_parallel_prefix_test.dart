// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// gray_parallel_prefix_test.dart
// Tests for the optional parallel-prefix Gray-to-binary converter.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/prefix_networks/parallel_prefix_operations.dart';
import 'package:rohd_hcl/src/encodings/gray/binary_gray.dart';
import 'package:test/test.dart';

import '../../arithmetic/prefix_networks/prefix_rtl_structure.dart';

final _generators = <String, ParallelPrefixGenerator<Logic>>{
  'ripple': Ripple<Logic>.new,
  'sklansky': Sklansky<Logic>.new,
  'koggeStone': KoggeStone<Logic>.new,
  'brentKung': BrentKung<Logic>.new,
};

int _grayToBinary(int gray) {
  var result = 0;
  for (var remaining = gray; remaining != 0; remaining >>= 1) {
    result ^= remaining;
  }
  return result;
}

// A direct fixture for the original linear circuit and its definition name.
class _OriginalGrayToBinary extends Module {
  _OriginalGrayToBinary(Logic gray)
      : super(definitionName: 'GrayToBinaryConverter_W${gray.width}') {
    final width = gray.width;
    gray = addInput('gray', gray, width: width);
    final binary = addOutput('binary', width: width);
    final bits = List<Logic>.filled(width, Const(0));
    bits[width - 1] = gray[width - 1];
    for (var bit = width - 2; bit >= 0; bit--) {
      bits[bit] = bits[bit + 1] ^ gray[bit];
    }
    binary <= bits.rconcat();
  }
}

class _GrayHarness extends Module {
  _GrayHarness(int width, {bool reverse = false})
      : super(definitionName: 'GrayHarness') {
    final gray = addInput('gray', Logic(width: width), width: width);
    addOutput('linear', width: width) <= GrayToBinaryConverter(gray).binary;
    final generators =
        reverse ? _generators.entries.toList().reversed : _generators.entries;
    for (final generator in generators) {
      addOutput(generator.key, width: width) <=
          GrayToBinaryConverter(gray, ppGen: generator.value).binary;
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

  test('default generated RTL preserves the original linear circuit', () async {
    for (final width in [1, 3, 8]) {
      final current = GrayToBinaryConverter(Logic(width: width));
      final original = _OriginalGrayToBinary(Logic(width: width));
      await current.build();
      await original.build();
      String withoutTimestamp(String rtl) =>
          rtl.replaceAll(RegExp(r' \* Generation time:.*\n'), '');
      expect(withoutTimestamp(current.dumpSystemVerilog()),
          withoutTimestamp(original.dumpSystemVerilog()));
    }
  });

  for (final reverse in [false, true]) {
    test('mixed Gray RTL retains selected topologies, reverse=$reverse',
        () async {
      final harness = _GrayHarness(8, reverse: reverse);
      await harness.build();
      final modules = rtlModules(harness.dumpSystemVerilog());
      final top = modules['GrayHarness']!;
      for (final generator in _generators.keys) {
        final converter = connectedDefinition(top, 'binary', generator);
        final scan = connectedDefinition(modules[converter]!, 'out', 'binary');
        expectScanTopology(modules, scan, generator, '^', highToLow: true);
      }
    });
  }

  for (final width in [1, 2, 3, 5, 8]) {
    for (final generator in _generators.entries) {
      test('width $width ${generator.key} matches the linear converter',
          () async {
        final gray = Logic(width: width);
        final linear = GrayToBinaryConverter(gray);
        final prefix = GrayToBinaryConverter(gray, ppGen: generator.value);
        await linear.build();
        await prefix.build();
        for (var value = 0; value < 1 << width; value++) {
          gray.put(value);
          final expected = _grayToBinary(value);
          expect(linear.binary.value.toInt(), expected);
          expect(prefix.binary.value.toInt(), expected, reason: 'gray=$value');
        }
      });
    }
  }

  for (final width in [1, 3, 5]) {
    test('mixed Gray converter RTL matches reference at width $width',
        () async {
      final harness = _GrayHarness(width);
      await harness.build();
      final bench = StringBuffer('''
module testbench;
  reg [${width - 1}:0] gray;
''');
      for (final port in ['linear', ..._generators.keys]) {
        bench.writeln('  wire [${width - 1}:0] $port;');
      }
      bench
        ..writeln('  GrayHarness dut(.*);')
        ..writeln('  initial begin');
      for (var value = 0; value < 1 << width; value++) {
        bench.writeln("    gray = $width'd$value; #1;");
        for (final port in ['linear', ..._generators.keys]) {
          bench.writeln("    if ($port !== $width'd${_grayToBinary(value)}) "
              '\$fatal(1, "$port gray=$value");');
        }
      }
      bench.writeln('    \$finish; end\nendmodule');
      final base =
          '.gray_icarus_${pid}_${DateTime.now().microsecondsSinceEpoch}';
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
