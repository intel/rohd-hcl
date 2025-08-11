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

ComplexFloatingPoint newComplex(double real, double imaginary) {
  final realFP = FloatingPoint64();
  final imaginaryFP = FloatingPoint64();

  final realFPValue = FloatingPoint64Value.populator().ofDouble(real);
  final imaginaryFPValue = FloatingPoint64Value.populator().ofDouble(imaginary);

  realFP.put(realFPValue);
  imaginaryFP.put(imaginaryFPValue);

  final complex = ComplexFloatingPoint(
    exponentWidth: realFP.exponent.width,
    mantissaWidth: realFP.mantissa.width,
  );
  complex.realPart <= realFP;
  complex.imaginaryPart <= imaginaryFP;

  return complex;
}

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
    final a = newComplex(1.0, 2.0);
    final b = newComplex(-3.0, -4.0);
    final twiddle = newComplex(1.0, 0.0);
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);
    final go = Logic()..put(0);

    final n = 2;

    final exponentWidth = a.realPart.exponent.width;
    final mantissaWidth = a.realPart.mantissa.width;
    final dataWidth = a.width; //2 * (1 + exponentWidth + mantissaWidth);
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
    
    print(stage.generateSynth());

    unawaited(Simulator.run());

    reset.inject(1);
    await clk.waitCycles(10);
    reset.inject(0);
    await clk.waitCycles(10);

    await write(clk, tempMemoryWritePort, a.value, 0);
    await write(clk, tempMemoryWritePort, b.value, 1);
    await write(clk, twiddleFactorROMWritePort, a.value, 0);
    await write(clk, twiddleFactorROMWritePort, b.value, 1);

    go.inject(1);
    stage.done.posedge.listen((_) {
      go.inject(0);
    });
    await clk.waitCycles(5);

    await Simulator.endSimulation();
  });
}
