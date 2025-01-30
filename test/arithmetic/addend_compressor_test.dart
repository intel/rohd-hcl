// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// addend_compressor_test.dart
// Tests for the select interface of Booth encoding
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/evaluate_compressor.dart';
import 'package:rohd_hcl/src/arithmetic/evaluate_partial_product.dart';
import 'package:rohd_hcl/src/arithmetic/partial_product_sign_extend.dart';
import 'package:test/test.dart';

/// This extension will eventually move to ROHD once it is proven useful
extension LogicValueMajority on LogicValue {
  /// Compute the unary majority on LogicValue
  bool majority() {
    if (!isValid) {
      return false;
    }
    final zero = LogicValue.filled(width, LogicValue.zero);
    var shiftedValue = this;
    var result = 0;
    while (shiftedValue != zero) {
      result += (shiftedValue[0] & LogicValue.one == LogicValue.one) ? 1 : 0;
      shiftedValue >>>= 1;
    }
    return result > (width ~/ 2);
  }

  /// Compute the first One find operation on LogicValue, returning its position
  int? firstOne() {
    if (!isValid) {
      return null;
    }
    var shiftedValue = this;
    var result = 0;
    while (shiftedValue[0] != LogicValue.one) {
      result++;
      if (result == width) {
        return null;
      }
      shiftedValue >>>= 1;
    }
    return result;
  }

  /// Return the populationCount of 1s in a LogicValue
  int popCount() {
    final r = RegExp('1');
    final matches = r.allMatches(bitString);
    return matches.length;
  }
}

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

    final pp = PartialProductGenerator(a, b, encoder,
        signedMultiplicand: signed, signedMultiplier: signed);
    CompactRectSignExtension(pp).signExtend();

    compressor = ColumnCompressor(pp, clk: clk);
    compressor.compress();
    final r0 = addOutput('r0', width: compressor.columns.length);
    final r1 = addOutput('r1', width: compressor.columns.length);

    r0 <= compressor.extractRow(0);
    r1 <= compressor.extractRow(1);
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('4-2 compressor', () {
    final bits = Logic(width: 4);
    final cin = [Logic()];

    final inputs = [
      for (var i = 0; i < bits.width; i++)
        CompressTerm(null, CompressTermType.pp, bits[i], [], 0, 0)
    ];
    final carryInputs = [
      for (var i = 0; i < cin.length; i++)
        CompressTerm(null, CompressTermType.pp, cin[i], [], 0, 0)
    ];

    final compressor = Compressor4(inputs, carryInputs);

    for (var cVal = 0; cVal < 2; cVal++) {
      cin[0].put(cVal);

      for (var val = 0; val < pow(2, 4) - 1; val++) {
        bits.put(val);
        final count = compressor.sum.value.toInt() +
            2 *
                (compressor.carry.value.toInt() +
                    compressor.cout.value.toInt());
        final bitCount =
            bits.value.popCount() + ((cin[0].value == LogicValue.one) ? 1 : 0);
        expect(count, equals(bitCount));
      }
    }
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
  test('Column Compressor: single compressor 4:2 evaluate', () {
    const widthX = 5;
    const widthY = 5;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    const av = 12;
    const bv = 13;
    for (final signed in [true]) {
      final bA = SignedBigInt.fromSignedInt(av, widthX, signed: signed);
      final bB = SignedBigInt.fromSignedInt(bv, widthY, signed: signed);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      const radix = 2;
      final encoder = RadixEncoder(radix);
      for (final useSelect in [false]) {
        final selectSignedMultiplicand = useSelect ? Logic() : null;
        final selectSignedMultiplier = useSelect ? Logic() : null;
        if (useSelect) {
          selectSignedMultiplicand!.put(signed ? 1 : 0);
          selectSignedMultiplier!.put(signed ? 1 : 0);
        }
        final pp = PartialProductGenerator(a, b, encoder,
            signedMultiplicand: !useSelect & signed,
            signedMultiplier: !useSelect & signed,
            selectSignedMultiplicand: selectSignedMultiplicand,
            selectSignedMultiplier: selectSignedMultiplier);
        CompactRectSignExtension(pp).signExtend();

        expect(pp.evaluate(), equals(bA * bB));
        final compressor = ColumnCompressor(pp, use42Compressors: true)
          ..compress();
        expect(compressor.evaluate().$1, equals(bA * bB));
      }
    }
  });
}
