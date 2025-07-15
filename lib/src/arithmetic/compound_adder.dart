// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compound_adder.dart
// Implementation of Compund Integer Adder Module
// (Output Sum and Sum1 which is Sum + 1).
//
// 2024 September
// Author: Anton Sorokin <anton.a.sorokin@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An abstract class for all compound adder module implementations.
abstract class CompoundAdder extends Adder {
  /// The addition result [sum] + 1 in 2s complement form as [sumP1]
  Logic get sumP1 => output('sumP1');

  /// Takes in input [a] and input [b] and return the [sum] as well as
  /// [sumP1] which is [sum] plus 1.
  /// The width of input [a] and [b] must be the same, both [sum] and
  /// [sumP1] are one wider than the inputs.
  CompoundAdder(super.a, super.b,
      {Logic? carryIn,
      super.name = 'compound_adder',
      super.definitionName = 'compound_adder'}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    if (carryIn != null) {
      throw RohdHclException("we don't support carryIn");
    }
    addOutput('sumP1', width: a.width + 1);
  }
}

/// A trivial compound adder.
class TrivialCompoundAdder extends CompoundAdder {
  /// Constructs a [CompoundAdder].
  TrivialCompoundAdder(super.a, super.b,
      {super.carryIn, super.name = 'trivial_compound_adder'})
      : super(definitionName: 'trival_compound_adder') {
    sum <= a.zeroExtend(a.width + 1) + b.zeroExtend(b.width + 1);
    sumP1 <= sum + 1;
  }
}

/// Carry-select compound adder.
class CarrySelectCompoundAdder extends CompoundAdder {
  /// Adder block size computation algorithm.
  /// Generates only one carry-select block
  /// Return list of adder block sizes starting from
  /// the LSB connected one.
  /// [adderWidth] is a whole width of adder.
  static List<int> splitSelectAdderAlgorithmSingleBlock(int adderWidth) {
    final splitData = <int>[adderWidth];
    return splitData;
  }

  /// Adder  block size computation algorithm.
  /// Generates 4 bit carry-select blocks with 1st entry width adjusted down.
  /// Return list of block sizes starting from
  /// the LSB connected one.
  /// [adderWidth] is a whole width of adder.
  @Deprecated('use splitSelectAdderAlgorithmNBit instead')
  static List<int> splitSelectAdderAlgorithm4Bit(int adderWidth) {
    final blockNb = (adderWidth / 4.0).ceil();
    final firstBlockSize = adderWidth - (blockNb - 1) * 4;
    final splitData = <int>[firstBlockSize];
    for (var i = 1; i < blockNb; ++i) {
      splitData.add(4);
    }
    return splitData;
  }

  /// General width splitter
  static List<int> _splitAdderNBitFunctor(int adderWidth, int n) {
    final blockNb = (adderWidth / n).ceil();
    final firstBlockSize = adderWidth - (blockNb - 1) * n;
    final splitData = <int>[firstBlockSize];
    for (var i = 1; i < blockNb; ++i) {
      splitData.add(n);
    }
    return splitData;
  }

  /// Generator of splitter algorithm
  static List<int> Function(int adderWidth) splitSelectAdderAlgorithmNBit(
          int n) =>
      (adderWidth) => _splitAdderNBitFunctor(adderWidth, n);

  /// Default adder functor to use.
  static Adder _defaultBlockAdder(Logic a, Logic b,
          {Logic? carryIn, Logic? subtractIn, String name = ''}) =>
      ParallelPrefixAdder(a, b, carryIn: carryIn, name: name);

