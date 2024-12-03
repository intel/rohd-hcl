// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplier_test.dart
// Test Multiplier and MultiplerAccumulate:  CompressionTree implementations
//
// 2024 August 7
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/evaluate_compressor.dart';
import 'package:rohd_hcl/src/arithmetic/partial_product_sign_extend.dart';
import 'package:test/test.dart';

/// The following routines are useful only during testing
extension TestMultiplierSignage on Multiplier {
  /// Return true if multiplicand [a] is truly signed (fixed or runtime)
  bool isSignedMultiplicand() => (selectSignedMultiplicand == null)
      ? signedMultiplicand
      : selectSignedMultiplicand!.value.isZero;

  /// Return true if multiplier [b] is truly signed (fixed or runtime)
  bool isSignedMultiplier() => (selectSignedMultiplier == null)
      ? signedMultiplier
      : selectSignedMultiplier!.value.isZero;

  /// Return true if accumulate result is truly signed (fixed or runtime)
  bool isSignedResult() => isSignedMultiplicand() | isSignedMultiplier();
}

/// The following routines are useful only during testing
extension TestMultiplierAccumulateSignage on MultiplyAccumulate {
  /// Return true if multiplicand [a] is truly signed (fixed or runtime)
  bool isSignedMultiplicand() => (selectSignedMultiplicand == null)
      ? signedMultiplicand
      : !selectSignedMultiplicand!.value.isZero;

  /// Return true if multiplier [b] is truly signed (fixed or runtime)
  bool isSignedMultiplier() => (selectSignedMultiplier == null)
      ? signedMultiplier
      : !selectSignedMultiplier!.value.isZero;

  /// Return true if addend [c] is truly signed (fixed or runtime)
  bool isSignedAddend() => (selectSignedAddend == null)
      ? signedAddend
      : !selectSignedAddend!.value.isZero;

  /// Return true if accumulate result is truly signed (fixed or runtime)
  bool isSignedResult() =>
      isSignedAddend() | isSignedMultiplicand() | isSignedMultiplier();
}

/// Simple multiplier to demonstrate instantiation of CompressionTreeMultiplier
class SimpleMultiplier extends Module {
  /// The output of the simple multiplier
  late final Logic product;

  /// Construct a simple multiplier with runtime sign operation
  SimpleMultiplier(
      Logic a, Logic b, Logic selSignedMultiplicand, Logic selSignedMultiplier)
      : super(name: 'my_test_module') {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    selSignedMultiplicand = addInput('multDSigned', selSignedMultiplicand);
    selSignedMultiplier = addInput('multMSigned', selSignedMultiplier);
    product = addOutput('product', width: a.width + b.width);

    final mult = CompressionTreeMultiplier(a, b, 4,
        selectSignedMultiplicand: selSignedMultiplicand,
        selectSignedMultiplier: selSignedMultiplier);
    product <= mult.product;
  }
}

// Inner test of a multipy accumulate unit
void checkMultiplyAccumulate(
    MultiplyAccumulate mod, BigInt bA, BigInt bB, BigInt bC) {
  final golden = bA * bB + bC;
  // ignore: invalid_use_of_protected_member
  mod.a.put(bA);
  // ignore: invalid_use_of_protected_member
  mod.b.put(bB);
  // ignore: invalid_use_of_protected_member
  mod.c.put(bC);

  final result = mod.accumulate.value
      .toBigInt()
      .toCondSigned(mod.accumulate.width, signed: mod.isSignedResult());

  expect(result, equals(golden));
}

void testMultiplyAccumulateSingle(int width, BigInt ibA, BigInt ibB, BigInt ibC,
    MultiplyAccumulate Function(Logic a, Logic b, Logic c) fn) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final c = Logic(name: 'c', width: width * 2);
  a.put(0);
  b.put(0);
  c.put(0);
  final mod = fn(a, b, c);
  test('single_W${width}_${mod.name}', () async {
    final multiplyOnly = mod is MutiplyOnly;
    await mod.build();
    final bA = ibA.toCondSigned(width, signed: mod.isSignedMultiplicand());
    final bB = ibB.toCondSigned(width, signed: mod.isSignedMultiplier());
    final bC = multiplyOnly
        ? BigInt.zero
        : ibC.toCondSigned(width * 2, signed: mod.isSignedAddend());

    checkMultiplyAccumulate(mod, bA, bB, bC);
  });
}

