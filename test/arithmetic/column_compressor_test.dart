// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// column_compressor_test.dart
// Tests for the column compressor.
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/multiplier_components/evaluate_compressor.dart';
import 'package:rohd_hcl/src/arithmetic/multiplier_components/evaluate_partial_product.dart';
import 'package:test/test.dart';

/// This [CompressorTestMod] module is used to test instantiation, where we can
/// catch trace errors (IO not added) not found in a simple test instantiation.
class CompressorTestMod extends Module {
  late final PartialProductGeneratorBase pp;

  late final ColumnCompressor compressor;

  Logic get r0 => output('r0');

  Logic get r1 => output('r1');

  CompressorTestMod(Logic ia, Logic ib, RadixEncoder encoder, Logic? iclk,
      {bool signed = true})
      : super(name: 'compressor_test_mod') {
    final a = addInput('a', ia, width: ia.width);
    final b = addInput('b', ib, width: ib.width);
    Logic? clk;
    if (iclk != null) {
      clk = addInput('clk', iclk);
    }

    final pp = PartialProduct(a, b, encoder,
        signedMultiplicand: signed, signedMultiplier: signed);
    CompactRectSignExtension(pp.array).signExtend();

    pp.generateOutputs();

    compressor = ColumnCompressor(pp.rows, pp.rowShift, clk: clk);
    final r0 = addOutput('r0', width: compressor.columns.length);
    final r1 = addOutput('r1', width: compressor.columns.length);

    r0 <= compressor.add0;
    r1 <= compressor.add1;
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('Column Compressor: evaluate flopped', () async {
    final clk = SimpleClockGenerator(10).clk;
    const widthX = 6;
    const widthY = 6;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    var av = 3;
    const bv = 6;
    var bA = SignedBigInt.fromSignedInt(av, widthX, signed: true);
    final bB = SignedBigInt.fromSignedInt(bv, widthY, signed: true);

    // Set these so that printing inside module build will have Logic values
    a.put(bA);
    b.put(bB);
    const radix = 2;
    final encoder = RadixEncoder(radix);

    final compressorTestMod = CompressorTestMod(a, b, encoder, clk);
    await compressorTestMod.build();

    unawaited(Simulator.run());

    await clk.nextNegedge;
    expect(compressorTestMod.compressor.evaluate().$1,
        equals(BigInt.from(av * bv)));
    av = 4;
    bA = BigInt.from(av).toSigned(widthX);
    a.put(bA);
    await clk.nextNegedge;
    expect(compressorTestMod.compressor.evaluate().$1,
        equals(BigInt.from(av * bv)));
    await Simulator.endSimulation();
  });

  test('Column Compressor: single compressor evaluate', () async {
    const widthX = 3;
    const widthY = 3;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    const av = -3;
    const bv = -3;
    for (final signed in [true, false]) {
      final bA = SignedBigInt.fromSignedInt(av, widthX, signed: signed);
      final bB = SignedBigInt.fromSignedInt(bv, widthY, signed: signed);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      const radix = 4;
      final encoder = RadixEncoder(radix);
      for (final useSelect in [false, true]) {
        final selectSignedMultiplicand =
            useSelect ? Logic(name: 'multiplicand') : null;
        final selectSignedMultiplier =
            useSelect ? Logic(name: 'multiplier') : null;
        if (useSelect) {
          selectSignedMultiplicand!.put(signed ? 1 : 0);
          selectSignedMultiplier!.put(signed ? 1 : 0);
        }
        final pp = PartialProduct(
          a,
          b,
          encoder,
          signedMultiplicand: StaticOrDynamicParameter(
              name: 'signedMultiplicand',
              staticConfig: !useSelect & signed,
              dynamicConfig: selectSignedMultiplicand),
          signedMultiplier: StaticOrDynamicParameter(
              name: 'signedMultiplier',
              staticConfig: !useSelect & signed,
              dynamicConfig: selectSignedMultiplier),
        );
        CompactRectSignExtension(pp.array).signExtend();

        pp.generateOutputs();
        expect(pp.array.evaluate(), equals(bA * bB));
        final compressor =
            ColumnCompressor(pp.rows, pp.rowShift, dontCompress: true);
        expect(compressor.evaluate().$1, equals(bA * bB));
        compressor.compress();
        expect(compressor.evaluate().$1, equals(bA * bB));
      }
    }
  });
}