  /// Constructs a [CarrySelectCompoundAdder].
  /// - [carryIn] is a carry [Logic] into the [CarrySelectCompoundAdder]
  /// - [adderGen] provides an adder [Function] which must supply optional
  ///   [carryIn] and [subtractIn] [Logic] controls.
  /// - [subtractIn]  This option is used by the
  ///   [CarrySelectOnesComplementCompoundAdder] and should not be used directly
  ///   as it requires ones-complement behavior from [adderGen].
  /// - [widthGen] is the splitting [Function] for creating the different adder
  ///   blocks. Decreasing the split width will increase speed but also increase
  ///   area.
  CarrySelectCompoundAdder(
    super.a,
    super.b, {
    Logic? subtractIn,
    super.carryIn,
    Adder Function(Logic a, Logic b,
            {Logic? carryIn, Logic? subtractIn, String name})
        adderGen = _defaultBlockAdder,
    List<int> Function(int) widthGen = splitSelectAdderAlgorithmSingleBlock,
    String? definitionName,
    super.name = 'cs_compound_adder',
  }) : super(
            definitionName: definitionName ??
                'CarrySelectCompoundAdder_${adderGen(a, b).definitionName}') {
    subtractIn = (subtractIn != null)
        ? addInput('subtractIn', subtractIn, width: subtractIn.width)
        : null;
    // output bits lists
    final sumList0F = <Logic>[];
    final sumList1F = <Logic>[];
    // carryout of previous adder block
    // for sum and sum+1
    Logic carry0 = Const(0);
    Logic carry1 = Const(0);
    // Get size of each adder block
    final adderSplit = widthGen(a.width);
    // 1st output bit index of each block
    var blockStartIdx = 0;
    for (var i = 0; i < adderSplit.length; ++i) {
      // input width of current adder block
      final blockWidth = adderSplit[i];
      final sum0Ary = Logic(width: blockWidth);
      final sum1Ary = Logic(width: blockWidth);
      if (blockWidth <= 0) {
        throw RohdHclException('non-positive adder block size.');
      }
      final blockEnd = blockStartIdx + blockWidth;
      if (blockEnd > a.width) {
        throw RohdHclException('oversized adders sequence.');
      }
      // Build sub adders for carryIn=0 and carryIn=1
      final fullAdder0 = adderGen(a.getRange(blockStartIdx, blockEnd),
          b.getRange(blockStartIdx, blockEnd),
          subtractIn: subtractIn, carryIn: Const(0), name: 'block0_$i');
      final fullAdder1 = adderGen(a.getRange(blockStartIdx, blockEnd),
          b.getRange(blockStartIdx, blockEnd),
          subtractIn: subtractIn, carryIn: Const(1), name: 'block1_$i');
      sum0Ary <=
          ((i == 0)
                  ? fullAdder0.sum
                  : mux(carry0, fullAdder1.sum, fullAdder0.sum))
              .slice(0, blockWidth - 1)
              .named('block_${i}_sum0Ary');

      sum1Ary <=
          ((i == 0)
                  ? fullAdder1.sum
                  : mux(carry1, fullAdder1.sum, fullAdder0.sum))
              .slice(0, blockWidth - 1)
              .named('block_${i}_sum1Ary');

      sumList0F.add(sum0Ary);
      sumList1F.add(sum1Ary);
      if (i == 0) {
        // select carryout as a last bit of the adder
        carry0 = fullAdder0.sum[blockWidth].named('block_${i}_adder0Msb');
        carry1 = fullAdder1.sum[blockWidth].named('block_${i}_adder1Msb');
      } else {
        // select carryout depending on carryin (carryout of the previous block)
        carry0 =
            mux(carry0, fullAdder1.sum[blockWidth], fullAdder0.sum[blockWidth])
                .named('block_${i}_carry0');
        carry1 =
            mux(carry1, fullAdder1.sum[blockWidth], fullAdder0.sum[blockWidth])
                .named('block_${i}_carry1');
      }

      blockStartIdx += blockWidth;
    }

    sum <= [sumList0F.swizzle(), carry0].swizzle().named('sum_inner').reversed;
    sumP1 <=
        [sumList1F.swizzle(), carry1].swizzle().named('sumP1_inner').reversed;
  }
}

