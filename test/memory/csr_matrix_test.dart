// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_matrix_test.dart
// Cross-implementation matrix for a minimal CSR. One stimulus table drives:
// the Dart RTL (golden, four-state), the Dart software model, SystemVerilog
// RTL (iverilog), SystemC RTL (two-state), and SystemC software models
// (four-state and two-state). Each leg emits one binary trace line per op.
//
// Process legs run concurrently in the background while the Dart simulations
// run, so the matrix costs roughly one SystemC compile rather than one per
// case.
//
// 2026 October 20
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

const int _dataWidth = 32;
const int _addrWidth = 8;

/// Minimal CSR covering every access mode: a readWrite register with
/// writeOnly, writeOnesClear, and readWriteLegal fields; a readOnly register;
/// a 1-bit scalar; and a 32-bit register.
CsrTopConfig csrMatrixConfig({required bool asyncReset}) => CsrTopConfig(
      name: 'matrix',
      blockSize: 64,
      asyncReset: asyncReset,
      blocks: [
        CsrBlockConfig(name: 'ctrl', baseAddr: 0, registers: [
          CsrInstanceConfig(
            arch: CsrConfig(name: 'ctl', access: CsrAccess.readWrite, fields: [
              CsrFieldConfig(
                  start: 0,
                  width: 4,
                  name: 'rw',
                  access: CsrFieldAccess.readWrite),
              CsrFieldConfig(
                  start: 4,
                  width: 4,
                  name: 'wo',
                  access: CsrFieldAccess.writeOnly),
              CsrFieldConfig(
                  start: 8,
                  width: 4,
                  name: 'w1c',
                  access: CsrFieldAccess.writeOnesClear),
              CsrFieldConfig(
                  start: 12,
                  width: 2,
                  name: 'legal',
                  access: CsrFieldAccess.readWriteLegal,
                  legalValues: const [0, 1]),
            ]),
            addr: 0,
            width: 16,
            resetValue: 0x0fa0,
          ),
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'ro', access: CsrAccess.readOnly, fields: const []),
              addr: 1,
              width: 16,
              resetValue: 0xabcd),
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'flag', access: CsrAccess.readWrite, fields: const []),
              addr: 2,
              width: 1),
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'wide', access: CsrAccess.readWrite, fields: const []),
              addr: 3,
              width: 32,
              resetValue: 0x12345678),
        ]),
      ],
    );

/// One clock cycle of stimulus. The read port always samples [addr] after the
/// rising edge, so every trace entry is the post-edge frontdoor read.
class _Op {
  const _Op({
    this.reset = false,
    this.write = false,
    this.addr = 0,
    this.data = 0,
    this.enableX = false,
    this.dataX = false,
  });

  final bool reset;
  final bool write;
  final int addr;
  final int data;
  final bool enableX;
  final bool dataX;

  LogicValue get enable =>
      enableX ? LogicValue.x : LogicValue.ofInt(write ? 1 : 0, 1);

  LogicValue get dataValue => dataX
      ? LogicValue.ofString('xxxxxxxxxxxxxxxx0000111100001111')
      : LogicValue.ofInt(data, _dataWidth);
}

/// X-free stimulus, run by every leg. Covers reset values, readWrite,
/// writeOnly (reads return the reset value), writeOnesClear, readWriteLegal
/// (legal, and illegal falling back to the transform), readOnly write
/// suppression, 1-bit and 32-bit registers, back-to-back write/read, and
/// mid-run reset.
const List<_Op> _commonOps = [
  _Op(reset: true),
  _Op(),
  _Op(addr: 1),
  _Op(addr: 2),
  _Op(addr: 3),
  _Op(write: true, data: 0xffff),
  _Op(),
  _Op(write: true, data: 0x0100),
  _Op(),
  _Op(write: true),
  _Op(),
  _Op(write: true, data: 0x5a5a),
  _Op(),
  _Op(write: true, data: 0x3000),
  _Op(),
  _Op(write: true, data: 0x1000),
  _Op(),
  _Op(write: true, addr: 1, data: 0x1234),
  _Op(addr: 1),
  _Op(write: true, addr: 2, data: 1),
  _Op(addr: 2),
  _Op(write: true, addr: 2),
  _Op(addr: 2),
  _Op(write: true, addr: 3, data: 0xdeadbeef),
  _Op(addr: 3),
  _Op(write: true, addr: 3, data: 0xffffffff),
  _Op(addr: 3),
  _Op(write: true, data: 0xa5a5),
  _Op(write: true, addr: 3),
  _Op(),
  _Op(addr: 3),
  _Op(reset: true),
  _Op(),
  _Op(addr: 2),
  _Op(addr: 3),
  _Op(write: true, data: 0xf0f0),
  _Op(reset: true),
  _Op(),
];

