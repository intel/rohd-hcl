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

/// Simple multiplier to demonstrate instantiation of CompressionTreeMultiplier
class SimpleMultiplier extends Module {
  /// The output of the simple multiplier
  late final Logic product;

  /// Construct a simple multiplier with runtime sign operation
  SimpleMultiplier(Logic a, Logic b, Logic multASigned)
      : super(name: 'my_test_module') {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    multASigned = addInput('multASigned', multASigned);
    product = addOutput('product', width: a.width + b.width);

    final mult = CompressionTreeMultiplier(a, b, 4, selectSigned: multASigned);
    product <= mult.product;
  }
}

// Inner test of a multipy accumulate unit
void checkMultiplyAccumulate(
    MultiplyAccumulate mod, BigInt bA, BigInt bB, BigInt bC,
    {bool signedTest = false}) {
  final golden = bA * bB + bC;
  // ignore: invalid_use_of_protected_member
  mod.a.put(bA);
  // ignore: invalid_use_of_protected_member
  mod.b.put(bB);
  // ignore: invalid_use_of_protected_member
  mod.c.put(bC);

  final result = signedTest
      ? mod.accumulate.value.toBigInt().toSigned(mod.accumulate.width)
      : mod.accumulate.value.toBigInt().toUnsigned(mod.accumulate.width);
  expect(result, equals(golden));
}

// Random testing of a mutiplier or multiplier/accumulate unit
void testMultiplyAccumulateRandom(int width, int iterations,
    MultiplyAccumulate Function(Logic a, Logic b, Logic c) fn,
    {bool signedTest = false}) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final c = Logic(name: 'c', width: width * 2);
  a.put(0);
  b.put(0);
  c.put(0);
  final mod = fn(a, b, c);
  test('random_${mod.name}_S${mod.signed}_W${width}_I$iterations', () async {
    final multiplyOnly = mod is MutiplyOnly;
    await mod.build();
    final value = Random(47);
    for (var i = 0; i < iterations; i++) {
      final bA = signedTest
          ? value.nextLogicValue(width: width).toBigInt().toSigned(width)
          : value.nextLogicValue(width: width).toBigInt().toUnsigned(width);
      final bB = signedTest
          ? value.nextLogicValue(width: width).toBigInt().toSigned(width)
          : value.nextLogicValue(width: width).toBigInt().toUnsigned(width);
      final bC = multiplyOnly
          ? BigInt.zero
          : signedTest
              ? value.nextLogicValue(width: width).toBigInt().toSigned(width)
              : value.nextLogicValue(width: width).toBigInt().toUnsigned(width);
      checkMultiplyAccumulate(mod, bA, bB, bC, signedTest: signedTest);
    }
  });
}

// Exhaustive testing of a mutiplier or multiplier/accumulate unit
void testMultiplyAccumulateExhaustive(
    int width, MultiplyAccumulate Function(Logic a, Logic b, Logic c) fn,
    {bool signedTest = false}) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final c = Logic(name: 'c', width: 2 * width);
  a.put(0);
  b.put(0);
  c.put(0);
  final mod = fn(a, b, c);
  test('exhaustive_${mod.name}_S${mod.signed}_W$width', () async {
    await mod.build();
    final multiplyOnly = mod is MutiplyOnly;

    final cLimit = multiplyOnly ? 1 : (1 << (2 * width));

    for (var aa = 0; aa < (1 << width); ++aa) {
      for (var bb = 0; bb < (1 << width); ++bb) {
        for (var cc = 0; cc < cLimit; ++cc) {
          final bA = signedTest
              ? BigInt.from(aa).toSigned(width)
              : BigInt.from(aa).toUnsigned(width);
          final bB = signedTest
              ? BigInt.from(bb).toSigned(width)
              : BigInt.from(bb).toUnsigned(width);
          final bC = multiplyOnly
              ? BigInt.zero
              : signedTest
                  ? BigInt.from(cc).toSigned(2 * width)
                  : BigInt.from(cc).toUnsigned(2 * width);
          checkMultiplyAccumulate(mod, bA, bB, bC, signedTest: signedTest);
        }
      }
    }
  });
}

