// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inference_knobs.dart
// Shared typed format, tensor shape, and scheduling configuration controls.
//
// 2026 November 24
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Boundary exposed by independently reusable inference engines.
enum InferenceConfiguratorBoundary {
  /// Explicit synchronous actions without a transport protocol.
  actions,

  /// The existing ready/valid attachment shell.
  readyValid,
}

/// Groups the width and fractional precision of a fixed-point format.
class InferenceFixedPointFormatKnob extends GroupOfKnobs {
  /// Total packed width, including the sign bit when signed.
  final PositiveIntConfigKnob widthKnob;

  /// Number of fractional bits.
  final NonNegativeIntConfigKnob fractionBitsKnob;

  /// Creates fixed-point format controls.
  factory InferenceFixedPointFormatKnob({
    int width = 8,
    int fractionBits = 0,
  }) =>
      InferenceFixedPointFormatKnob._(
        PositiveIntConfigKnob(value: width),
        NonNegativeIntConfigKnob(value: fractionBits),
      );

  InferenceFixedPointFormatKnob._(this.widthKnob, this.fractionBitsKnob)
      : super({
          'Width': widthKnob,
          'Fraction Bits': fractionBitsKnob,
        }, name: 'Fixed-point format');

  /// Builds an integer lane or a fractional lane retaining its Q schema.
  Logic element({String? name, bool signed = true}) {
    if (fractionBitsKnob.value >= widthKnob.value) {
      throw ArgumentError('Fraction bits must be smaller than total width.');
    }
    if (fractionBitsKnob.value == 0) {
      return Logic(name: name, width: widthKnob.value);
    }
    return FixedPoint(
      integerWidth: widthKnob.value - fractionBitsKnob.value - (signed ? 1 : 0),
      fractionWidth: fractionBitsKnob.value,
      signed: signed,
      name: name,
    );
  }

  /// Builds a typed vector using this format.
  TypedLogicArray<Logic, LogicValue> array(int count,
          {String? name, bool signed = true, bool unpacked = false}) =>
      TypedLogicArray(
        [count],
        ({name}) => element(name: name, signed: signed),
        name: name,
        numUnpackedDimensions: unpacked ? 1 : 0,
      );
}

/// Groups tensor dimensions, element format, and packed/unpacked layout.
class InferenceTensorKnob extends GroupOfKnobs {
  /// Physical row count.
  final PositiveIntConfigKnob rowsKnob;

  /// Physical column count.
  final PositiveIntConfigKnob columnsKnob;

  /// Element width and fractional precision.
  final InferenceFixedPointFormatKnob formatKnob;

  /// Whether elements have a sign bit.
  final ToggleConfigKnob signedKnob;

  /// Whether tensor dimensions are unpacked.
  final ToggleConfigKnob unpackedKnob;

  /// Creates tensor shape and format controls.
  factory InferenceTensorKnob() => InferenceTensorKnob._(
        PositiveIntConfigKnob(value: 2),
        PositiveIntConfigKnob(value: 2),
        InferenceFixedPointFormatKnob(),
        ToggleConfigKnob(value: true),
        ToggleConfigKnob(value: false),
      );

  InferenceTensorKnob._(this.rowsKnob, this.columnsKnob, this.formatKnob,
      this.signedKnob, this.unpackedKnob)
      : super({
          'Rows': rowsKnob,
          'Columns': columnsKnob,
          'Element Format': formatKnob,
          'Signed Elements': signedKnob,
          'Unpacked Dimensions': unpackedKnob,
        }, name: 'Tensor');

  /// Creates a typed tile with matching numeric metadata and masks.
  InferenceTensorTile<Logic, LogicValue> tile({String? name}) {
    final prototype = formatKnob.element(signed: signedKnob.value);
    final width = formatKnob.widthKnob.value;
    final fraction = formatKnob.fractionBitsKnob.value;
    final format = fraction == 0
        ? (signedKnob.value
            ? InferenceNumericFormat.signedInteger(width)
            : InferenceNumericFormat.unsignedInteger(width))
        : InferenceNumericFormat.fixedPoint(
            signed: signedKnob.value,
            integerWidth: width - fraction - (signedKnob.value ? 1 : 0),
            fractionWidth: fraction,
          );
    return InferenceTensorTile(
      rowCount: rowsKnob.value,
      columnCount: columnsKnob.value,
      elementBuilder: prototype.clone,
      format: format,
      numUnpackedDimensions: unpackedKnob.value ? 2 : 0,
      name: name ?? 'tile',
    );
  }
}
