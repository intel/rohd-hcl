// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplier_test.dart
// Test Multiplier and MultiplerAccumulate:  CompressionTree implementations
//
// 2024 August 7
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/multiplier_components/evaluate_compressor.dart';
import 'package:rohd_hcl/src/arithmetic/multiplier_components/evaluate_partial_product.dart';
import 'package:test/test.dart';

/// The following routines are useful only during testing
extension TestMultiplierSignage on Multiplier {
  /// Return true if multiplicand [a] is truly signed (fixed or runtime)
  bool isSignedMultiplicand() => signedMultiplicandParameter.value;

  /// Return true if multiplier [b] is truly signed (fixed or runtime)
  bool isSignedMultiplier() => signedMultiplierParameter.value;

  /// Return true if accumulate result is truly signed (fixed or runtime)
  bool isSignedResult() => isSignedMultiplicand() | isSignedMultiplier();
}

/// The following routines are useful only during testing
extension TestMultiplierAccumulateSignage on MultiplyAccumulate {
  /// Return true if multiplicand [a] is truly signed (fixed or runtime)
  bool isSignedMultiplicand() => signedMultiplicandParameter.value;

  /// Return true if multiplier [b] is truly signed (fixed or runtime)
  bool isSignedMultiplier() => signedMultiplierParameter.value;

  /// Return true if addend [c] is truly signed (fixed or runtime)
  bool isSignedAddend() => signedAddendParameter.value;

  /// Return true if accumulate result is truly signed (fixed or runtime)
  bool isSignedResult() =>
      isSignedAddend() | isSignedMultiplicand() | isSignedMultiplier();
}

/// Simple multiplier to demonstrate instantiation of CompressionTreeMultiplier.
class SimpleMultiplier extends Multiplier {
  /// The output of the simple multiplier
  @override
  Logic get product => output('product');

  /// Construct a simple multiplier with runtime sign operation
  SimpleMultiplier(
      Logic a, Logic b, dynamic signedMultiplicand, dynamic signedMultiplier)
      : super(a, b) {
    final mult = CompressionTreeMultiplier(a, b,
        adderGen: ParallelPrefixAdder.new,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier);
    product <= mult.product;
  }
}