typedef MultiplyAccumulateCallback = MultiplyAccumulate Function(
    Logic a, Logic b, Logic c);

typedef MultiplierCallback = Multiplier Function(Logic a, Logic b,
    {Logic? selectSigned});

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  MultiplierCallback curryCompressionTreeMultiplier(
          int radix,
          ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
              ppTree,
          {PartialProductGenerator Function(Logic, Logic, RadixEncoder,
                  {required bool signed, Logic? selectSigned})
              ppGen = PartialProductGeneratorCompactRectSignExtension.new,
          bool signed = false,
          Logic? selectSigned}) =>
      (a, b, {selectSigned}) => CompressionTreeMultiplier(a, b, radix,
          selectSigned: selectSigned,
          ppTree: ppTree,
          ppGen: ppGen,
          signed: signed,
          name: 'Compression Tree Multiplier: ${ppTree.call([
                Logic()
              ], (a, b, {selectSigned}) => Logic()).name}'
              ' Sel=${selectSigned != null}R${radix}_E'
              '${ppGen.call(a, b, RadixEncoder(radix), signed: signed).name}');

  MultiplyAccumulateCallback curryMultiplierAsMultiplyAccumulate(
          int radix,
          ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
              ppTree,
          {PartialProductGenerator Function(Logic, Logic, RadixEncoder,
                  {required bool signed, Logic? selectSigned})
              ppGen = PartialProductGeneratorCompactRectSignExtension.new,
          bool signed = false,
          Logic? selectSign}) =>
      (a, b, c) => MutiplyOnly(
          a,
          b,
          c,
          selectSigned: selectSign,
          curryCompressionTreeMultiplier(radix, ppTree,
              ppGen: ppGen, selectSigned: selectSign, signed: signed));

  MultiplyAccumulateCallback curryMultiplyAccumulate(
    int radix,
    ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppTree, {
    PartialProductGenerator Function(Logic, Logic, RadixEncoder,
            {required bool signed, Logic? selectSigned})
        ppGen = PartialProductGeneratorCompactRectSignExtension.new,
    bool signed = false,
    Logic? selectSign,
  }) =>
      (a, b, c) => CompressionTreeMultiplyAccumulate(a, b, c, radix,
          selectSigned: selectSign,
          ppTree: ppTree,
          ppGen: ppGen,
          signed: signed,
          name: 'Compression Tree MAC: ${ppTree.call([
                Logic()
              ], (a, b) => Logic()).name}'
              ' Sel=${selectSign != null}R${radix}_E'
              '${ppGen.call(a, b, RadixEncoder(radix), signed: signed).name}');

  group('Compression Tree Multiplier: curried random radix/width', () {
    for (final signedTest in [false, true]) {
      for (final signedOperands in [false, true]) {
        final Logic? signedSelect;
        if (signedOperands) {
          signedSelect = Logic()..put(signedTest ? 1 : 0);
        } else {
          signedSelect = null;
        }
        for (final radix in [2, 16]) {
          for (final width in [5, 6]) {
            for (final ppTree in [KoggeStone.new]) {
              testMultiplyAccumulateRandom(
                  width,
                  10,
                  curryMultiplierAsMultiplyAccumulate(radix, ppTree,
                      ppGen: PartialProductGeneratorStopBitsSignExtension.new,
                      signed: !signedOperands && signedTest,
                      selectSign: signedSelect),
                  signedTest: signedTest);
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
        clk: clk, selectSigned: signedSelect);
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

  group('Compression Tree Multiplier: curried exhaustive sign/select/extension',
      () {
    for (final signedTest in [false, true]) {
      for (final signedOperands in [false, true]) {
        final Logic? signedSelect;
        if (signedOperands) {
          signedSelect = Logic()..put(signedTest ? 1 : 0);
        } else {
          signedSelect = null;
        }
        for (final radix in [4]) {
          for (final ppTree in [KoggeStone.new]) {
            for (final ppGen in [
              PartialProductGeneratorCompactSignExtension.new,
              PartialProductGeneratorCompactRectSignExtension.new,
              PartialProductGeneratorStopBitsSignExtension.new,
              PartialProductGeneratorBruteSignExtension.new
            ]) {
              for (final width in [1 + log2Ceil(radix)]) {
                testMultiplyAccumulateExhaustive(
                    width,
                    curryMultiplierAsMultiplyAccumulate(radix, ppTree,
                        ppGen: ppGen,
                        signed: !signedOperands && signedTest,
                        selectSign: signedSelect),
                    signedTest: signedTest);
              }
            }
          }
        }
      }
    }
  });

  test('Trim Curried Test of Compression Tree Multiplier', () async {
    final Logic? signedSelect;
    signedSelect = Logic()..put(1);
    const width = 5;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: width * 2 + 1);
    a.put(0);
    b.put(0);
    c.put(0);
    final bA = BigInt.from(-10).toSigned(width);
    final bB = BigInt.from(-10).toSigned(width);
    a.put(bA);
    b.put(bB);
    final mod = curryMultiplierAsMultiplyAccumulate(4, KoggeStone.new,
        ppGen: PartialProductGeneratorCompactSignExtension.new,
        selectSign: signedSelect)(a, b, c);
    checkMultiplyAccumulate(mod, bA, bB, BigInt.zero, signedTest: true);
  });

  group('Compression Tree Multiplier Accumulate: random radix/width', () {
    for (final signedTest in [false, true]) {
      for (final signedOperands in [false, true]) {
        final Logic? signedSelect;
        if (signedOperands) {
          signedSelect = Logic()..put(signedTest ? 1 : 0);
        } else {
          signedSelect = null;
        }
        for (final radix in [4, 16]) {
          for (final width in [5, 6]) {
            for (final ppTree in [KoggeStone.new]) {
              testMultiplyAccumulateRandom(
                  width,
                  10,
                  curryMultiplyAccumulate(radix, ppTree,
                      signed: !signedOperands && signedTest,
                      selectSign: signedSelect),
                  signedTest: signedTest);
            }
          }
        }
      }
    }
  });

  group(
      'Compression Tree Multiplier Accumulate: '
      'curried exhaustive sign/select/extension', () {
    for (final signedTest in [false, true]) {
      for (final signedOperands in [false, true]) {
        final Logic? signedSelect;
        if (signedOperands) {
          signedSelect = Logic()..put(signedTest ? 1 : 0);
        } else {
          signedSelect = null;
        }
        for (final radix in [4]) {
          for (final ppTree in [KoggeStone.new]) {
            for (final ppGen in [
              PartialProductGeneratorCompactSignExtension.new,
              PartialProductGeneratorCompactRectSignExtension.new,
              PartialProductGeneratorStopBitsSignExtension.new,
              PartialProductGeneratorBruteSignExtension.new
            ]) {
              for (final width in [1 + log2Ceil(radix)]) {
                testMultiplyAccumulateExhaustive(
                    width,
                    curryMultiplyAccumulate(radix, ppTree,
                        ppGen: ppGen,
                        signed: !signedOperands && signedTest,
                        selectSign: signedSelect),
                    signedTest: signedTest);
              }
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
    final c = Logic(name: 'c', width: width * 2 + 1);
    final bA = BigInt.from(-10).toSigned(width);
    final bB = BigInt.from(-10).toSigned(width);
    final bC = BigInt.from(0).toSigned(width);
    a.put(bA);
    b.put(bB);
    c.put(bC);
    final mod = curryMultiplyAccumulate(4, KoggeStone.new,
        ppGen: PartialProductGeneratorCompactSignExtension.new,
        selectSign: signedSelect)(a, b, c);
    checkMultiplyAccumulate(mod, bA, bB, bC, signedTest: true);
  });

  test('Compression Tree MAC: pipelined test', () async {
    final clk = SimpleClockGenerator(10).clk;
    final Logic? signedSelect;
    signedSelect = Logic()..put(1);
    const width = 5;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: width * 2 + 1);
    final bA = BigInt.from(-10).toSigned(width);
    final bB = BigInt.from(-10).toSigned(width);
    final bC = BigInt.from(100).toSigned(width);

    final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4,
        clk: clk, selectSigned: signedSelect);
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
        final bA = signed
            ? BigInt.from(av).toSigned(width)
            : BigInt.from(av).toUnsigned(width);
        final bB = signed
            ? BigInt.from(bv).toSigned(width)
            : BigInt.from(bv).toUnsigned(width);

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
            signed: !useSignedLogic && signed, selectSigned: signedSelect);
        await mod.build();
        mod.generateSynth();
        final golden = bA * bB;
        final result = mod.signed
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
        selectSign: signedOperands)(multA, multB, Const(0));

    checkMultiplyAccumulate(mod, av, bv, BigInt.zero, signedTest: true);
  });

  test('single mac', () async {
    const width = 8;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: 2 * width + 1);
    const av = 0;
    const bv = 0;
    const cv = -512;
    for (final signed in [true, false]) {
      final bA = signed
          ? BigInt.from(av).toSigned(width)
          : BigInt.from(av).toUnsigned(width);
      final bB = signed
          ? BigInt.from(bv).toSigned(width)
          : BigInt.from(bv).toUnsigned(width);
      final bC = signed
          ? BigInt.from(cv).toSigned(2 * width + 1)
          : BigInt.from(cv).toUnsigned(width * 2 + 1);

      final signedOperands = Logic(name: 'signedOperands');
      // ignore: cascade_invocations
      signedOperands.put(1);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      c.put(bC);

      final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4,
          selectSigned: signedOperands);
      checkMultiplyAccumulate(mod, bA, bB, bC, signedTest: signed);
    }
  });

  test('single rectangular mac', () async {
    const widthA = 6;
    const widthB = 9;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);
    final c = Logic(name: 'c', width: widthA + widthB + 1);

    const av = 0;
    const bv = 0;
    const cv = -512;
    for (final signed in [true, false]) {
      final bA = signed
          ? BigInt.from(av).toSigned(widthA)
          : BigInt.from(av).toUnsigned(widthA);
      final bB = signed
          ? BigInt.from(bv).toSigned(widthB)
          : BigInt.from(bv).toUnsigned(widthB);
      final bC = signed
          ? BigInt.from(cv).toSigned(widthA + widthB)
          : BigInt.from(cv).toUnsigned(widthA + widthB);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      c.put(bC);

      final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4, signed: signed);
      checkMultiplyAccumulate(mod, bA, bB, bC, signedTest: signed);
    }
  });
  test('trivial compression tree multiply-accumulate test', () async {
    const widthA = 6;
    const widthB = 6;
    const radix = 8;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);
    final c = Logic(name: 'c', width: widthA + widthB + 1);

    a.put(15);
    b.put(3);
    c.put(5);

    final multiplier =
        CompressionTreeMultiplyAccumulate(a, b, c, radix, signed: true);
    final accumulate = multiplier.accumulate;
    expect(accumulate.value.toBigInt(), equals(BigInt.from(15 * 3 + 5)));
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
        signed: true);

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
    const expectedRep2 = '''
	pp3,15	pp3,14	pp3,13	pp3,12	pp3,11	pp3,10	pp3,9	pp3,8	pp3,7	pp3,6	pp3,5	pp2,4	pp2,3	pp1,2	pp1,1	pp0,0
			pp2,13	pp2,12	pp1,11	pp2,10	pp2,9	pp2,8	pp2,7	pp2,6	pp2,5	pp0,4	pp0,3	pp0,2	pp0,1	
					pp2,11	pp1,10	pp1,9	pp1,8	pp1,7	pp1,6	pp1,5	pp1,4	pp1,3			
						pp0,10	pp0,9	pp0,8	pp0,7	pp0,6	pp0,5					
''';
    // print(cc.representation());
    expect(cc.representation(), equals(expectedRep2));

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
