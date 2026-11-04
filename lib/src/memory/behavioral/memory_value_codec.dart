// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_value_codec.dart
// Lossless value encoding for behavioral memory models.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Lossless four-state values for images and generated behavioral metadata.
abstract final class MemoryValueCodec {
  /// Binary bits, optionally zero-extended, with no integer-width limitation.
  static String binary(LogicValue value, {int? width}) {
    final targetWidth = width ?? value.width;
    if (targetWidth <= 0 || targetWidth < value.width) {
      throw ArgumentError.value(targetWidth, 'width',
          'Must be positive and at least the value width.');
    }
    return value
        .toString(includeWidth: false)
        .toLowerCase()
        .padLeft(targetWidth, '0');
  }

  /// Encodes width explicitly and preserves X/Z without normalization.
  static Map<String, Object> encode(LogicValue value) =>
      {'width': value.width, 'bits': binary(value)};

  /// Decodes a validated value; malformed or truncated values throw.
  static LogicValue decode(Object? encoded) {
    if (encoded is! Map<String, Object?>) {
      throw const FormatException('A memory value must be an object.');
    }
    final width = encoded['width'];
    final bits = encoded['bits'];
    if (width is! int ||
        width <= 0 ||
        bits is! String ||
        bits.length != width ||
        !RegExp(r'^[01xXzZ]+$').hasMatch(bits)) {
      throw const FormatException('Expected width and exact four-state bits.');
    }
    return LogicValue.ofString(bits.toLowerCase());
  }
}