// Inner test of a multipy accumulate unit
void checkMultiplyAccumulate(
    MultiplyAccumulate mod, BigInt bA, BigInt bB, BigInt bC) {
  final golden = bA * bB + bC;
  mod.a.put(bA);
  mod.b.put(bB);
  mod.c.put(bC);

  final result = mod.accumulate.value
      .toBigInt()
      .toCondSigned(mod.accumulate.width, signed: mod.isSignedResult());
  expect(result, equals(golden),
      reason: '${mod.name} failed for A=$bA, B=$bB, C=$bC');
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
    final multiplyOnly = mod is MultiplyOnly;
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
    final multiplyOnly = mod is MultiplyOnly;

    final rand = Random(47);
    for (var i = 0; i < iterations; i++) {
      final bA = rand
          .nextLogicValue(width: width)
          .toBigInt()
          .toCondSigned(width, signed: mod.isSignedMultiplicand());
      final bB = rand
          .nextLogicValue(width: width)
          .toBigInt()
          .toCondSigned(width, signed: mod.isSignedMultiplier());

      final bC = multiplyOnly
          ? BigInt.zero
          : rand
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
  test('Multiplier exhaustive_W${width}_${mod.name}', () async {
    await mod.build();
    final multiplyOnly = mod is MultiplyOnly;

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
    {dynamic signedMultiplicand, dynamic signedMultiplier});

MultiplierCallback curryCompressionTreeMultiplier(int radix,
    {SignExtensionFunction seGen = CompactRectSignExtension.new,
    Adder Function(Logic a, Logic b, {Logic? carryIn, String name}) adderGen =
        NativeAdder.new,
    dynamic signedMultiplicand,
    dynamic signedMultiplier}) {
  String adderName(Logic a, Logic b) => '${adderGen(a, b).name}_W${a.width}';
  String genName(Logic a, Logic b) =>
      seGen(PartialProductGenerator(a, b, RadixEncoder(radix))).name;
  final signage = '${Multiplier.signedMD(signedMultiplicand)}_'
      '${Multiplier.signedML(signedMultiplier)}';
  return (a, b, {signedMultiplicand, signedMultiplier}) =>
      CompressionTreeMultiplier(a, b,
          radix: radix,
          signedMultiplicand: signedMultiplicand,
          signedMultiplier: signedMultiplier,
          signExtensionGen: seGen,
          adderGen: adderGen,
          name: 'compression_tree_multiplier_'
              '${adderName(a, b)}_'
              '${signage}_R${radix}_E${genName(a, b)}');
}

MultiplyAccumulateCallback curryMultiplierAsMultiplyAccumulate(int radix,
        {SignExtensionFunction seGen = CompactRectSignExtension.new,
        Adder Function(Logic a, Logic b, {Logic? carryIn, String name})
            adderGen = NativeAdder.new,
        dynamic signedMultiplicand,
        dynamic signedMultiplier}) =>
    (a, b, c) => MultiplyOnly(
        a,
        b,
        c,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier,
        curryCompressionTreeMultiplier(
          radix,
          adderGen: adderGen,
          seGen: seGen,
          signedMultiplicand: signedMultiplicand,
          signedMultiplier: signedMultiplier,
        ));

MultiplyAccumulateCallback curryMultiplyAccumulate(int radix,
    {Adder Function(Logic a, Logic b, {Logic? carryIn, String name}) adderGen =
        NativeAdder.new,
    SignExtensionFunction seGen = CompactRectSignExtension.new,
    dynamic signedMultiplicand,
    dynamic signedMultiplier,
    dynamic signedAddend}) {
  String genName(Logic a, Logic b) =>
      seGen(PartialProductGenerator(a, b, RadixEncoder(radix))).name;
  final signage = '${Multiplier.signedMD(signedMultiplicand)}_'
      '${Multiplier.signedML(signedMultiplier)}_'
      '${MultiplyAccumulate.signedAD(signedAddend)}';

  return (a, b, c) => CompressionTreeMultiplyAccumulate(a, b, c,
      radix: radix,
      adderGen: adderGen,
      seGen: seGen,
      signedMultiplicand: signedMultiplicand,
      signedMultiplier: signedMultiplier,
      signedAddend: signedAddend,
      name: 'compression_tree_mac_'
          '${signage}_R${radix}_E${genName(a, b)}');
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('Native multiplier sweep with signage test', () async {
    const width = 5;
    final a = Logic(width: width);
    final b = Logic(width: width);

    for (final selectSignedMultiplicand in [null, Const(0), Const(1)]) {
      for (final signedMultiplicand
          in (selectSignedMultiplicand == null) ? [false, true] : [false]) {
        for (final selectSignedMultiplier in [null, Const(0), Const(1)]) {
          for (final signedMultiplier
              in (selectSignedMultiplier == null) ? [false, true] : [false]) {
            final signedMultiplicandConfig = StaticOrRuntimeParameter(
                name: 'signedMultiplicand',
                runtimeConfig: selectSignedMultiplicand,
                staticConfig: signedMultiplicand);
            final signedMultiplierConfig = StaticOrRuntimeParameter(
                name: 'signedMultiplier',
                runtimeConfig: selectSignedMultiplier,
                staticConfig: signedMultiplier);
            final mod = NativeMultiplier(a, b,
                signedMultiplicand: signedMultiplicandConfig,
                signedMultiplier: signedMultiplierConfig,
                name: 'NativeMultiplier_W${a.width}x${b.width}'
                    '_${Multiplier.signedMD(signedMultiplicandConfig)}_'
                    '${Multiplier.signedML(signedMultiplierConfig)}');

            for (var i = 0; i < pow(2, width); i++) {
              for (var j = 0; j < pow(2, width); j++) {
                final ai = signedMultiplicandConfig.value
                    ? BigInt.from(i).toSigned(width)
                    : BigInt.from(i).toUnsigned(width);
                final bi = signedMultiplierConfig.value
                    ? BigInt.from(j).toSigned(width)
                    : BigInt.from(j).toUnsigned(width);
                a.put(ai);
                b.put(bi);
                final expected = ai * bi;
                final product = mod.isSignedResult()
                    ? mod.product.value.toBigInt().toSigned(width * 2)
                    : mod.product.value.toBigInt();
                expect(product, equals(expected));
              }
            }
          }
        }
      }
    }
  });

  group('Native multiplier check', () {
    for (final selectSignedMultiplicand in [null, Const(0), Const(1)]) {
      for (final signedMultiplicand
          in (selectSignedMultiplicand == null) ? [false, true] : [false]) {
        for (final selectSignedMultiplier in [null, Const(0), Const(1)]) {
          for (final signedMultiplier
              in (selectSignedMultiplier == null) ? [false, true] : [false]) {
            final signedMultiplicandConfig = StaticOrRuntimeParameter(
                name: 'signedMultiplicand',
                runtimeConfig: selectSignedMultiplicand,
                staticConfig: signedMultiplicand);
            final signedMultiplierConfig = StaticOrRuntimeParameter(
                name: 'signedMultiplier',
                runtimeConfig: selectSignedMultiplier,
                staticConfig: signedMultiplier);
            // Make sure multiplier generator lambda function passes the correct
            // signage as these may contain Logic signals that may have been
            // added to the enclosing module via [StaticOrRuntimeParameter].
            testMultiplyAccumulateExhaustive(
                5,
                (a, b, c) => MultiplyOnly(
                    a,
                    b,
                    c,
                    signedMultiplicand: signedMultiplicandConfig,
                    signedMultiplier: signedMultiplierConfig,
                    (a, b, {signedMultiplicand, signedMultiplier}) =>
                        NativeMultiplier(a, b,
                            signedMultiplicand: signedMultiplicand,
                            signedMultiplier: signedMultiplier,
                            name: 'NativeMultiplier_W${a.width}x${b.width}'
                                '_${Multiplier.signedMD(signedMultiplicand)}_'
                                '${Multiplier.signedML(signedMultiplier)}')));
          }
        }
      }
    }
  });

  group('Compression Tree Multiplier: curried random radix/ptree/width', () {
    for (final radix in [2, 4]) {
      for (final width in [3, 4]) {
        for (final ppTree in [KoggeStone.new, BrentKung.new, Sklansky.new]) {
          Adder adderFn(Logic a, Logic b, {Logic? carryIn, String? name}) =>
              ParallelPrefixAdder(a, b, carryIn: carryIn, ppGen: ppTree);
          testMultiplyAccumulateRandom(width, 10,
              curryMultiplierAsMultiplyAccumulate(radix, adderGen: adderFn));
        }
      }
    }
  });

  group('Compression Tree Multiplier: curried random radix/extension/width',
      () {
    for (final radix in [2, 4]) {
      for (final width in [3, 4]) {
        for (final signExtension
            in SignExtension.values.where((e) => e != SignExtension.none)) {
          final seg = currySignExtensionFunction(signExtension);
          testMultiplyAccumulateRandom(
              width,
              10,
              curryMultiplierAsMultiplyAccumulate(radix,
                  adderGen: ParallelPrefixAdder.new, seGen: seg));
        }
      }
    }
  });

  group('Compression Tree Multiplier: curried random sign/select', () {
    for (final selectSignedMultiplicand in [null, Const(0), Const(1)]) {
      for (final signedMultiplicand
          in (selectSignedMultiplicand == null) ? [false, true] : [false]) {
        for (final selectSignedMultiplier in [null, Const(0), Const(1)]) {
          for (final signedMultiplier
              in (selectSignedMultiplier == null) ? [false, true] : [false]) {
            for (final radix in [4]) {
              for (final width in [1 + log2Ceil(radix)]) {
                final signedMultiplicandConfig = StaticOrRuntimeParameter(
                    name: 'signedMultiplicand',
                    runtimeConfig: selectSignedMultiplicand,
                    staticConfig: signedMultiplicand);
                final signedMultiplierConfig = StaticOrRuntimeParameter(
                    name: 'signedMultiplier',
                    runtimeConfig: selectSignedMultiplier,
                    staticConfig: signedMultiplier);
                testMultiplyAccumulateRandom(
                    width,
                    10,
                    curryMultiplierAsMultiplyAccumulate(radix,
                        adderGen: ParallelPrefixAdder.new,
                        signedMultiplicand: signedMultiplicandConfig,
                        signedMultiplier: signedMultiplierConfig));
              }
            }
          }
        }
      }
    }
  });

  test('Compression Tree MAC: curried random sign/select singleton', () {
    const signedMultiplicand = true;
    const signedMultiplier = true;
    const signedAddend = true;
    for (final radix in [4]) {
      for (final width in [1 + log2Ceil(radix)]) {
        final signedMultiplicandConfig = StaticOrRuntimeParameter(
            name: 'signedMultiplicand', staticConfig: signedMultiplicand);
        final signedMultiplierConfig = StaticOrRuntimeParameter(
            name: 'signedMultiplier', staticConfig: signedMultiplier);

        final signedAddendConfig = StaticOrRuntimeParameter(
            name: 'signedAddend', staticConfig: signedAddend);

        final fn = curryMultiplyAccumulate(
          radix,
          adderGen: ParallelPrefixAdder.new,
          signedMultiplicand: signedMultiplicandConfig,
          signedMultiplier: signedMultiplierConfig,
          signedAddend: signedAddendConfig,
        );

        final a = Logic(name: 'a', width: width);
        final b = Logic(name: 'b', width: width);
        final c = Logic(name: 'c', width: width * 2);

        final bA = BigInt.from(2).toCondSigned(width, signed: true);
        final bB = BigInt.from(-2).toCondSigned(width, signed: true);
        final bC = BigInt.from(-2).toCondSigned(width, signed: true);

        a.put(bA);
        b.put(bB);
        c.put(bC);
        final mod = fn(a, b, c);
        checkMultiplyAccumulate(mod, bA, bB, bC);
      }
    }
  });

  group('Compression Tree MAC: curried random sign/select', () {
    for (final selectSignedMultiplicand in [null, Const(0), Const(1)]) {
      for (final signedMultiplicand
          in (selectSignedMultiplicand == null) ? [false, true] : [false]) {
        for (final selectSignedMultiplier in [null, Const(0), Const(1)]) {
          for (final signedMultiplier
              in (selectSignedMultiplier == null) ? [false, true] : [false]) {
            for (final selectSignedAddend in [null, Const(0), Const(1)]) {
              for (final signedAddend
                  in (selectSignedAddend == null) ? [false, true] : [false]) {
                for (final radix in [4]) {
                  for (final width in [1 + log2Ceil(radix)]) {
                    final signedMultiplicandConfig = StaticOrRuntimeParameter(
                        name: 'signedMultiplicand',
                        runtimeConfig: selectSignedMultiplicand,
                        staticConfig: signedMultiplicand);
                    final signedMultiplierConfig = StaticOrRuntimeParameter(
                        name: 'signedMultiplier',
                        runtimeConfig: selectSignedMultiplier,
                        staticConfig: signedMultiplier);

                    final signedAddendConfig = StaticOrRuntimeParameter(
                        name: 'signedAddend',
                        runtimeConfig: selectSignedAddend,
                        staticConfig: signedAddend);
                    testMultiplyAccumulateRandom(
                        width,
                        10,
                        curryMultiplyAccumulate(
                          radix,
                          adderGen: ParallelPrefixAdder.new,
                          signedMultiplicand: signedMultiplicandConfig,
                          signedMultiplier: signedMultiplierConfig,
                          signedAddend: signedAddendConfig,
                        ));
                  }
                }
              }
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
    final mod = CompressionTreeMultiplier(a, b,
        clk: clk,
        adderGen: ParallelPrefixAdder.new,
        signedMultiplicand:
            RuntimeConfig(signedSelect, name: 'selectSignedMultiplicand'),
        signedMultiplier:
            RuntimeConfig(signedSelect, name: 'selectSignedMultiplier'));
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

    final mod = CompressionTreeMultiplyAccumulate(a, b, c,
        clk: clk,
        adderGen: ParallelPrefixAdder.new,
        signedMultiplicand: signedSelect,
        signedMultiplier: signedSelect,
        signedAddend: signedSelect);
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
    const av = 1;
    const bv = 1;
    for (final signed in [false]) {
      for (final useSignedLogic in [false]) {
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

        final mod = CompressionTreeMultiplier(a, b,
            adderGen: ParallelPrefixAdder.new,
            signExtensionGen: StopBitsSignExtension.new,
            signedMultiplicand: StaticOrRuntimeParameter(
                name: 'signedMultiplicand',
                runtimeConfig: signedSelect,
                staticConfig: signed),
            signedMultiplier: StaticOrRuntimeParameter(
                name: 'signedMultiplicand',
                runtimeConfig: signedSelect,
                staticConfig: signed));
        final golden = bA * bB;
        final result = mod.isSignedResult()
            ? mod.product.value.toBigInt().toSigned(mod.product.width)
            : mod.product.value.toBigInt().toUnsigned(mod.product.width);
        expect(result, equals(golden));
      }
    }
  });

  test('trivial instantiated multiplier', () async {
    // Using this to find trace errors when instantiating multipliers
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

    final mod = MultiplyOnly(
        multA,
        multB,
        Logic(),
        (a, b, {signedMultiplicand, signedMultiplier}) =>
            SimpleMultiplier(a, b, signedMultiplicand, signedMultiplier),
        signedMultiplicand: signedOperands,
        signedMultiplier: signedOperands);

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

      final mod = CompressionTreeMultiplyAccumulate(a, b, c,
          signedMultiplicand: signedOperands,
          signedMultiplier: signedOperands,
          signedAddend: signedOperands);

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

      final mod = CompressionTreeMultiplyAccumulate(a, b, c,
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

    final multiplier = CompressionTreeMultiplyAccumulate(a, b, c,
        radix: radix, signedMultiplier: BooleanConfig(staticConfig: true));
    final accumulate = multiplier.accumulate;
    expect(accumulate.value.toBigInt(), equals(BigInt.from(15 * 3 + 5)));
  });

  test('trivial compression MAC signed', () async {
    const widthA = 6;
    const widthB = 6;
    const widthC = widthA + widthB;
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

      final multiplier = CompressionTreeMultiplyAccumulate(a, b, c,
          signedMultiplicand: signed, signedMultiplier: signed);

      final accumulate = multiplier.accumulate;
      expect(accumulate.value.toBigInt(), equals(golden));
    }
  });

  test('Multiplier Components exhaustive', () async {
    const width = 4;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final ppG0 = PartialProductGenerator(a, b, RadixEncoder(4));
    CompactRectSignExtension(ppG0).signExtend();

    final vec = <Logic>[];
    for (var row = 0; row < ppG0.rows; row++) {
      vec.add(ppG0.partialProducts[row].rswizzle());
    }
    final cc = ColumnCompressor(vec, ppG0.rowShift);
    final multiplier0 = CompressionTreeMultiplier(a, b);
    final adder = ParallelPrefixAdder(cc.add0, cc.add1);
    final product = adder.sum.slice(a.width + b.width - 1, 0);
    const limit = 1 << width;
    for (var ai = 0; ai < limit; ai++) {
      for (var bi = 0; bi < limit; bi++) {
        final aVal = SignedBigInt.fromSignedInt(ai, width);
        final bVal = SignedBigInt.fromSignedInt(bi, width);

        a.put(aVal);
        b.put(bVal);
        final computed = EvaluateLivePartialProduct(ppG0).evaluate();

        final adderVal = product.value.toBigInt();
        final expected = multiplier0.product.value.toBigInt();
        expect(computed, equals(expected));
        expect(adderVal, equals(expected));
      }
    }
  });

  test('dot product select signed exhaustive', () async {
    const width = 3;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: width);
    final d = Logic(name: 'd', width: width);

    for (final mdSigned in [Const(0), Const(1)]) {
      for (final mlSigned in [Const(0), Const(1)]) {
        final ppG0 = PartialProductGenerator(a, b, RadixEncoder(4),
            signedMultiplicand: mdSigned, signedMultiplier: mlSigned);
        StopBitsSignExtension(ppG0).signExtend();
        final ppG1 = PartialProductGenerator(c, d, RadixEncoder(4),
            signedMultiplicand: mdSigned, signedMultiplier: mlSigned);
        StopBitsSignExtension(ppG1).signExtend();

        ppG0.partialProducts.addAll(ppG1.partialProducts);
        ppG0.rowShift.addAll(ppG1.rowShift);
        final vec = <Logic>[];
        for (var row = 0; row < ppG0.rows; row++) {
          vec.add(ppG0.partialProducts[row].rswizzle());
        }
        final cc = ColumnCompressor(vec, ppG0.rowShift);
        final sum = cc.add0 + cc.add1;
        const limit = 1 << width;
        for (var ai = 0; ai < limit; ai++) {
          for (var bi = 0; bi < limit; bi++) {
            for (var ci = 0; ci < limit; ci++) {
              for (var di = 0; di < limit; di++) {
                // By default these are unsigned
                final aVal = SignedBigInt.fromSignedInt(ai, a.width,
                    signed: mdSigned.value.toBool());
                final bVal = SignedBigInt.fromSignedInt(bi, b.width,
                    signed: mlSigned.value.toBool());
                final cVal = SignedBigInt.fromSignedInt(ci, c.width,
                    signed: mdSigned.value.toBool());
                final dVal = SignedBigInt.fromSignedInt(di, d.width,
                    signed: mlSigned.value.toBool());

                a.put(aVal);
                b.put(bVal);
                c.put(cVal);
                d.put(dVal);
                final expected = aVal * bVal + cVal * dVal;
                final computed = sum.value.toBigInt().toCondSigned(sum.width,
                    signed: mdSigned.value.toBool() | mlSigned.value.toBool());
                expect(computed, equals(expected), reason: '''
                aVal=$aVal, bVal=$bVal, cVal=$cVal, dVal=$dVal
                computed=$computed, expected=$expected
 ''');
              }
            }
          }
        }
      }
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

    final ppG0 = PartialProduct(a, b, RadixEncoder(4),
        signedMultiplicand: true, signedMultiplier: true);
    CompactRectSignExtension(ppG0.array).signExtend();

    final bit_0_5 = ppG0.array.getAbsolute(0, 5);
    expect(bit_0_5.value, equals(LogicValue.one));
    ppG0.array.setAbsolute(0, 5, Const(0));
    expect(ppG0.array.getAbsolute(0, 5).value, equals(LogicValue.zero));

    final bit_1_2 = ppG0.array.getAbsolute(1, 2);
    expect(bit_1_2.value, equals(LogicValue.zero));
    ppG0.array.setAbsolute(1, 2, Const(1));
    expect(ppG0.array.getAbsolute(1, 2).value, equals(LogicValue.one));

    final bits_3_678 = ppG0.array.getAbsoluteAll(3, [6, 7, 8]);

    expect(bits_3_678.swizzle().value, equals(Const(0, width: 3).value));

    ppG0.array.setAbsoluteAll(3, 6, [Const(1), Const(1), Const(0)]);

    expect(ppG0.array.getAbsoluteAll(3, [6, 7, 8]).swizzle().value,
        equals([Const(1), Const(1), Const(0)].swizzle().value));

    ppG0.array
      ..muxAbsolute(0, 4, select, Const(0))
      ..muxAbsoluteAll(1, 9, select, [Const(1), Const(0)]);

    expect(ppG0.array.getAbsolute(0, 4).value, equals(Const(1).value));
    expect(ppG0.array.getAbsolute(1, 9).value, equals(Const(0).value));
    expect(ppG0.array.getAbsolute(1, 10).value, equals(Const(1).value));

    select.put(1);
    expect(ppG0.array.getAbsolute(0, 4).value, equals(Const(0).value));
    expect(ppG0.array.getAbsolute(1, 9).value, equals(Const(1).value));
    expect(ppG0.array.getAbsolute(1, 10).value, equals(Const(0).value));

    ppG0.generateOutputs();

    final cc = ColumnCompressor(ppG0.rows, ppG0.rowShift, dontCompress: true);
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
        1       1       0       0       0       0       0       0       1       1       0       0       0       1       1       0        = 49350 (-16186)
                        1       1       1       0       0       0       0       0       0       0       1       0       0                = 14344 (14344)
                                        0       0       1       0       0       0       0       1       1                                = 536 (536)
                                                0       1       1       1       1       0                                                = 960 (960)
p       1       1       1       1       1       1       1       0       1       0       1       0       0       1       1       0        = 65190 (-346)''';
    expect(ts.toString(), equals(expectedEval));
  });
}