/// Four-state-only stimulus appended after [_commonOps]. X on the enable or
/// data input must propagate identically in the four-state legs; the
/// two-state legs cannot represent X and run only the common prefix.
const List<_Op> _xOps = [
  _Op(write: true, data: 0x1111, enableX: true),
  _Op(),
  _Op(reset: true),
  _Op(),
  _Op(write: true, addr: 3, data: 0x5, dataX: true),
  _Op(addr: 3),
  _Op(reset: true),
  _Op(addr: 3),
];

final List<_Op> _allOps = [..._commonOps, ..._xOps];

LogicValue _portValue(_Op op, String name, int width) => switch (name) {
      'reset' => LogicValue.ofInt(op.reset ? 1 : 0, 1),
      'frontWrite_en' => op.enable,
      'frontWrite_addr' => LogicValue.ofInt(op.addr, width),
      'frontWrite_data' => op.dataValue,
      'frontRead_en' => LogicValue.one,
      'frontRead_addr' => LogicValue.ofInt(op.addr, width),
      _ => LogicValue.ofInt(0, width),
    };

bool _hasTool(String tool) => Process.runSync('which', [tool]).exitCode == 0;

String _normalize(String text) => text
    .split('\n')
    .map((line) => line.trim().toLowerCase().replaceFirst(RegExp('^0b'), ''))
    .where((line) => RegExp(r'^[01xz]+$').hasMatch(line))
    .join('\n');

List<String> _lines(String text) =>
    _normalize(text).split('\n').where((line) => line.isNotEmpty).toList();

class _Outcome {
  const _Outcome(this.trace, this.log);

  /// Null when the leg failed to compile or run.
  final List<String>? trace;
  final String log;
}

typedef _Harness = ({
  CsrTop top,
  DataPortInterface read,
  DataPortInterface write,
});

_Harness _newHarness({
  required bool asyncReset,
  required CsrImplementation implementation,
  required Logic clk,
  required Logic reset,
}) {
  final read = DataPortInterface(_dataWidth, _addrWidth)
    ..en.put(0)
    ..addr.put(0);
  final write = DataPortInterface(_dataWidth, _addrWidth)
    ..en.put(0)
    ..addr.put(0)
    ..data.put(0);
  final top = CsrTop(
      config: csrMatrixConfig(asyncReset: asyncReset),
      clk: clk,
      reset: reset,
      frontRead: read,
      frontWrite: write,
      implementationConfiguration:
          CsrImplementationConfiguration(implementation: implementation));
  for (final block in top.backdoorInterfaces) {
    for (final port in block) {
      port.wrEn?.put(0);
      port.wrData?.put(0);
    }
  }
  return (top: top, read: read, write: write);
}

/// Dart simulation of [ops]: the golden for RTL, and the software model.
Future<List<String>> _dartTrace(
  List<_Op> ops, {
  required bool asyncReset,
  required CsrImplementation implementation,
}) async {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic()..put(0);
  final harness = _newHarness(
      asyncReset: asyncReset,
      implementation: implementation,
      clk: clk,
      reset: reset);
  await harness.top.build();
  Simulator.setMaxSimTime(ops.length * 100 + 1000);
  unawaited(Simulator.run());
  final trace = <String>[];
  for (final op in ops) {
    reset.inject(op.reset ? 1 : 0);
    harness.write.en.inject(op.enable);
    harness.write.addr.inject(op.addr);
    harness.write.data.inject(op.dataValue);
    harness.read.en.inject(1);
    harness.read.addr.inject(op.addr);
    await Simulator.tick();
    await clk.nextPosedge;
    await clk.nextNegedge;
    trace.add(harness.read.data.value.toString(includeWidth: false));
  }
  await Simulator.endSimulation();
  await Simulator.reset();
  return trace;
}

CsrTop _buildSynthTop({
  required bool asyncReset,
  required CsrImplementation implementation,
}) {
  final clk = Logic()..put(0);
  final reset = Logic()..put(0);
  return _newHarness(
          asyncReset: asyncReset,
          implementation: implementation,
          clk: clk,
          reset: reset)
      .top;
}

