// Copyright (C) 2021-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

int bitReverse(int value, int bits) {
  var reversed = 0;
  for (var i = 0; i < bits; i++) {
    reversed <<= 1;
    reversed |= value & 1;
    value >>= 1;
  }
  return reversed;
}

class BitReversal extends Module {
  LogicArray get out => output('out') as LogicArray;

  BitReversal(LogicArray input, {super.name = 'bit_reversal'})
      : assert(input.dimensions.length == 1, 'Can only bit reverse 1D arrays') {
    input = addInputArray(
      'input_array',
      input,
      dimensions: input.dimensions, // it seems like these are needed
      elementWidth: input.elementWidth,
      numUnpackedDimensions: input.numUnpackedDimensions,
    );

    final out = addOutputArray(
      'out',
      dimensions: input.dimensions,
      elementWidth: input.elementWidth,
      numUnpackedDimensions: input.numUnpackedDimensions,
    );

    final length = input.dimensions[0];
    final bits = log2Ceil(length);

    for (var i = 0; i < length; i++) {
      out.elements[bitReverse(i, bits)] <= input.elements[i];
    }
  }
}