void testMultiplyAccumulateRandom(int width, int iterations,
    MultiplyAccumulate Function(Logic a, Logic b, Logic c) fn) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final c = Logic(name: 'c', width: width * 2);
  a.put(0);
  b.put(0);
  c.put(0);
  final mod = fn(a, b, c);
  test('random_W${width}_I${iterations}_${mod.name}', () {
    final multiplyOnly = mod is MutiplyOnly;

    final value = Random(47);
    for (var i = 0; i < iterations; i++) {
      final bA = value
          .nextLogicValue(width: width)
          .toBigInt()
          .toCondSigned(width, signed: mod.isSignedMultiplicand());
      final bB = value
          .nextLogicValue(width: width)
          .toBigInt()
          .toCondSigned(width, signed: mod.isSignedMultiplier());

      final bC = multiplyOnly
          ? BigInt.zero
          : value
              .nextLogicValue(width: width)
              .toBigInt()
              .toCondSigned(width, signed: mod.isSignedAddend());

      checkMultiplyAccumulate(mod, bA, bB, bC);
    }
  });
}

void testMultiplyAccumulateExhaustive(
    int width, MultiplyAccumulate Function(Logic a, Logic b, Logic c) fn) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final c = Logic(name: 'c', width: 2 * width);
  a.put(0);
  b.put(0);
  c.put(0);
  final mod = fn(a, b, c);
  test('exhaustive_W${width}_${mod.name}', () async {
    await mod.build();
    final multiplyOnly = mod is MutiplyOnly;

    for (var aa = 0; aa < (1 << width); ++aa) {
      for (var bb = 0; bb < (1 << width); ++bb) {
        for (var cc = 0; cc < (multiplyOnly ? 1 : (1 << (2 * width))); ++cc) {
          final bA = SignedBigInt.fromSignedInt(aa, width,
              signed: mod.isSignedMultiplicand());
          final bB = SignedBigInt.fromSignedInt(bb, width,
              signed: mod.isSignedMultiplier());
          final bC = multiplyOnly
              ? BigInt.zero
              : SignedBigInt.fromSignedInt(bb, width * 2,
                  signed: mod.isSignedAddend());
          checkMultiplyAccumulate(mod, bA, bB, bC);
        }
      }
    }
  });
}

typedef MultiplyAccumulateCallback = MultiplyAccumulate Function(
    Logic a, Logic b, Logic c);

