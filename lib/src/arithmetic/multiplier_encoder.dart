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

  /// Constructor for setting up a radix encoding block
  RadixEncoder(this.radix) {
    if (pow(2.0, log2Ceil(radix)) != radix) {
      throw RohdHclException('radix must be a power of 2');
    }
  }

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
      {Logic? selectSigned, bool signed = false})
      : _encoder = radixEncoder,
        _sliceWidth = log2Ceil(radixEncoder.radix) + 1 {
    if (signed && (selectSigned != null)) {
      throw RohdHclException('sign reconfiguration requires signed=false');
    }
    // Unsigned encoding wants to overlap past the multipler
    if (signed) {
      rows =
          ((multiplier.width + (signed ? 0 : 1)) / log2Ceil(radixEncoder.radix))
              .ceil();
    } else {
      rows = (((multiplier.width + 1) % (_sliceWidth - 1) == 0) ? 0 : 1) +
          ((multiplier.width + 1) ~/ log2Ceil(radixEncoder.radix));
    }
    // slices overlap by 1 and start at -1a
    if (selectSigned == null) {
      _extendedMultiplier = (signed
          ? multiplier.signExtend(rows * (_sliceWidth - 1))
          : multiplier.zeroExtend(rows * (_sliceWidth - 1)));
    } else {
      final len = multiplier.width;
      final sign = multiplier[len - 1];
      final extension = [
        for (var i = len - 1; i < (rows * (_sliceWidth - 1)); i++)
          mux(selectSigned, sign, Const(0))
      ];
      _extendedMultiplier = (multiplier.elements + extension).rswizzle();
    }
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
