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
import 'package:test/test.dart';

/// The following routines are useful only during testing
extension TestMultiplierSignage on Multiplier {
  /// Return true if multiplicand [a] is truly signed (fixed or runtime)
  bool isSignedMultiplicand() => (selectSignedMultiplicand == null)
      ? signedMultiplicand
      : !selectSignedMultiplicand!.value.isZero;

  /// Return true if multiplier [b] is truly signed (fixed or runtime)
  bool isSignedMultiplier() => (selectSignedMultiplier == null)
      ? signedMultiplier
      : !selectSignedMultiplier!.value.isZero;

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

/// Simple multiplier to demonstrate instantiation of CompressionTreeMultiplier.
class SimpleMultiplier extends Multiplier {
  /// The output of the simple multiplier
  @override
  Logic get product => output('product');

  /// Construct a simple multiplier with runtime sign operation
  SimpleMultiplier(Logic a, Logic b, dynamic signedMultiplicandParam,
      dynamic signedMultiplierParam)
      : super(a, b) {
    final mult = CompressionTreeMultiplier(a, b, 4,
        adderGen: ParallelPrefixAdder.new,
        signedMultiplicandParam: signedMultiplicandParam,
        signedMultiplierParam: signedMultiplierParam);
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
  test('exhaustive_W${width}_${mod.name}', () async {
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
    {dynamic signedMultiplicandParam, dynamic signedMultiplierParam});

String _signedMD(dynamic mdConfig) {
  if (mdConfig is Config) {
    if (mdConfig.runtimeConfig != null) {
      return 'SSD_';
    }
    return mdConfig.staticConfig ? 'SD_' : 'UD_';
  }
  return '';
}

String _signedML(dynamic mdConfig) {
  if (mdConfig is Config) {
    if (mdConfig.runtimeConfig != null) {
      return 'SSL_';
    }
    return mdConfig.staticConfig ? 'SL_' : 'UL_';
  }
  return '';
}

MultiplierCallback curryCompressionTreeMultiplier(int radix,
    {SignExtensionFunction seGen = CompactRectSignExtension.new,
    Adder Function(Logic a, Logic b, {Logic? carryIn, String name}) adderGen =
        NativeAdder.new,
    dynamic signedMultiplicandParam,
    dynamic signedMultiplierParam}) {
  String adderName(Logic a, Logic b) => '${adderGen(a, b).name}_W${a.width}';
  String genName(Logic a, Logic b) =>
      seGen(PartialProductGenerator(a, b, RadixEncoder(radix))).name;
  final signage = '${_signedMD(signedMultiplicandParam)}'
      '${_signedML(signedMultiplierParam)}';
  return (a, b, {signedMultiplicandParam, signedMultiplierParam}) =>
      CompressionTreeMultiplier(a, b, radix,
          signedMultiplicandParam: signedMultiplicandParam,
          signedMultiplierParam: signedMultiplierParam,
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
        dynamic signedMultiplicandParam,
        dynamic signedMultiplierParam}) =>
    (a, b, c) => MultiplyOnly(
        a,
        b,
        c,
        signedMultiplicandParam: signedMultiplicandParam,
        signedMultiplierParam: signedMultiplierParam,
        curryCompressionTreeMultiplier(
          radix,
          adderGen: adderGen,
          seGen: seGen,
          signedMultiplicandParam: signedMultiplicandParam,
          signedMultiplierParam: signedMultiplierParam,
        ));

MultiplyAccumulateCallback curryMultiplyAccumulate(int radix,
    {Adder Function(Logic a, Logic b, {Logic? carryIn, String name}) adderGen =
        NativeAdder.new,
    SignExtensionFunction seGen = CompactRectSignExtension.new,
    dynamic signedMultiplicandParam,
    dynamic signedMultiplierParam,
    dynamic signedAddendParam}) {
  String genName(Logic a, Logic b) =>
      seGen(PartialProductGenerator(a, b, RadixEncoder(radix))).name;
  final signage = '${_signedMD(signedMultiplicandParam)}'
      '${_signedML(signedMultiplierParam)}';

  return (a, b, c) => CompressionTreeMultiplyAccumulate(a, b, c, radix,
      adderGen: adderGen,
      seGen: seGen,
      signedMultiplicandParam: signedMultiplicandParam,
      signedMultiplierParam: signedMultiplierParam,
      signedAddendParam: signedAddendParam,
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
            final signedMultiplicandParam = Config(
                name: 'signedMultiplicand',
                runtimeConfig: selectSignedMultiplicand,
                staticConfig: selectSignedMultiplicand != null
                    ? null
                    : signedMultiplicand);
            final signedMultiplierParam = Config(
                name: 'signedMultiplier',
                runtimeConfig: selectSignedMultiplier,
                staticConfig:
                    selectSignedMultiplier != null ? null : signedMultiplier);
            final mod = NativeMultiplier(a, b,
                signedMultiplicandParam: signedMultiplicandParam,
                signedMultiplierParam: signedMultiplierParam,
                name: 'NativeMultiplier_W${a.width}x'
                    '${b.width}_${_signedMD(signedMultiplicandParam)}'
                    '${_signedML(signedMultiplierParam)}');

            for (var i = 0; i < pow(2, width); i++) {
              for (var j = 0; j < pow(2, width); j++) {
                final ai = signedMultiplicandParam.value
                    ? BigInt.from(i).toSigned(width)
                    : BigInt.from(i).toUnsigned(width);
                final bi = signedMultiplierParam.value
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

  // TODO(desmonddak): must set variables in the enclosing module, so we can't
  // really curry unless the enclosing module reads them off the passed in
  // multiplier.
  group('Native multiplier check', () {
    for (final selectSignedMultiplicand in [null, Const(0), Const(1)]) {
      // for (final selectSignedMultiplicand in [null]) {
      for (final signedMultiplicand
          in (selectSignedMultiplicand == null) ? [false, true] : [false]) {
        for (final selectSignedMultiplier in [null, Const(0), Const(1)]) {
          // for (final selectSignedMultiplier in [null]) {
          for (final signedMultiplier
              in (selectSignedMultiplier == null) ? [false, true] : [false]) {
            testMultiplyAccumulateExhaustive(
                5,
                (a, b, c) => MultiplyOnly(
                    a,
                    b,
                    c,
                    signedMultiplicandParam: selectSignedMultiplicand != null
                        ? RuntimeConfig(selectSignedMultiplicand,
                            name: 'selectSignedMultiplicand')
                        : BooleanConfig(staticConfig: signedMultiplicand),
                    signedMultiplierParam: selectSignedMultiplier != null
                        ? RuntimeConfig(selectSignedMultiplier,
                            name: 'selectSignedMultiplier')
                        : BooleanConfig(staticConfig: signedMultiplier),
                    (a, b, {signedMultiplicandParam, signedMultiplierParam}) =>
                        NativeMultiplier(a, b,
                            signedMultiplicandParam: signedMultiplicandParam,
                            signedMultiplierParam: signedMultiplierParam,
                            name: 'NativeMultiplier_W${a.width}x${b.width}'
                                '_${_signedMD(signedMultiplicandParam)}'
                                '${_signedML(signedMultiplierParam)}')));
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
                final signedMultiplicandParam = Config(
                    name: 'signedMultiplicand',
                    runtimeConfig: selectSignedMultiplicand,
                    staticConfig: selectSignedMultiplicand != null
                        ? null
                        : signedMultiplicand);
                final signedMultiplierParam = Config(
                    name: 'signedMultiplier',
                    runtimeConfig: selectSignedMultiplier,
                    staticConfig: selectSignedMultiplier != null
                        ? null
                        : signedMultiplier);
                testMultiplyAccumulateRandom(
                    width,
                    10,
                    curryMultiplierAsMultiplyAccumulate(radix,
                        adderGen: ParallelPrefixAdder.new,
                        signedMultiplicandParam: signedMultiplicandParam,
                        signedMultiplierParam: signedMultiplierParam));
              }
            }
          }
        }
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
                    final signedMultiplicandParam = Config(
                        name: 'signedMultiplicand',
                        runtimeConfig: selectSignedMultiplicand,
                        staticConfig: selectSignedMultiplicand != null
                            ? null
                            : signedMultiplicand);
                    final signedMultiplierParam = Config(
                        name: 'signedMultiplier',
                        runtimeConfig: selectSignedMultiplier,
                        staticConfig: selectSignedMultiplier != null
                            ? null
                            : signedMultiplier);

                    final signedAddendConfig = Config(
                        name: 'signedAddend',
                        runtimeConfig: selectSignedAddend,
                        staticConfig:
                            selectSignedAddend != null ? null : signedAddend);
                    testMultiplyAccumulateRandom(
                        width,
                        10,
                        curryMultiplyAccumulate(
                          radix,
                          adderGen: ParallelPrefixAdder.new,
                          signedMultiplicandParam: signedMultiplicandParam,
                          signedMultiplierParam: signedMultiplierParam,
                          signedAddendParam: signedAddendConfig,
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
    final mod = CompressionTreeMultiplier(a, b, 4,
        clk: clk,
        adderGen: ParallelPrefixAdder.new,
        signedMultiplicandParam:
            RuntimeConfig(signedSelect, name: 'selectSignedMultiplicand'),
        signedMultiplierParam:
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

    final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4,
        clk: clk,
        adderGen: ParallelPrefixAdder.new,
        signedMultiplicandParam:
            RuntimeConfig(signedSelect, name: 'selectSignedMultiplicand'),
        signedMultiplierParam:
            RuntimeConfig(signedSelect, name: 'selectSignedMultiplier'),
        signedAddendParam:
            RuntimeConfig(signedSelect, name: 'selectSignedAddend'));
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

        final mod = CompressionTreeMultiplier(
          a,
          b,
          4,
          adderGen: ParallelPrefixAdder.new,
          signExtensionGen: StopBitsSignExtension.new,
          signedMultiplicandParam: signedSelect != null
              ? RuntimeConfig(signedSelect, name: 'selectSignedMultiplicand')
              : null,
          signedMultiplierParam: signedSelect != null
              ? RuntimeConfig(signedSelect, name: 'selectSignedMultiplier')
              : BooleanConfig(staticConfig: !useSignedLogic && signed),
        );
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
        (a, b, {signedMultiplicandParam, signedMultiplierParam}) =>
            SimpleMultiplier(
                a, b, signedMultiplicandParam, signedMultiplierParam),
        signedMultiplicandParam:
            RuntimeConfig(signedOperands, name: 'selectSignedMultiplicand'),
        signedMultiplierParam:
            RuntimeConfig(signedOperands, name: 'selectSignedMultiplier'));

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
          signedMultiplicandParam:
              RuntimeConfig(signedOperands, name: 'selectSignedMultiplicand'),
          signedMultiplierParam:
              RuntimeConfig(signedOperands, name: 'selectSignedMultiplier'),
          signedAddendParam:
              RuntimeConfig(signedOperands, name: 'selectSignedAddend'));
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
          signedMultiplicandParam: BooleanConfig(staticConfig: signed),
          signedMultiplierParam: BooleanConfig(staticConfig: signed),
          signedAddendParam: BooleanConfig(staticConfig: signed));
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
        signedMultiplierParam: BooleanConfig(staticConfig: true));
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
          signedMultiplicandParam: BooleanConfig(staticConfig: signed),
          signedMultiplierParam: BooleanConfig(staticConfig: signed));
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
