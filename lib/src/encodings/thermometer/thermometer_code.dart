// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// thermometer_code.dart
// Binary and thermometer-code conversion.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Encodes an unsigned count as contiguous low-order ones.
///
/// [encoded] has `outputWidth` bits. Values greater than `outputWidth` are
/// saturated and reported by [overflow].
/// {@category Encodings}
class BinaryToThermometer extends Module {
  /// Encoded thermometer value.
  Logic get encoded => output('encoded');

  /// Whether the input exceeds the representable thermometer count.
  Logic get overflow => output('overflow');

  /// Creates a binary-to-thermometer encoder.
  BinaryToThermometer(
    Logic binary, {
    required int outputWidth,
    super.name = 'binary_to_thermometer',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName: definitionName ??
              'BinaryToThermometer_I${binary.width}_'
                  'O$outputWidth',
        ) {
    if (outputWidth < 1) {
      throw ArgumentError.value(
          outputWidth, 'outputWidth', 'Must be positive.');
    }
    binary = addInput('binary', binary, width: binary.width);
    final compareWidth = binary.width > outputWidth.bitLength
        ? binary.width
        : outputWidth.bitLength;
    final count = binary.zeroExtend(compareWidth);
    addOutput('encoded', width: outputWidth) <=
        [
          for (var bit = outputWidth - 1; bit >= 0; bit--)
            count.gt(Const(bit, width: compareWidth)),
        ].concat();
    addOutput('overflow') <= count.gt(Const(outputWidth, width: compareWidth));
  }
}

/// Decodes contiguous low-order ones into their unsigned count.
///
/// [valid] is low for non-thermometer patterns. [binary] is the population
/// count even when the pattern is invalid.
/// {@category Encodings}
class ThermometerToBinary extends Module {
  /// Population count of the input bits.
  Logic get binary => output('binary');

  /// Whether the input consists of contiguous low-order ones.
  Logic get valid => output('valid');

  /// Creates a thermometer-to-binary decoder.
  ThermometerToBinary(
    Logic thermometer, {
    super.name = 'thermometer_to_binary',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName:
              definitionName ?? 'ThermometerToBinary_W${thermometer.width}',
        ) {
    if (thermometer.width < 1) {
      throw ArgumentError.value(
          thermometer.width, 'thermometer.width', 'Must be positive.');
    }
    thermometer =
        addInput('thermometer', thermometer, width: thermometer.width);
    final countWidth = thermometer.width.bitLength;
    Logic count = Const(0, width: countWidth);
    for (final bit in thermometer.elements) {
      count = count + bit.zeroExtend(countWidth);
    }
    addOutput('binary', width: countWidth) <= count;
    final invalid = [
      for (var bit = 1; bit < thermometer.width; bit++)
        thermometer[bit] & ~thermometer[bit - 1],
    ];
    addOutput('valid') <= (invalid.isEmpty ? Const(1) : ~invalid.concat().or());
  }
}