typedef MultiplierCallback = Multiplier Function(Logic a, Logic b,
    {Logic? selectSignedMultiplicand, Logic? selectSignedMultiplier});

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  MultiplierCallback curryCompressionTreeMultiplier(int radix,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppTree,
      {PPGFunction ppGen = PartialProductGeneratorCompactRectSignExtension.new,
      bool signedMultiplicand = false,
      bool signedMultiplier = false,
      Logic? selectSignedMultiplicand,
      Logic? selectSignedMultiplier}) {
    String genName(Logic a, Logic b) => ppGen(
          a,
          b,
          RadixEncoder(radix),
          signedMultiplicand: signedMultiplicand,
          signedMultiplier: signedMultiplier,
          selectSignedMultiplicand:
              selectSignedMultiplicand != null ? Logic() : null,
          selectSignedMultiplier:
              selectSignedMultiplier != null ? Logic() : null,
        ).name;
    final signage = ' SelD=${(selectSignedMultiplicand != null) ? 1 : 0}'
        ' SelM=${(selectSignedMultiplier != null) ? 1 : 0}'
        ' SD=${signedMultiplicand ? 1 : 0}'
        ' SM=${signedMultiplier ? 1 : 0}';
    return (a, b, {selectSignedMultiplicand, selectSignedMultiplier}) =>
        CompressionTreeMultiplier(a, b, radix,
            ppTree: ppTree,
            ppGen: ppGen,
            signedMultiplicand: signedMultiplicand,
            signedMultiplier: signedMultiplier,
            selectSignedMultiplicand: selectSignedMultiplicand,
            selectSignedMultiplier: selectSignedMultiplier,
            name: 'Compression Tree Multiplier: '
                '${ppTree([Logic()], (a, b) => Logic()).name}'
                '$signage R${radix}_E${genName(a, b)}');
  }

  MultiplyAccumulateCallback curryMultiplierAsMultiplyAccumulate(
          int radix,
          ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
              ppTree,
          {PPGFunction ppGen =
              PartialProductGeneratorCompactRectSignExtension.new,
          bool signedMultiplicand = false,
          bool signedMultiplier = false,
          Logic? selectSignedMultiplicand,
          Logic? selectSignedMultiplier}) =>
      (a, b, c) => MutiplyOnly(
          a,
          b,
          c,
          signedMultiplicand: signedMultiplicand,
          signedMultiplier: signedMultiplier,
          selectSignedMultiplicand: selectSignedMultiplicand,
          selectSignedMultiplier: selectSignedMultiplier,
          curryCompressionTreeMultiplier(
            radix,
            ppTree,
            ppGen: ppGen,
            signedMultiplicand: signedMultiplicand,
            signedMultiplier: signedMultiplier,
            selectSignedMultiplicand: selectSignedMultiplicand,
            selectSignedMultiplier: selectSignedMultiplier,
          ));

  MultiplyAccumulateCallback curryMultiplyAccumulate(
    int radix,
    ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppTree, {
    PPGFunction ppGen = PartialProductGeneratorCompactRectSignExtension.new,
    bool signedMultiplicand = false,
    bool signedMultiplier = false,
    bool signedAddend = false,
    Logic? selectSignedMultiplicand,
    Logic? selectSignedMultiplier,
    Logic? selectSignedAddend,
  }) {
    String genName(Logic a, Logic b) => ppGen(
          a,
          b,
          RadixEncoder(radix),
          signedMultiplicand: signedMultiplicand,
          signedMultiplier: signedMultiplier,
          selectSignedMultiplicand:
              selectSignedMultiplicand != null ? Logic() : null,
          selectSignedMultiplier:
              selectSignedMultiplier != null ? Logic() : null,
        ).name;
    final signage = ' SelD=${(selectSignedMultiplicand != null) ? 1 : 0}'
        ' SelM=${(selectSignedMultiplier != null) ? 1 : 0}'
        ' SD=${signedMultiplicand ? 1 : 0}'
        ' SM=${signedMultiplier ? 1 : 0}';

    return (a, b, c) => CompressionTreeMultiplyAccumulate(a, b, c, radix,
        ppTree: ppTree,
        ppGen: ppGen,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier,
        signedAddend: signedAddend,
        selectSignedMultiplicand: selectSignedMultiplicand,
        selectSignedMultiplier: selectSignedMultiplier,
        selectSignedAddend: selectSignedAddend,
        name: 'Compression Tree MAC: ${ppTree.call([
              Logic()
            ], (a, b) => Logic()).name}'
            ' $signage R$radix E${genName(a, b)}');
  }

  group('Compression Tree Multiplier: curried random radix/width', () {
    for (final signedTest in [false, true]) {
      for (final signedOperands in [false, true]) {
        final Logic? signedSelect;
        if (signedOperands) {
          signedSelect = Logic()..put(signedTest ? 1 : 0);
        } else {
          signedSelect = null;
        }
        for (final radix in [2, 4]) {
          for (final width in [3, 4]) {
            for (final ppTree in [KoggeStone.new]) {
              testMultiplyAccumulateRandom(
                  width,
                  10,
                  curryMultiplierAsMultiplyAccumulate(radix, ppTree,
                      ppGen: PartialProductGeneratorStopBitsSignExtension.new,
                      signedMultiplicand: !signedOperands && signedTest,
                      signedMultiplier: !signedOperands && signedTest,
                      selectSignedMultiplicand: signedSelect,
                      selectSignedMultiplier: signedSelect));
            }
          }
        }
      }
    }
  });

  test('Compression Tree Multiplier: pipelined test', () async {
    final clk = SimpleClockGenerator(10).clk;
    final Logic? signedSelect;
    signedSelect = Logic()..put(1);
    const width = 5;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final bA = BigInt.from(-10).toSigned(width);
    final bB = BigInt.from(-10).toSigned(width);
    final mod = CompressionTreeMultiplier(a, b, 4,
        clk: clk,
        selectSignedMultiplicand: signedSelect,
        selectSignedMultiplier: signedSelect);
    unawaited(Simulator.run());
    a.put(bA);
    b.put(bB);

    await clk.nextNegedge;
    final golden = bA * bB;
    a.put(0);
    b.put(0);

    final result = mod.product.value.toBigInt().toSigned(mod.product.width);
    expect(result, equals(golden));
    await Simulator.endSimulation();
  });

  group('Compression Tree Multiplier: curried random sign/select/extension',
      () {
    for (final signedTest in [false, true]) {
      for (final signedOperands in [false, true]) {
        final Logic? signedSelect;
        if (signedOperands) {
          signedSelect = Logic()..put(signedTest ? 1 : 0);
        } else {
          signedSelect = null;
        }
        for (final radix in [2, 4]) {
          for (final ppTree in [KoggeStone.new]) {
            for (final ppGen in [
              PartialProductGeneratorCompactSignExtension.new,
              PartialProductGeneratorCompactRectSignExtension.new,
              PartialProductGeneratorStopBitsSignExtension.new,
              PartialProductGeneratorBruteSignExtension.new
            ]) {
              for (final width in [1 + log2Ceil(radix)]) {
                testMultiplyAccumulateRandom(
                    width,
                    10,
                    curryMultiplierAsMultiplyAccumulate(radix, ppTree,
                        ppGen: ppGen,
                        signedMultiplicand: !signedOperands && signedTest,
                        signedMultiplier: !signedOperands && signedTest,
                        selectSignedMultiplicand: signedSelect,
                        selectSignedMultiplier: signedSelect));
              }
            }
          }
        }
      }
    }
  });

  group('Compression Tree MAC: random + signed/radix/width', () {
    for (final signedTest in [false, true]) {
      for (final signedOperands in [false, true]) {
        final Logic? signedSelect;
        if (signedOperands) {
          signedSelect = Logic()..put(signedTest ? 1 : 0);
        } else {
          signedSelect = null;
        }
        for (final radix in [2, 4]) {
          for (final width in [3, 4]) {
            for (final ppTree in [KoggeStone.new]) {
              testMultiplyAccumulateRandom(
                  width,
                  10,
                  curryMultiplyAccumulate(
                    radix,
                    ppTree,
                    signedMultiplicand: !signedOperands && signedTest,
                    signedMultiplier: !signedOperands && signedTest,
                    signedAddend: !signedOperands && signedTest,
                    selectSignedMultiplicand: signedSelect,
                    selectSignedMultiplier: signedSelect,
                    selectSignedAddend: signedSelect,
                  ));
            }
          }
        }
      }
    }
  });

  test('Trim Curried Test of Compression Tree MAC', () async {
    final Logic? signedSelect;
    signedSelect = Logic()..put(1);
    const width = 5;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: width * 2);
    final bA = BigInt.from(0).toSigned(width);
    final bB = BigInt.from(0).toSigned(width);
    final bC = BigInt.from(-1).toSigned(width * 2);
    a.put(bA);
    b.put(bB);
    c.put(bC);
    final mod = curryMultiplyAccumulate(
      4,
      KoggeStone.new,
      selectSignedMultiplicand: signedSelect,
      selectSignedMultiplier: signedSelect,
      selectSignedAddend: signedSelect,
    )(a, b, c);

    checkMultiplyAccumulate(mod, bA, bB, bC);
  });

  test('Compression Tree MAC: pipelined test', () async {
    final clk = SimpleClockGenerator(10).clk;
    final Logic? signedSelect;
    signedSelect = Logic()..put(1);
    const width = 5;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: width * 2);
    final bA = BigInt.from(0).toSigned(width);
    final bB = BigInt.from(0).toSigned(width);
    final bC = BigInt.from(-512).toSigned(width * 2);
    a.put(0);
    b.put(0);
    c.put(0);

    final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4,
        clk: clk,
        selectSignedMultiplicand: signedSelect,
        selectSignedMultiplier: signedSelect,
        selectSignedAddend: signedSelect);
    unawaited(Simulator.run());
    a.put(bA);
    b.put(bB);
    c.put(bC);

    await clk.nextNegedge;
    final golden = bA * bB + bC;
    a.put(0);
    b.put(0);
    c.put(0);

    final result =
        mod.accumulate.value.toBigInt().toSigned(mod.accumulate.width);
    expect(result, equals(golden));
    await Simulator.endSimulation();
  });

  test('single multiplier', () async {
    const width = 8;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    const av = 12;
    const bv = 13;
    for (final signed in [true, false]) {
      for (final useSignedLogic in [true, false]) {
        final bA = SignedBigInt.fromSignedInt(av, width, signed: signed);
        final bB = SignedBigInt.fromSignedInt(bv, width, signed: signed);

        final Logic? signedSelect;

        if (useSignedLogic) {
          signedSelect = Logic()..put(signed ? 1 : 0);
        } else {
          signedSelect = null;
        }

        // Set these so that printing inside module build will have Logic values
        a.put(bA);
        b.put(bB);

        final mod = CompressionTreeMultiplier(a, b, 4,
            signedMultiplier: !useSignedLogic && signed,
            selectSignedMultiplicand: signedSelect,
            selectSignedMultiplier: signedSelect);
        await mod.build();
        mod.generateSynth();
        final golden = bA * bB;
        final result = mod.isSignedResult()
            ? mod.product.value.toBigInt().toSigned(mod.product.width)
            : mod.product.value.toBigInt().toUnsigned(mod.product.width);
        expect(result, equals(golden));
      }
    }
  });

  test('trivial instantiated multiplier', () async {
    const dataWidth = 5;
    final av = BigInt.from(-16).toSigned(dataWidth);
    final bv = BigInt.from(-6).toSigned(dataWidth);

    final multA = Logic(name: 'multA', width: dataWidth);
    final multB = Logic(name: 'multB', width: dataWidth);

    final signedOperands = Logic(name: 'signedOperands');
    // ignore: cascade_invocations
    signedOperands.put(1);
    multA.put(av);
    multB.put(bv);

    final mod = curryMultiplierAsMultiplyAccumulate(4, KoggeStone.new,
        selectSignedMultiplicand: signedOperands,
        selectSignedMultiplier: signedOperands)(multA, multB, Const(0));

    checkMultiplyAccumulate(mod, av, bv, BigInt.zero);
  });

  test('single mac', () async {
    const width = 8;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: 2 * width);
    const av = 10;
    const bv = 6;
    const cv = 0;
    for (final signed in [false, true]) {
      final bA = SignedBigInt.fromSignedInt(av, width, signed: signed);
      final bB = SignedBigInt.fromSignedInt(bv, width, signed: signed);
      final bC = SignedBigInt.fromSignedInt(cv, width * 2, signed: signed);

      final signedOperands = Logic(name: 'signedOperands');
      // ignore: cascade_invocations
      signedOperands.put(1);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      c.put(bC);

      final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4,
          selectSignedMultiplicand: signedOperands,
          selectSignedMultiplier: signedOperands,
          selectSignedAddend: signedOperands);
      checkMultiplyAccumulate(mod, bA, bB, bC);
    }
  });

  test('single rectangular mac', () async {
    const widthA = 8;
    const widthB = 8;
    const widthC = widthA + widthB;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);
    final c = Logic(name: 'c', width: widthC);

    const av = 10;
    const bv = 0;
    const cv = 0;
    for (final signed in [true, false]) {
      final bA = SignedBigInt.fromSignedInt(av, widthA, signed: signed);
      final bB = SignedBigInt.fromSignedInt(bv, widthB, signed: signed);
      final bC = SignedBigInt.fromSignedInt(cv, widthC, signed: signed);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      c.put(bC);

      final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4,
          signedMultiplicand: signed,
          signedMultiplier: signed,
          signedAddend: signed);
      checkMultiplyAccumulate(mod, bA, bB, bC);
    }
  });
  test('trivial compression tree multiply-accumulate test', () async {
    const widthA = 6;
    const widthB = 6;
    const radix = 8;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);
    final c = Logic(name: 'c', width: widthA + widthB);

    a.put(15);
    b.put(3);
    c.put(5);

    final multiplier = CompressionTreeMultiplyAccumulate(a, b, c, radix,
        signedMultiplier: true);
    final accumulate = multiplier.accumulate;
    expect(accumulate.value.toBigInt(), equals(BigInt.from(15 * 3 + 5)));
  });

  test('trivial compression MAC signed', () async {
    const widthA = 6;
    const widthB = 6;
    const widthC = widthA + widthB;
    const radix = 4;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);
    final c = Logic(name: 'c', width: widthC);

    const av = 10;
    const bv = 6;
    const cv = 0;
    for (final signed in [false, true]) {
      final bA = SignedBigInt.fromSignedInt(av, widthA, signed: signed);
      final bB = SignedBigInt.fromSignedInt(bv, widthB, signed: signed);
      final bC = SignedBigInt.fromSignedInt(cv, widthC, signed: signed);

      final golden = bA * bB + bC;

      a.put(bA);
      b.put(bB);
      c.put(bC);

      final multiplier = CompressionTreeMultiplyAccumulate(a, b, c, radix,
          signedMultiplicand: signed, signedMultiplier: signed);
      final accumulate = multiplier.accumulate;
      expect(accumulate.value.toBigInt(), equals(golden));
    }
  });

  test('setting PPG', () async {
    const width = 8;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final select = Logic(name: 'select');
    // ignore: cascade_invocations
    select.put(0);
    a.put(6);
    b.put(3);

    final ppG0 = PartialProductGeneratorCompactRectSignExtension(
        a, b, RadixEncoder(4),
        signedMultiplicand: true, signedMultiplier: true);

    final bit_0_5 = ppG0.getAbsolute(0, 5);
    expect(bit_0_5.value, equals(LogicValue.one));
    ppG0.setAbsolute(0, 5, Const(0));
    expect(ppG0.getAbsolute(0, 5).value, equals(LogicValue.zero));

    final bit_1_2 = ppG0.getAbsolute(1, 2);
    expect(bit_1_2.value, equals(LogicValue.zero));
    ppG0.setAbsolute(1, 2, Const(1));
    expect(ppG0.getAbsolute(1, 2).value, equals(LogicValue.one));

    final bits_3_678 = ppG0.getAbsoluteAll(3, [6, 7, 8]);

    expect(bits_3_678.swizzle().value, equals(Const(0, width: 3).value));

    ppG0.setAbsoluteAll(3, 6, [Const(1), Const(1), Const(0)]);

    expect(ppG0.getAbsoluteAll(3, [6, 7, 8]).swizzle().value,
        equals([Const(1), Const(1), Const(0)].swizzle().value));

    ppG0
      ..muxAbsolute(0, 4, select, Const(0))
      ..muxAbsoluteAll(1, 9, select, [Const(1), Const(0)]);

    expect(ppG0.getAbsolute(0, 4).value, equals(Const(1).value));
    expect(ppG0.getAbsolute(1, 9).value, equals(Const(0).value));
    expect(ppG0.getAbsolute(1, 10).value, equals(Const(1).value));

    select.put(1);
    expect(ppG0.getAbsolute(0, 4).value, equals(Const(0).value));
    expect(ppG0.getAbsolute(1, 9).value, equals(Const(1).value));
    expect(ppG0.getAbsolute(1, 10).value, equals(Const(0).value));

    final cc = ColumnCompressor(ppG0);
    const expectedRep = '''
	pp3,15	pp3,14	pp3,13	pp3,12	pp3,11	pp3,10	pp3,9	pp3,8	pp3,7	pp3,6	pp3,5	pp2,4	pp2,3	pp1,2	pp1,1	pp0,0
			pp2,13	pp2,12	pp1,11	pp2,10	pp2,9	pp2,8	pp2,7	pp2,6	pp2,5	pp0,4	pp0,3	pp0,2	pp0,1	
					pp2,11	pp1,10	pp1,9	pp1,8	pp1,7	pp1,6	pp1,5	pp1,4	pp1,3			
						pp0,10	pp0,9	pp0,8	pp0,7	pp0,6	pp0,5					
''';
    expect(cc.representation(), equals(expectedRep));

    final (v, ts) = cc.evaluate(printOut: true);

    const expectedEval = '''
       15      14      13      12      11      10       9       8       7       6       5       4       3       2       1       0
        1       I       0       0       0       0       0       0       1       1       0       0       0       1       1       0        = 49350 (-16186)
                        1       I       1       0       0       0       0       0       0       0       1       0       0                = 14344 (14344)
                                        0       i       1       0       0       0       0       1       1                                = 536 (536)
                                                i       S       S       1       1       0                                                = 960 (960)
p       1       1       1       1       1       1       1       0       1       0       1       0       0       1       1       0        = 65190 (-346)''';
    expect(ts.toString(), equals(expectedEval));
  });
}
