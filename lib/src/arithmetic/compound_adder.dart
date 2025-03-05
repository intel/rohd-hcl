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
  /// - [subtractIn] can be provided to dynamically select a subtraction.
  /// - [carryIn] is a carry Logic into the [CarrySelectCompoundAdder]
  /// - [adderGen] provides an adder Function which must supply optional
  /// [carryIn] and [subtractIn] Logic controls.
  /// - [widthGen] is the splitting function for creating the different adder
  /// blocks.
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
    final sumList0 = <Logic>[];
    final sumList1 = <Logic>[];
    // carryout of previous adder block
    // for sum and sum+1
    Logic? carry0;
    Logic? carry1;
    // Get size of each adder block
    final adderSplit = widthGen(a.width);
    // 1st output bit index of each block
    var blockStartIdx = 0;
    for (var i = 0; i < adderSplit.length; ++i) {
      // input width of current adder block
      final blockWidth = adderSplit[i];
      if (blockWidth <= 0) {
        throw RohdHclException('non-positive adder block size.');
      }
      if (blockWidth + blockStartIdx > a.width) {
        throw RohdHclException('oversized adders sequence.');
      }
      final blockA = Logic(name: 'block_${i}_a', width: blockWidth);
      final blockB = Logic(name: 'block_${i}_b', width: blockWidth);
      blockA <= a.getRange(blockStartIdx, blockStartIdx + blockWidth);
      blockB <= b.getRange(blockStartIdx, blockStartIdx + blockWidth);
      // Build sub adders for 0 and 1 carryin values
      final fullAdder0 = adderGen(blockA, blockB,
          subtractIn: subtractIn, carryIn: Const(0), name: 'block0_$i');
      final fullAdder1 = adderGen(blockA, blockB,
          subtractIn: subtractIn, carryIn: Const(1), name: 'block1_$i');
      for (var bitIdx = 0; bitIdx < blockWidth; ++bitIdx) {
        if (i == 0) {
          // connect directly to respective sum output bit
          sumList0.add(fullAdder0.sum[bitIdx]);
          sumList1.add(fullAdder1.sum[bitIdx]);
        } else {
          final bitOut0 = Logic(name: 'bit0_${blockStartIdx + bitIdx}');
          final bitOut1 = Logic(name: 'bit1_${blockStartIdx + bitIdx}');
          // select adder output from adder matching carryin value
          bitOut0 <=
              mux(carry0!, fullAdder1.sum[bitIdx], fullAdder0.sum[bitIdx]);
          bitOut1 <=
              mux(carry1!, fullAdder1.sum[bitIdx], fullAdder0.sum[bitIdx]);
          sumList0.add(bitOut0);
          sumList1.add(bitOut1);
        }
      }
      if (i == 0) {
        // select carryout as a last bit of the adder
        carry0 = fullAdder0.sum[blockWidth];
        carry1 = fullAdder1.sum[blockWidth];
      } else {
        // select carryout depending on carryin (carryout of the previous block)
        carry0 = mux(
            carry0!, fullAdder1.sum[blockWidth], fullAdder0.sum[blockWidth]);
        carry1 = mux(
            carry1!, fullAdder1.sum[blockWidth], fullAdder0.sum[blockWidth]);
      }
      blockStartIdx += blockWidth;
    }

    // Append carryout bit
    sumList0.add(carry0!);
    sumList1.add(carry1!);

    sum <= sumList0.rswizzle();
    sumP1 <= sumList1.rswizzle();
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
  /// [OnesComplementAdder] in a carry-select configuration.
  /// Adds (or subtracts) [a] and [b] to produce [sum] and [sumP1] (sum
  /// plus 1).
  /// - [adderGen] is the adder used inside the [OnesComplementAdder].
  /// - [subtractIn] is an optional Logic control for subtraction.
  /// - [subtract] is a boolean control for subtraction. It must be false
  /// if a [subtractIn] is not null.
  /// - [widthGen] is a function which produces a list for splitting
  /// the adder for the carry-select chain.  The default is
  /// [CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock],
  CarrySelectOnesComplementCompoundAdder(super.a, super.b,
      {Adder Function(Logic, Logic, {Logic? carryIn}) adderGen =
          ParallelPrefixAdder.new,
      Logic? subtractIn,
      Logic? carryOut,
      Logic? carryOutP1,
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

    if (carryOut != null) {
      addOutput('carryOut');
      carryOut <= this.carryOut!;
    }
    if (carryOutP1 != null) {
      addOutput('carryOutP1');
      carryOutP1 <= this.carryOutP1!;
    }

    final doSubtract = subtractIn ?? (subtract ? Const(subtract) : Const(0));

    final csadder = CarrySelectCompoundAdder(a, b,
        widthGen: widthGen,
        subtractIn: subtractIn,
        adderGen: (a, b, {carryIn, subtractIn, name = 'ones_complement'}) =>
            OnesComplementAdder(a, b,
                adderGen: adderGen,
                carryIn: carryIn,
                endAroundCarry: Logic(),
                subtract: subtract,
                chainable: true,
                subtractIn: subtractIn));

    addOutput('sign') <= mux(doSubtract, ~csadder.sum[-1], Const(0));
    addOutput('signP1') <= mux(doSubtract, ~csadder.sumP1[-1], Const(0));
    final sumPlus1 =
        mux(doSubtract & csadder.sumP1[-1], ~csadder.sumP1, csadder.sumP1);
    if (carryOutP1 != null) {
      sumP1 <= sumPlus1;

      this.carryOutP1! <= csadder.sumP1[-1];
    } else {
      final incrementer = ParallelPrefixIncr(sumPlus1);
      sumP1 <= incrementer.out.named('sum_plus2');
    }
    if (carryOut != null) {
      sum <= mux(doSubtract & csadder.sum[-1], ~csadder.sum, csadder.sum);
      this.carryOut! <= csadder.sum[-1];
    } else {
      sum <= sumPlus1;
    }
  }
}