String _verilogTestbench(CsrTop top, List<_Op> ops) {
  final buf = StringBuffer('module tb;\n');
  String decl(String name, int width) =>
      width == 1 ? 'logic $name;' : 'logic [${width - 1}:0] $name;';
  for (final entry in top.inputs.entries) {
    buf.writeln('  ${decl(entry.key, entry.value.width)}');
  }
  for (final entry in top.outputs.entries) {
    buf.writeln('  ${decl(entry.key, entry.value.width)}');
  }
  final names = [...top.inputs.keys, ...top.outputs.keys];
  buf
    ..writeln('  ${top.definitionName} dut (')
    ..writeln(names.map((n) => '    .$n($n)').join(',\n'))
    ..writeln('  );')
    ..writeln('  initial begin');
  for (final entry in top.inputs.entries) {
    buf.writeln("    ${entry.key} = ${entry.value.width}'b0;");
  }
  buf.writeln('    clk = 0;');
  for (final op in ops) {
    for (final entry in top.inputs.entries) {
      if (entry.key == 'clk') {
        continue;
      }
      final value = _portValue(op, entry.key, entry.value.width);
      final bits = value.toString(includeWidth: false);
      buf.writeln("    ${entry.key} = ${value.width}'b$bits;");
    }
    buf.writeln(
        r'    #5 clk = 1; #1 $display("%b", frontRead_data); #4 clk = 0;');
  }
  buf
    ..writeln(r'    $finish;')
    ..writeln('  end')
    ..writeln('endmodule');
  return buf.toString();
}

Future<_Outcome> _runSystemVerilog(CsrTop top, List<_Op> ops) async {
  final directory = await Directory.systemTemp.createTemp('hcl_csr_sv_');
  try {
    await File('${directory.path}/dut.sv')
        .writeAsString(top.dumpSystemVerilog());
    await File('${directory.path}/tb.sv')
        .writeAsString(_verilogTestbench(top, ops));
    final compile = await Process.run('iverilog', [
      '-g2012',
      '-o',
      '${directory.path}/sim',
      '${directory.path}/tb.sv',
      '${directory.path}/dut.sv',
    ]);
    if (compile.exitCode != 0) {
      return _Outcome(null, '${compile.stdout}${compile.stderr}');
    }
    final run = await Process.run('vvp', ['-n', '${directory.path}/sim']);
    return _Outcome(_lines(run.stdout as String), '${run.stdout}${run.stderr}');
  } finally {
    await directory.delete(recursive: true);
  }
}

String _scType(int width, {required bool fourState}) => width == 1
    ? (fourState ? 'sc_dt::sc_logic' : 'bool')
    : (fourState ? 'sc_dt::sc_lv<$width>' : 'sc_dt::sc_uint<$width>');

String _scLiteral(LogicValue value, {required bool fourState}) {
  final bits = value.toString(includeWidth: false).toUpperCase();
  if (value.width == 1) {
    return fourState
        ? "sc_dt::sc_logic('$bits')"
        : (bits == '1' ? 'true' : 'false');
  }
  return fourState
      ? 'sc_dt::sc_lv<${value.width}>("$bits")'
      : 'sc_dt::sc_uint<${value.width}>(${value.toBigInt()}ULL)';
}

String _systemCMain({
  required CsrTop top,
  required String className,
  required bool fourState,
  required List<_Op> ops,
  required List<String> includes,
}) {
  final out = StringBuffer()
    ..writeln('#include <iostream>')
    ..writeln('#include <systemc>')
    ..writeln('using namespace sc_core;')
    ..writeln('using namespace sc_dt;');
  for (final include in includes) {
    out.writeln('#include "$include"');
  }
  out.writeln('int sc_main(int, char **) {');
  final ports = {...top.inputs, ...top.outputs};
  for (final entry in ports.entries) {
    out.writeln('  sc_core::sc_signal<'
        '${_scType(entry.value.width, fourState: fourState)}>'
        ' s_${entry.key};');
  }
  out.writeln('  $className dut("dut");');
  for (final name in ports.keys) {
    out.writeln('  dut.$name(s_$name);');
  }
  void drive(String name, LogicValue value) {
    out.writeln('  s_$name.write(${_scLiteral(value, fourState: fourState)});');
  }

  for (final entry in top.inputs.entries) {
    drive(entry.key, LogicValue.ofInt(0, entry.value.width));
  }
  // Settle the initial clk X->0 transition before the first edge; the
  // four-state model treats any clock event with an unknown prior value as
  // invalid, which would otherwise leave registers at X.
  out.writeln('  sc_core::sc_start(1, sc_core::SC_NS);');
  final readWidth = top.outputs['frontRead_data']!.width;
  final readOut = readWidth == 1
      ? '  std::cout << s_frontRead_data.read();'
      : '  for (int i = ${readWidth - 1}; i >= 0; --i) '
          '{ std::cout << s_frontRead_data.read()[i]; }';
  for (final op in ops) {
    for (final entry in top.inputs.entries) {
      if (entry.key == 'clk') {
        continue;
      }
      drive(entry.key, _portValue(op, entry.key, entry.value.width));
    }
    // Let combinational logic settle before the edge so the clocked process
    // samples current enables/data rather than the previous op's values.
    out.writeln('  sc_core::sc_start(1, sc_core::SC_NS);');
    drive('clk', LogicValue.one);
    out
      ..writeln('  sc_core::sc_start(1, sc_core::SC_NS);')
      ..writeln(readOut)
      ..writeln('  std::cout << std::endl;');
    drive('clk', LogicValue.zero);
    out.writeln('  sc_core::sc_start(1, sc_core::SC_NS);');
  }
  out.writeln('  return 0;\n}');
  return out.toString();
}

