// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// one_hot_test.dart
// Test of one_hot codec.
//
// 2023 February 24
// Author: Desmond Kirkpatrick
//

import 'dart:io';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/one_hot.dart';
import 'package:rohd_hcl/src/utils.dart';
import 'package:test/test.dart';

void main() {
  test('simple_encode', () {
    // Compute the binary value for a 1hot at position 'pos'
    for (var pos = 0; pos < 1000; pos++) {
      final w = log2Ceil(pos + 1);
      final val = BigInt.from(2).pow(pos);

      expect(BinaryToOneHot(Const(pos, width: w)).encoded.value,
          equals(LogicValue.ofBigInt(val, pow(2, w).toInt())));
    }
  });
  test('simple_decode', () async {
    // Compute the first 1 in a binary value
    // Limited to 64 by the Case matching inside
    for (var pos = 0; pos < 1000; pos++) {
      final val = BigInt.from(2).pow(pos);
      final computed = OneHotToBinary(Const(val, width: pos + 1)).binary;
      final expected = LogicValue.ofInt(pos, computed.width);
      expect(computed.value, equals(expected));
    }
    const pos = 32;
    final val = BigInt.from(2).pow(pos);
    final mod = OneHotToBinary(Const(val, width: pos + 1));
    await mod.build();
    final res = mod.generateSynth();
    File('${mod.definitionName}.v').openWrite().write(res);
  });
  test('tree_decode', () {
    // Compute the binary value (or bit position) of a one-hot encoded value
    for (var pos = 0; pos < 5120; pos++) {
      final val = BigInt.from(2).pow(pos);
      final computed = TreeOneHotToBinary(Const(val, width: pos + 1)).binary;
      final expected = LogicValue.ofInt(pos, computed.width);
      expect(computed.value, equals(expected));
    }
  });
}
