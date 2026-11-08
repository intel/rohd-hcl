// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// runtime_signedness_icarus_test.dart
// Verify independently selectable operand signedness in generated HDL.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('unnamed multiplier controls select independently in HDL', () async {
    final multiplier = CompressionTreeMultiplier(
      Logic(width: 3),
      Logic(width: 3),
      signedMultiplicand: StaticOrRuntimeParameter.fromLogic(Logic(),
          fallbackName: 'signedMultiplicand'),
      signedMultiplier: StaticOrRuntimeParameter.fromLogic(Logic(),
          fallbackName: 'signedMultiplier'),
    );
    await multiplier.build();

    final vectors = <Vector>[];
    for (final signA in [false, true]) {
      for (final signB in [false, true]) {
        final expected = BigInt.from(7).toCondSigned(3, signed: signA) *
            BigInt.from(6).toCondSigned(3, signed: signB);
        vectors.add(Vector({
          'a': 7,
          'b': 6,
          'signedMultiplicand': signA ? 1 : 0,
          'signedMultiplier': signB ? 1 : 0,
        }, {
          'product': expected.toUnsigned(multiplier.product.width).toInt(),
        }));
      }
    }
    SimCompare.checkIverilogVector(multiplier, vectors);
  }, skip: _iverilogUnavailableReason());

  test('shared multiplier control works in HDL', () async {
    final signed = Logic(name: 'sharedSigned');
    final multiplier = CompressionTreeMultiplier(
      Logic(width: 3),
      Logic(width: 3),
      signedMultiplicand: StaticOrRuntimeParameter.fromLogic(signed,
          fallbackName: 'signedMultiplicand'),
      signedMultiplier: StaticOrRuntimeParameter.fromLogic(signed,
          fallbackName: 'signedMultiplier'),
    );
    await multiplier.build();

    SimCompare.checkIverilogVector(multiplier, [
      Vector({'a': 7, 'b': 6, 'sharedSigned': 0}, {'product': 42}),
      Vector({'sharedSigned': 1}, {'product': 2}),
    ]);
  }, skip: _iverilogUnavailableReason());

  test('unnamed MAC controls select independently in HDL', () async {
    final mac = CompressionTreeMultiplyAccumulate(
      Logic(width: 3),
      Logic(width: 3),
      Logic(width: 6),
      signedMultiplicand: StaticOrRuntimeParameter.fromLogic(Logic(),
          fallbackName: 'signedMultiplicand'),
      signedMultiplier: StaticOrRuntimeParameter.fromLogic(Logic(),
          fallbackName: 'signedMultiplier'),
      signedAddend: StaticOrRuntimeParameter.fromLogic(Logic(),
          fallbackName: 'signedAddend'),
    );
    await mac.build();

    final vectors = <Vector>[];
    for (final signA in [false, true]) {
      for (final signB in [false, true]) {
        for (final signC in [false, true]) {
          final expected = BigInt.from(7).toCondSigned(3, signed: signA) *
                  BigInt.from(6).toCondSigned(3, signed: signB) +
              BigInt.from(63).toCondSigned(6, signed: signC);
          vectors.add(Vector({
            'a': 7,
            'b': 6,
            'c': 63,
            'signedMultiplicand': signA ? 1 : 0,
            'signedMultiplier': signB ? 1 : 0,
            'signedAddend': signC ? 1 : 0,
          }, {
            'accumulate': expected.toUnsigned(mac.accumulate.width).toInt(),
          }));
        }
      }
    }
    SimCompare.checkIverilogVector(mac, vectors);
  }, skip: _iverilogUnavailableReason());
}

String? _iverilogUnavailableReason() {
  try {
    final result = Process.runSync('iverilog', const ['-V']);
    return result.exitCode == 0 ? null : 'Icarus Verilog is unavailable.';
  } on ProcessException {
    return 'Icarus Verilog is not installed.';
  }
}
