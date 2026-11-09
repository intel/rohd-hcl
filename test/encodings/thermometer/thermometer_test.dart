// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// thermometer_test.dart
// Tests for thermometer-code conversion.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  test('binary encoding saturates above the thermometer width', () async {
    final encoder = BinaryToThermometer(Logic(width: 4), outputWidth: 5);
    await encoder.build();
    final vectors = [
      for (var input = 0; input < 16; input++)
        Vector({
          'binary': input
        }, {
          'encoded': (1 << (input < 5 ? input : 5)) - 1,
          'overflow': input > 5 ? 1 : 0,
        }),
    ];
    await SimCompare.checkFunctionalVector(encoder, vectors);
    SimCompare.checkIverilogVector(encoder, vectors);
  });

  test('decoder counts bits and detects non-thermometer inputs', () async {
    final decoder = ThermometerToBinary(Logic(width: 5));
    await decoder.build();
    final vectors = [
      for (var input = 0; input < 32; input++)
        Vector({
          'thermometer': input
        }, {
          'binary': input.toRadixString(2).split('1').length - 1,
          'valid': (input & (input + 1)) == 0 ? 1 : 0,
        }),
    ];
    await SimCompare.checkFunctionalVector(decoder, vectors);
    SimCompare.checkIverilogVector(decoder, vectors);
  });

  for (final width in [1, 2, 4]) {
    test('width $width handles every binary and thermometer value', () async {
      final binaryWidth = width.bitLength;
      final encoder =
          BinaryToThermometer(Logic(width: binaryWidth), outputWidth: width);
      await encoder.build();
      final encodeVectors = [
        for (var input = 0; input < (1 << binaryWidth); input++)
          Vector({
            'binary': input
          }, {
            'encoded': (1 << (input < width ? input : width)) - 1,
            'overflow': input > width ? 1 : 0,
          }),
      ];
      await SimCompare.checkFunctionalVector(encoder, encodeVectors);
      SimCompare.checkIverilogVector(encoder, encodeVectors);
      await Simulator.reset();

      final decoder = ThermometerToBinary(Logic(width: width));
      await decoder.build();
      final decodeVectors = [
        for (var input = 0; input < (1 << width); input++)
          Vector({
            'thermometer': input
          }, {
            'binary': input.toRadixString(2).split('1').length - 1,
            'valid': (input & (input + 1)) == 0 ? 1 : 0,
          }),
      ];
      await SimCompare.checkFunctionalVector(decoder, decodeVectors);
      SimCompare.checkIverilogVector(decoder, decodeVectors);
    });
  }
}
