// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point/fft/butterfly.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point/fft/fft_stage.dart';
import 'package:rohd_hcl/src/arithmetic/signals/floating_point_logics/complex_floating_point_logic.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';
import 'fft_utils.dart';

Future<void> write(
  Logic clk,
  DataPortInterface writePort,
  LogicValue value,
  int addr,
) async {
  await clk.nextNegedge;
  writePort.addr.inject(LogicValue.ofInt(addr, writePort.addrWidth));
  writePort.data.inject(value);
  writePort.en.inject(1);

  await clk.nextNegedge;
  writePort.en.inject(0);
  await clk.nextNegedge;
}

Future<LogicValue> read(Logic clk, DataPortInterface readPort, int addr) async {
  readPort.addr.inject(LogicValue.ofInt(addr, readPort.addrWidth));
  readPort.en.inject(1);
  await clk.nextPosedge;
  final value = readPort.data.value;

  await clk.nextNegedge;
  readPort.en.inject(0);
  await clk.nextNegedge;

  return value;
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('fft stage unit test', () async {
    final a = Complex(real: 1.0, imaginary: 2.0);
    final b = Complex(real: -3.0, imaginary: -4.0);
    final twiddle = Complex(real: 1.0, imaginary: 0.0);
    final aLogic = newComplex(a.real, a.imaginary);
    final bLogic = newComplex(b.real, b.imaginary);
    final twiddleLogic = newComplex(twiddle.real, twiddle.imaginary);
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);
    final go = Logic()..put(0);

    final n = 2;

    final exponentWidth = aLogic.realPart.exponent.width;
    final mantissaWidth = aLogic.realPart.mantissa.width;
    final dataWidth = aLogic.width; //2 * (1 + exponentWidth + mantissaWidth);
    final addrWidth = log2Ceil(n);

    final tempMemoryWritePort = DataPortInterface(dataWidth, addrWidth);
    final tempMemoryReadPortA = DataPortInterface(dataWidth, addrWidth);
    final tempMemoryReadPortB = DataPortInterface(dataWidth, addrWidth);
    final twiddleFactorROMWritePort = DataPortInterface(dataWidth, addrWidth);
    final twiddleFactorROMReadPort = DataPortInterface(dataWidth, addrWidth);
    final outputSamplesA = DataPortInterface(dataWidth, addrWidth);
    final outputSamplesB = DataPortInterface(dataWidth, addrWidth);

    final twiddleFactorROM = RegisterFile(
      clk,
      reset,
      [twiddleFactorROMWritePort],
      [twiddleFactorROMReadPort],
      numEntries: n,
    );
    final tempMemory = RegisterFile(
      clk,
      reset,
      [tempMemoryWritePort],
      [tempMemoryReadPortA, tempMemoryReadPortB],
      numEntries: n,
    );

    final stage = BadFFTStage(
      logStage: 1,
      exponentWidth: exponentWidth,
      mantissaWidth: mantissaWidth,
      clk: clk,
      reset: reset,
      go: go,
      inputSamplesA: tempMemoryReadPortA,
      inputSamplesB: tempMemoryReadPortB,
      twiddleFactorROM: twiddleFactorROMReadPort,
      outputSamplesA: outputSamplesA,
      outputSamplesB: outputSamplesB,
    );

    await stage.build();

    WaveDumper(stage);

    unawaited(Simulator.run());

    reset.inject(1);
    await clk.waitCycles(10);
    reset.inject(0);
    await clk.waitCycles(10);

    await write(clk, tempMemoryWritePort, aLogic.value, 0);
    await write(clk, tempMemoryWritePort, bLogic.value, 1);
    await write(clk, twiddleFactorROMWritePort, twiddleLogic.value, 0);

    go.inject(1);
    flop(clk, stage.done).posedge.listen((_) {
      go.inject(0);
    });
    await clk.waitCycles(5);

    final output1 = await read(clk, outputSamplesA, 0);
    final output2 = await read(clk, outputSamplesA, 1);
    final output1float = ComplexFloatingPoint.of(
      Const(output1),
      exponentWidth: exponentWidth,
      mantissaWidth: mantissaWidth,
    );
    final output2float = ComplexFloatingPoint.of(
      Const(output2),
      exponentWidth: exponentWidth,
      mantissaWidth: mantissaWidth,
    );

    final expected = butterfly(a, b, twiddle);

    compareDouble(
      output1float.realPart.floatingPointValue.toDouble(),
      expected[0].real,
    );
    compareDouble(
      output1float.imaginaryPart.floatingPointValue.toDouble(),
      expected[0].imaginary,
    );
    compareDouble(
      output2float.realPart.floatingPointValue.toDouble(),
      expected[1].real,
    );
    compareDouble(
      output2float.imaginaryPart.floatingPointValue.toDouble(),
      expected[1].imaginary,
    );

    await Simulator.endSimulation();
  });
}