Future<_Outcome> _compileAndRunSystemC(
    Map<String, String> files, String mainSource) async {
  final directory = await Directory.systemTemp.createTemp('hcl_csr_sc_');
  try {
    for (final entry in files.entries) {
      await File('${directory.path}/${entry.key}').writeAsString(entry.value);
    }
    await File('${directory.path}/main.cpp').writeAsString(mainSource);
    final compile = await Process.run('g++', [
      '-std=c++17',
      '-I',
      directory.path,
      '${directory.path}/main.cpp',
      '-lsystemc',
      '-o',
      '${directory.path}/sim',
    ]);
    if (compile.exitCode != 0) {
      return _Outcome(null, '${compile.stdout}${compile.stderr}');
    }
    final run = await Process.run('${directory.path}/sim', []);
    return _Outcome(_lines(run.stdout as String), '${run.stdout}${run.stderr}');
  } finally {
    await directory.delete(recursive: true);
  }
}

Future<_Outcome> _runSystemCRtl(CsrTop top, List<_Op> ops) {
  final synth = SystemCSynthesizer();
  final files = SynthBuilder(top, synth).getSynthFileContents();
  final topFile = files.firstWhere(
      (f) => f.contents.contains('SC_MODULE(${top.definitionName})'));
  final includes = [
    for (final f in files)
      if (f != topFile) f.name,
    topFile.name,
  ];
  return _compileAndRunSystemC(
    {for (final f in files) f.name: f.contents},
    _systemCMain(
      top: top,
      className: top.definitionName,
      fourState: false,
      ops: ops,
      includes: includes,
    ),
  );
}

Future<_Outcome> _runSystemCSoftware(
  CsrTop top, {
  required bool fourState,
  required List<_Op> ops,
}) {
  const modelHeader = 'model.h';
  final className = fourState ? 'CsrModel4' : 'CsrModel2';
  final options = fourState
      ? const SystemCModelOptions()
      : const SystemCModelOptions(
          portType: SystemCModelPortType.twoState,
          unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset);
  final header =
      top.generateModelSystemC(className: className, options: options);
  return _compileAndRunSystemC(
    {modelHeader: header},
    _systemCMain(
      top: top,
      className: className,
      fourState: fourState,
      ops: ops,
      includes: [modelHeader],
    ),
  );
}

/// Outcomes for one reset mode. Process legs run in the background; the Dart
/// legs are simulated in the foreground.
class _ModeLegs {
  _ModeLegs({
    required this.golden,
    required this.software,
    required this.systemVerilog,
    required this.systemCRtl,
    required this.systemCFourState,
    required this.systemCTwoState,
  });

  final List<String> golden;
  final List<String> software;
  final Future<_Outcome>? systemVerilog;
  final Future<_Outcome>? systemCRtl;
  final Future<_Outcome>? systemCFourState;
  final Future<_Outcome>? systemCTwoState;
}

Future<Map<bool, _ModeLegs>>? _matrixFuture;

Future<Map<bool, _ModeLegs>> _matrix() => _matrixFuture ??= _runMatrix();

