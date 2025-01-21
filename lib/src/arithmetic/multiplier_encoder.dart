// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// muliplier_encoder.dart
// Generation of Booth Encoded partial products for multiplication
//
// 2024 May 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A bundle for the leaf radix compute nodes. This holds the multiples
/// of the multiplicand that are needed for encoding
class RadixEncode extends LogicStructure {
  /// Which multiples need to be selected
  final Logic multiples;

  /// 'sign' of multiple.
  final Logic sign;

  /// The [row] that is encoded by this RadixEncode (encoding an
  /// overlapping segment of the multiplier).
  late final int row;

  /// Structure for holding Radix Encoding
  RadixEncode(int row, {required int numMultiples})
      : this._(
            Logic(
                width: numMultiples,
                name: 'multiples',
                naming: Naming.mergeable),
            Logic(name: 'sign'),
            row);

  RadixEncode._(this.multiples, this.sign, this.row, {String? name})
      : super([multiples, sign], name: name ?? 'RadixLogic');

  @override
  RadixEncode clone({String? name}) =>
      RadixEncode(row, numMultiples: multiples.width);
}

/// Base interface for radix radixEncoder
class RadixEncoder {
  /// The radix of the radixEncoder
  int radix;

  /// Constructor for setting up a radix encoding block
  RadixEncoder(this.radix) {
    if (pow(2.0, log2Ceil(radix)) != radix) {
      throw RohdHclException('radix must be a power of 2');
    }
  }

  /// Encode a multiplier slice into the Booth encoded value
  RadixEncode encode(Logic multiplierSlice, int row) {
    if (multiplierSlice.width != log2Ceil(radix) + 1) {
      throw RohdHclException('multiplier slice width ${multiplierSlice.width}'
          'must be same length as log(radix)+1=${log2Ceil(radix) + 1}');
    }
    final width = log2Ceil(radix) + 1;
    final inputXor = Logic(width: width);
    inputXor <=
        (multiplierSlice ^ (multiplierSlice >>> 1))
            .slice(multiplierSlice.width - 1, 0)
            .named('${multiplierSlice.name}_xor', naming: Naming.mergeable);

    final multiples = <Logic>[];
    for (var i = 2; i < radix + 1; i += 2) {
      final variantA = LogicValue.ofInt(i - 1, width);
      final xorA = variantA ^ (variantA >>> 1);
      final variantB = LogicValue.ofInt(i, width);
      final xorB = variantB ^ (variantB >>> 1);
      // Multiples don't agree on a bit position so we will skip that position
      final multiplesDisagree = xorA ^ xorB;
      // Where multiples agree, we need the sense or direction (1 or 0)
      final senseMultiples = xorA & xorB;

      multiples.add([
        for (var j = 0; j < width - 1; j++)
          if (multiplesDisagree[j].isZero)
            if (senseMultiples[j].isZero) ~inputXor[j] else inputXor[j]
      ].swizzle().and().named('multiple${i}_of_${multiplierSlice.name}',
          naming: Naming.mergeable));
    }

    final multiplesR = multiples
        .rswizzle()
        .named('multiples_reversed_r$row', naming: Naming.mergeable);

    return RadixEncode._(multiplesR,
        multiplesR.or() & multiplierSlice[multiplierSlice.width - 1], row);
  }
}

/// A class that generates the Booth encoding of the multipler.
class MultiplierEncoder {
  /// Access the multiplier
  final Logic multiplier;

  /// Number of rows that are Booth-encoded.
  late final int rows;

  /// The multiplier value, sign extended as appropriate to be divisible
  /// by the RadixEncoder width using overlapping (by one) bitslices.
  Logic _extendedMultiplier = Logic();

  /// Store the [RadixEncoder] used.
  late final RadixEncoder _encoder;

  late final _encodings = <RadixEncode>[];

  /// Generate the Booth encoding of an input [multiplier] using
  /// [radixEncoder].
  ///
  /// [signedMultiplier] generates a fixed signed encoder versus using
  /// [selectSignedMultiplier] which is a runtime sign selection [Logic]
  /// in which case [signedMultiplier] must be false.
  MultiplierEncoder(this.multiplier, RadixEncoder radixEncoder,
      {Logic? selectSignedMultiplier, bool signedMultiplier = false})
      : _encoder = radixEncoder {
    if (signedMultiplier && (selectSignedMultiplier != null)) {
      throw RohdHclException('sign reconfiguration requires signed=false');
    }
    // Unsigned encoding wants to overlap past the multipler
    if (signedMultiplier) {
      rows = ((multiplier.width + (signedMultiplier ? 0 : 1)) /
              log2Ceil(radixEncoder.radix))
          .ceil();
    } else {
      rows = (((multiplier.width + 1) % (log2Ceil(radixEncoder.radix)) == 0)
              ? 0
              : 1) +
          ((multiplier.width + 1) ~/ log2Ceil(radixEncoder.radix));
    }
    // slices overlap by 1 and start at -1a
    if (selectSignedMultiplier == null) {
      _extendedMultiplier = (signedMultiplier
              ? multiplier.signExtend(rows * (log2Ceil(radixEncoder.radix)))
              : multiplier.zeroExtend(rows * (log2Ceil(radixEncoder.radix))))
          .named('extended_multiplier', naming: Naming.mergeable);
    } else {
      final len = multiplier.width;
      final sign = multiplier[len - 1];
      final extension = [
        for (var i = len - 1; i < (rows * (log2Ceil(radixEncoder.radix))); i++)
          mux(selectSignedMultiplier, sign, Const(0))
      ];
      _extendedMultiplier = (multiplier.elements + extension)
          .rswizzle()
          .named('extended_multiplier', naming: Naming.mergeable);
    }
    for (var i = 0; i < rows; i++) {
      _encodings.add(getEncoding(i));
    }
  }

  /// Compute the Booth encoding for the row
  RadixEncode getEncoding(int row) {
    if (row >= rows) {
      throw RohdHclException('row $row is not < number of encoding rows $rows');
    }
    final base = row * log2Ceil(_encoder.radix);
    final multiplierSlice = [
      if (row > 0)
        _extendedMultiplier.slice(base + log2Ceil(_encoder.radix) - 1, base - 1)
      else
        [
          _extendedMultiplier.slice(base + log2Ceil(_encoder.radix) - 1, base),
          Const(0)
        ].swizzle()
    ].first.named('mult_slice_r$row', naming: Naming.mergeable);
    return _encoder.encode(multiplierSlice, row);
  }

  /// Retrieve the Booth encoding for the row
  RadixEncode fetchEncoding(int row) {
    if (row >= rows) {
      throw RohdHclException('row $row is not < number of encoding rows $rows');
    }
    return _encodings[row];
  }
}
