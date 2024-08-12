// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// muliplier_encoder.dart
// Generation of Booth Encoded partial products for multiplication
//
// 2024 May 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A bundle for the leaf radix compute nodes. This holds the multiples
/// of the multiplicand that are needed for encoding
class RadixEncode extends LogicStructure {
  /// Which multiples need to be selected
  final Logic multiples;

  /// 'sign' of multiple
  final Logic sign;

  /// Structure for holding Radix Encoding
  RadixEncode({required int numMultiples})
      : this._(
            Logic(width: numMultiples, name: 'multiples'), Logic(name: 'sign'));

  RadixEncode._(this.multiples, this.sign, {String? name})
      : super([multiples, sign], name: name ?? 'RadixLogic');

  @override
  RadixEncode clone({String? name}) =>
      RadixEncode(numMultiples: multiples.width);
}

/// Base interface for radix radixEncoder
class RadixEncoder {
  /// The radix of the radixEncoder
  int radix;

  /// Baseline call for setting up an empty radixEncoder
  RadixEncoder(this.radix);

  /// Encode a multiplier slice into the Booth encoded value
  RadixEncode encode(Logic multiplierSlice) {
    if (multiplierSlice.width != log2Ceil(radix) + 1) {
      throw RohdHclException('multiplier slice width ${multiplierSlice.width}'
          'must be same length as log(radix)+1=${log2Ceil(radix) + 1}');
    }
    final width = log2Ceil(radix) + 1;
    final inputXor = Logic(width: width);
    inputXor <=
        (multiplierSlice ^ (multiplierSlice >>> 1))
            .slice(multiplierSlice.width - 1, 0);

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
      ].swizzle().and());
    }

    return RadixEncode._(
        multiples.rswizzle(), multiplierSlice[multiplierSlice.width - 1]);
  }
}

/// A class that generates the Booth encoding of the multipler
class MultiplierEncoder {
  /// Access the multiplier
  final Logic multiplier;

  /// Number of row radixEncoders
  late final int rows;

  /// The multiplier value, sign extended as appropriate to be divisible
  /// by the RadixEncoder overlapping bitslices.
  Logic _extendedMultiplier = Logic();
  late final RadixEncoder _encoder;
  late final int _sliceWidth;

  /// Generate an encoding of the input multiplier
  MultiplierEncoder(this.multiplier, RadixEncoder radixEncoder,
      {required bool signed})
      : _encoder = radixEncoder,
        _sliceWidth = log2Ceil(radixEncoder.radix) + 1 {
    // Unsigned encoding wants to overlap past the multipler
    if (signed) {
      rows =
          ((multiplier.width + (signed ? 0 : 1)) / log2Ceil(radixEncoder.radix))
              .ceil();
    } else {
      rows = (((multiplier.width + 1) % (_sliceWidth - 1) == 0) ? 0 : 1) +
          ((multiplier.width + 1) ~/ log2Ceil(radixEncoder.radix));
    }
    // slices overlap by 1 and start at -1
    _extendedMultiplier = (signed
        ? multiplier.signExtend(rows * (_sliceWidth - 1))
        : multiplier.zeroExtend(rows * (_sliceWidth - 1)));
  }

  /// Retrieve the Booth encoding for the row
  RadixEncode getEncoding(int row) {
    if (row >= rows) {
      throw RohdHclException('row $row is not < number of encoding rows $rows');
    }
    final base = row * (_sliceWidth - 1);
    final multiplierSlice = [
      if (row > 0)
        _extendedMultiplier.slice(base + _sliceWidth - 2, base - 1)
      else
        [_extendedMultiplier.slice(base + _sliceWidth - 2, base), Const(0)]
            .swizzle()
    ];
    return _encoder.encode(multiplierSlice.first);
  }
}

/// A class accessing the multiples of the multiplicand at a position
class MultiplicandSelector {
  /// radix of the selector
  int radix;

  /// The bit shift of the selector (typically overlaps 1)
  int shift;

  /// New width of partial products generated from the multiplicand
  int get width => multiplicand.width + shift - 1;

  /// Access the multiplicand
  Logic multiplicand = Logic();

  /// Place to store multiples of the multiplicand
  late LogicArray multiples;

  /// Generate required multiples of multiplicand
  MultiplicandSelector(this.radix, this.multiplicand, {required bool signed})
      : shift = log2Ceil(radix) {
    if (radix > 16) {
      throw RohdHclException('Radices beyond 16 are not yet supported');
    }
    final width = multiplicand.width + shift;
    final numMultiples = radix ~/ 2;
    multiples = LogicArray([numMultiples], width);
    final extendedMultiplicand = signed
        ? multiplicand.signExtend(width)
        : multiplicand.zeroExtend(width);

    for (var pos = 0; pos < numMultiples; pos++) {
      final ratio = pos + 1;
      multiples.elements[pos] <=
          switch (ratio) {
            1 => extendedMultiplicand,
            2 => extendedMultiplicand << 1,
            3 => (extendedMultiplicand << 2) - extendedMultiplicand,
            4 => extendedMultiplicand << 2,
            5 => (extendedMultiplicand << 2) + extendedMultiplicand,
            6 => (extendedMultiplicand << 3) - (extendedMultiplicand << 1),
            7 => (extendedMultiplicand << 3) - extendedMultiplicand,
            8 => extendedMultiplicand << 3,
            _ => throw RohdHclException('Radix is beyond 16')
          };
    }
  }

  /// Retrieve the multiples of the multiplicand at current bit position
  Logic getMultiples(int col) => [
        for (var i = 0; i < multiples.elements.length; i++)
          multiples.elements[i][col]
      ].swizzle().reversed;

  Logic _select(Logic multiples, RadixEncode encode) =>
      (encode.multiples & multiples).or() ^ encode.sign;

  /// Select the partial product term from the multiples using a RadixEncode
  Logic select(int col, RadixEncode encode) =>
      _select(getMultiples(col), encode);
}