Future<Map<bool, _ModeLegs>> _runMatrix() async {
  final haveGpp = _hasTool('g++');
  final haveIverilog = _hasTool('iverilog');
  final pending = <bool, _Pending>{};
  for (final asyncReset in [false, true]) {
    final rtl = _buildSynthTop(
        asyncReset: asyncReset, implementation: CsrImplementation.rtl);
    await rtl.build();
    final software = _buildSynthTop(
        asyncReset: asyncReset, implementation: CsrImplementation.software);
    await software.build();
    pending[asyncReset] = _Pending(
      systemVerilog: haveIverilog ? _runSystemVerilog(rtl, _commonOps) : null,
      systemCRtl: haveGpp ? _runSystemCRtl(rtl, _commonOps) : null,
      systemCFourState: haveGpp
          ? _runSystemCSoftware(software, fourState: true, ops: _allOps)
          : null,
      systemCTwoState: haveGpp
          ? _runSystemCSoftware(software, fourState: false, ops: _commonOps)
          : null,
    );
  }
  final results = <bool, _ModeLegs>{};
  for (final asyncReset in [false, true]) {
    final golden = await _dartTrace(_allOps,
        asyncReset: asyncReset, implementation: CsrImplementation.rtl);
    final software = await _dartTrace(_allOps,
        asyncReset: asyncReset, implementation: CsrImplementation.software);
    final p = pending[asyncReset]!;
    results[asyncReset] = _ModeLegs(
      golden: golden,
      software: software,
      systemVerilog: p.systemVerilog,
      systemCRtl: p.systemCRtl,
      systemCFourState: p.systemCFourState,
      systemCTwoState: p.systemCTwoState,
    );
  }
  return results;
}

class _Pending {
  _Pending({
    required this.systemVerilog,
    required this.systemCRtl,
    required this.systemCFourState,
    required this.systemCTwoState,
  });

  final Future<_Outcome>? systemVerilog;
  final Future<_Outcome>? systemCRtl;
  final Future<_Outcome>? systemCFourState;
  final Future<_Outcome>? systemCTwoState;
}

void main() {
  tearDown(Simulator.reset);

  const matrixTimeout = Timeout(Duration(minutes: 3));
  final skipIverilog = _hasTool('iverilog') ? null : 'iverilog not on PATH';
  final skipGpp = _hasTool('g++') ? null : 'g++ not on PATH';

  group('CSR implementation matrix', () {
    for (final asyncReset in [false, true]) {
      final mode = asyncReset ? 'async' : 'sync';

      test('[$mode] Dart software model matches RTL golden trace',
          timeout: matrixTimeout, () async {
        final legs = (await _matrix())[asyncReset]!;
        expect(legs.software, legs.golden,
            reason: 'software model diverged from RTL golden');
      });

      test('[$mode] SystemVerilog RTL via iverilog matches golden trace',
          timeout: matrixTimeout, skip: skipIverilog, () async {
        final legs = (await _matrix())[asyncReset]!;
        final outcome = await legs.systemVerilog!;
        // Verilog `if (en)` holds on an X enable, while ROHD propagates X,
        // so the X tail is excluded and only `_commonOps` is replayed.
        expect(outcome.trace, legs.golden.take(_commonOps.length).toList(),
            reason: outcome.log);
      });

      test('[$mode] SystemC RTL matches golden trace on the two-state prefix',
          timeout: matrixTimeout, skip: skipGpp, () async {
        final legs = (await _matrix())[asyncReset]!;
        final outcome = await legs.systemCRtl!;
        expect(outcome.trace, legs.golden.take(_commonOps.length).toList(),
            reason: outcome.log);
      });

      test('[$mode] SystemC software four-state matches golden trace',
          timeout: matrixTimeout, skip: skipGpp, () async {
        final legs = (await _matrix())[asyncReset]!;
        final outcome = await legs.systemCFourState!;
        expect(outcome.trace, legs.golden, reason: outcome.log);
      });

      test('[$mode] SystemC software two-state matches golden trace prefix',
          timeout: matrixTimeout, skip: skipGpp, () async {
        final legs = (await _matrix())[asyncReset]!;
        final outcome = await legs.systemCTwoState!;
        expect(outcome.trace, legs.golden.take(_commonOps.length).toList(),
            reason: outcome.log);
      });
    }
  });

  test('generateModelSystemC rejects an RTL implementation', () async {
    final top = _buildSynthTop(
        asyncReset: false, implementation: CsrImplementation.rtl);
    await top.build();
    expect(
        () => top.generateModelSystemC(className: 'Model'), throwsStateError);
  });

  test('dumpSystemVerilog rejects a software implementation', () async {
    final top = _buildSynthTop(
        asyncReset: false, implementation: CsrImplementation.software);
    await top.build();
    expect(top.dumpSystemVerilog, throwsUnsupportedError);
  });
}