/// Carry-select ones-complement compound adder.
class CarrySelectOnesComplementCompoundAdder extends CompoundAdder {
  /// The sign of the [sum]
  Logic get sign => output('sign');

  /// The sign of the [sumP1]
  Logic get signP1 => output('signP1');

  /// The end-around carry for the [sum] should be added to it to get the final
  /// result.
  Logic? get carryOut => tryOutput('carryOut');

  /// The end-around carry for the [sumP1] should be added to it to get the
  /// final result.
  Logic? get carryOutP1 => tryOutput('carryOutP1');

  /// Subtraction controlled by an optional logic [subtractIn]
  @protected
  late final Logic? subtractIn;

  /// Constructs a [CarrySelectCompoundAdder] using a set of
  /// [OnesComplementAdder] in a carry-select configuration. Adds (or subtracts)
  /// [a] and [b] to produce [sum] and [sumP1] (sum plus 1).
  /// - [adderGen] is the adder generator [Function] inside the
  ///   [OnesComplementAdder].
  /// - [subtractIn] is an optional [Logic] control for subtraction.
  /// - [subtract] is a boolean control for subtraction. It must be
  ///   `false`(default) if a [subtractIn] [Logic] is provided.
  /// - [generateCarryOut] set to `true` will create output [carryOut] and
  ///   employ the ones-complement optimization of not adding '1' to convert
  ///   back to 2s complement during subtraction on the [sum].
  /// - [generateCarryOutP1] set to `true` will create output [carryOutP1] and
  ///   employ the ones-complement optimization of not adding '1' to convert
  ///   back to 2s complement during subtraction on the [sumP1].
  /// - [widthGen] is a [Function] which produces a list for splitting the adder
  ///   for the carry-select chain.  The default is
  ///   [CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock],
  CarrySelectOnesComplementCompoundAdder(super.a, super.b,
      {Adder Function(Logic, Logic, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      Logic? subtractIn,
      bool generateCarryOut = false,
      bool generateCarryOutP1 = false,
      bool subtract = false,
      List<int> Function(int) widthGen =
          CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock,
      super.name})
      : super(
            definitionName:
                'CarrySelectOnesComplementCompoundAdder_W${a.width}') {
    subtractIn = (subtractIn != null)
        ? addInput('subtractIn', subtractIn, width: subtractIn.width)
        : null;

    if (generateCarryOut) {
      addOutput('carryOut');
    }
    if (generateCarryOutP1) {
      addOutput('carryOutP1');
    }

    final doSubtract = subtractIn ?? (subtract ? Const(subtract) : Const(0));

    final csadder = CarrySelectCompoundAdder(a, b,
        widthGen: widthGen,
        subtractIn: subtractIn,
        adderGen: (a, b, {carryIn, subtractIn, name = 'ones_complement'}) =>
            OnesComplementAdder(a, b,
                adderGen: adderGen,
                carryIn: carryIn,
                generateEndAroundCarry: true,
                subtract: subtract,
                chainable: true,
                subtractIn: subtractIn));

    addOutput('sign') <= mux(doSubtract, ~csadder.sum[-1], Const(0));
    addOutput('signP1') <= mux(doSubtract, ~csadder.sumP1[-1], Const(0));
    final sumPlus1 =
        mux(doSubtract & csadder.sumP1[-1], ~csadder.sumP1, csadder.sumP1);
    if (generateCarryOutP1) {
      sumP1 <= sumPlus1;
      carryOutP1! <= csadder.sumP1[-1];
    } else {
      final incrementer = ParallelPrefixIncr(sumPlus1);
      sumP1 <=
          mux(csadder.sumP1[-1], incrementer.out.named('sum_plus2'), sumPlus1);
    }
    if (generateCarryOut) {
      sum <= mux(doSubtract & csadder.sum[-1], ~csadder.sum, csadder.sum);
      carryOut! <= csadder.sum[-1];
    } else {
      sum <= mux(doSubtract & csadder.sum[-1], sumPlus1, csadder.sum);
    }
  }
}
