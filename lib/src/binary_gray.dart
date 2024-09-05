// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_gray.dart
// A converter that can transform binary values into Gray code values or Gray
// code values into binary values.
//
// 2023 October 5
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:rohd/rohd.dart';

/// A module for converting binary values to Gray code representation.
///
/// The [BinaryToGrayConverter] class represents a module that takes a binary
/// value as input and produces the equivalent Gray code representation as
/// output. It internally uses the [binaryToGray] function for the
/// conversion.
class BinaryToGrayConverter extends Module {
  /// The Gray code representation output of the converter.
  ///
  /// This [Logic] value represents the Gray code representation of the binary
  /// input provided to the converter. It can be accessed using
  /// the [gray] getter.
  Logic get gray => output('gray');

  /// Creates a [BinaryToGrayConverter] instance with the specified binary
  /// input.
  ///
  /// The [binary] parameter is the binary input that you want to convert
  /// to Gray code. The width of the input [binary] determines the width
  /// of the Gray code output.
  BinaryToGrayConverter(Logic binary) {
    final inputWidth = binary.width;
    binary = addInput('binary', binary, width: inputWidth);
    final grayVal = addOutput('gray', width: inputWidth);

    Combinational([
      Case(
          binary,
          [
            for (var i = 0; i < (1 << inputWidth); i++)
              CaseItem(Const(i, width: inputWidth), [
                grayVal <
                    Const(binaryToGray(LogicValue.ofInt(i, inputWidth)),
                        width: inputWidth)
              ])
          ],
          conditionalType: ConditionalType.unique)
    ]);
  }

  /// Converts a binary value represented by [binary] to Gray code.
  ///
  /// Given a [binary] value, this function return [LogicValue]
  /// representing the equivalent Gray code.
  ///
  /// For each bit in the [binary] input, starting from the least significant
  /// bit (index 0), the function calculates the corresponding Gray code bit
  /// based on XOR operation with the previous bit. The resulting Gray code
  /// bits are returned.
  ///
  /// Returns [LogicValue] representing the Gray code.
  static LogicValue binaryToGray(LogicValue binary) {
    final reverseBit = binary.reversed;
    final binList = reverseBit.toList().asMap().entries.map((entry) {
      final currentBit = entry.value;
      final idx = entry.key;
      if (idx == 0) {
        return currentBit;
      } else {
        final previousIndex = reverseBit[idx - 1];
        return currentBit ^ previousIndex;
      }
    }).toList();
    return binList.swizzle();
  }
}

/// A module for converting Gray code to binary representation.
///
/// The [GrayToBinaryConverter] class represents a module that takes a Gray
/// code value as input and produces the equivalent binary representation as
/// output. It internally uses the [grayToBinary] function for the
/// conversion
class GrayToBinaryConverter extends Module {
  /// The binary representation output of the converter.
  ///
  /// This [Logic] value represents the binary representation of the Gray code
  /// input provided to the converter. It can be accessed using the [binary]
  /// getter.
  Logic get binary => output('binary');

  /// Creates a [GrayToBinaryConverter] instance with the specified Gray code
  /// input.
  ///
  /// The [gray] parameter is the Gray code input that you want to convert to
  /// binary. The width of the input [gray] determines the width of the binary
  /// output.
  GrayToBinaryConverter(Logic gray) {
    final inputWidth = gray.width;
    gray = addInput('gray', gray, width: inputWidth);
    final binaryVal = addOutput('binary', width: inputWidth);

    Combinational([
      Case(
          gray,
          [
            for (var i = 0; i < (1 << inputWidth); i++)
              CaseItem(Const(i, width: inputWidth), [
                binaryVal <
                    Const(grayToBinary(LogicValue.ofInt(i, inputWidth)),
                        width: inputWidth),
              ]),
          ],
          conditionalType: ConditionalType.unique),
    ]);
  }

  /// Converts a Gray code value represented by [gray] to binary.
  ///
  /// Given a [gray] value, this function return [LogicValue]
  /// representing the equivalent binary representation.
  ///
  /// For each bit in the [gray] input, starting from the least significant bit
  /// (index 0), the function calculates the corresponding binary bit based
  /// on XOR operation with the previous binary bit.
  ///
  /// Return [LogicValue] representing the binary representation.
  static LogicValue grayToBinary(LogicValue gray) {
    final reverseGray = gray.reversed;
    final grayList = reverseGray.toList();
    var previousBit = LogicValue.zero;

    final binaryList = grayList.map((currentBit) {
      final binaryBit = currentBit ^ previousBit;
      previousBit = binaryBit;
      return binaryBit;
    }).toList();

    return binaryList.swizzle();
  }
}
