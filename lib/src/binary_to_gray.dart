// Copyright (C) 2021-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_to_gray.dart
// A converter to convert binary value to gray value.
//
// 2023 October 2
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:rohd/rohd.dart';

/// Add doc
class BinaryToGrayConverter extends Module {
  /// Add doc
  Logic get grayVal => output('gray_value');

  /// Add doc
  BinaryToGrayConverter(Logic binaryInput) {
    final inputWidth = binaryInput.width;
    binaryInput = addInput('binaryInput', binaryInput, width: inputWidth);
    final grayVal = addOutput('gray_value', width: inputWidth);

    Combinational([
      //Assignment Here
      Case(binaryInput, conditionalType: ConditionalType.unique, [
        CaseItem(binaryInput, [
          grayVal <
              Const(binaryToGrayMap(binaryInput).swizzle(), width: inputWidth)
        ])
      ], defaultItem: [
        grayVal < binaryInput
      ])
    ]);
  }

  /// Add doc
  List<LogicValue> binaryToGrayMap(Logic binary) {
    final reverseBit = binary.value.toList().swizzle();
    final binList = reverseBit.toList().asMap().entries.map((entry) {
      final currentBit = entry.value;
      final idx = entry.key;
      if (idx == 0) {
        return currentBit;
      } else {
        final previousIndex = reverseBit[idx - 1];
        return currentBit ^ previousIndex;
      }
    });
    return binList.toList();
  }
}

void main() async {
  final binaryInput = Logic(name: 'binaryInput', width: 8);
  binaryInput.put(bin('10110011'));
  final binToGray = BinaryToGrayConverter(binaryInput);
  await binToGray.build();

  print(binToGray.generateSynth());
  print(binToGray.grayVal.value.toString(includeWidth: false));
}
