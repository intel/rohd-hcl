// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compound_adder.dart
// Implementation of Compund Integer Adder Module
// (Output Sum and Sum1 which is Sum + 1).
//
// 2024 September
// Author: Anton Sorokin <anton.a.sorokin@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An abstract class for all compound adder module implementations.
abstract class CompoundAdder extends Adder {
  /// The addition result [sum] + 1 in 2s complement form as [sum1]
  Logic get sum1 => output('sum1');

  /// Takes in input [a] and input [b] and return the [sum] of the addition
  /// result and [sum1] sum + 1.
  /// The width of input [a] and [b] must be the same.
  CompoundAdder(super.a, super.b, {super.name = 'compound_adders'}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    addOutput('sum1', width: a.width + 1);
  }
}

/// A trivial compound adder.
class TrivialCompoundAdder extends CompoundAdder {
  /// Constructs a [CompoundAdder].
  TrivialCompoundAdder(super.a, super.b,
      {super.name = 'trivial_compound_adder'}) {
    sum <= a.zeroExtend(a.width + 1) + b.zeroExtend(b.width + 1);
    sum1 <= sum + 1;
  }
}

/// Carry-select compound adder.
class CarrySelectCompoundAdder extends CompoundAdder {
  /// Adder ripple-carry block size computation algorithm.
  /// Generates only one carry-select block
  /// Return list of carry-ripple block sizes starting from
  /// the LSB connected one.
  /// [adderWidth] is a whole width of adder.
  static List<int> splitSelectAdderAlgorithmSingleBlock(int adderWidth) {
    final splitData = <int>[adderWidth];
    return splitData;
  }

  /// Adder ripple-carry block size computation algorithm.
  /// Generates 4 bit carry-select blocks with 1st entry width adjusted down.
  /// Return list of carry-ripple block sizes starting from
  /// the LSB connected one.
  /// [adderWidth] is a whole width of adder.
  static List<int> splitSelectAdderAlgorithm4Bit(int adderWidth) {
    final blockNb = (adderWidth / 4.0).ceil();
    final firstBlockSize = adderWidth - (blockNb - 1) * 4;
    final splitData = <int>[firstBlockSize];
    for (var i = 1; i < blockNb; ++i) {
      splitData.add(4);
    }
    return splitData;
  }

  /// Constructs a [CarrySelectCompoundAdder].
  CarrySelectCompoundAdder(super.a, super.b,
      {Adder Function(Logic a, Logic b, {Logic? carryIn, String name})
          adderGen = ParallelPrefixAdder.new,
      super.name = 'cs_compound_adder',
      List<int> Function(int) widthGen =
          splitSelectAdderAlgorithmSingleBlock}) {
    // output bits lists
    final sumList0 = <Logic>[];
    final sumList1 = <Logic>[];
    // carryout of previous ripple-carry adder block
    // for sum and sum+1
    Logic? carry0;
    Logic? carry1;
    // Get size of each ripple-carry adder block
    final adderSplit = widthGen(a.width);
    // 1st output bit index of each block
    var blockStartIdx = 0;
    for (var i = 0; i < adderSplit.length; ++i) {
      // input width of current ripple-carry adder block
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
      // Build ripple-carry adders for 0 and 1 carryin values
      final fullAdder0 =
          adderGen(blockA, blockB, carryIn: Const(0), name: 'block0_$i');
      final fullAdder1 =
          adderGen(blockA, blockB, carryIn: Const(1), name: 'block1_$i');
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

    // append carryout bit
    sumList0.add(carry0!);
    sumList1.add(carry1!);

    sum <= sumList0.rswizzle();
    sum1 <= sumList1.rswizzle();
  }
}
