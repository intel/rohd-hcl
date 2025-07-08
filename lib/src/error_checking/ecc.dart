// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ecc.dart
// Error correcting code hardware generators.
//
// 2024 January 18
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Type of Hamming code, with different characteristics for error correction,
/// error detection, and number of check bits required.
enum HammingType {
  /// Single error correction (SEC), but cannot detect double bit errors.
  sec._(hasExtraParityBit: false, hasCorrection: true),

  /// Double error detection (DED): can detect up to double-bit errors, but
  /// performs no correction.
  sedded._(hasExtraParityBit: false, hasCorrection: false),

  /// Single error correction, double error detection (SECDED).
  secded._(hasExtraParityBit: true, hasCorrection: true),

  /// Triple error detection (TED), can detect up to triple-bit errors, but
  /// performs no correction.
  seddedted._(hasExtraParityBit: true, hasCorrection: false);

  /// Indicates whether this type requires an additional parity bit.
  final bool hasExtraParityBit;

  /// Indicates whether this type supports correction of errors.
  final bool hasCorrection;

  /// Constrcut a [HammingType] with given characteristics.
  const HammingType._(
      {required this.hasExtraParityBit, required this.hasCorrection});

  /// The number of extra parity bits required for this type.
  int get _extraParityBits => hasExtraParityBit ? 1 : 0;
}

/// A transmitter for data which generates a Hamming code for error detection
/// and possibly correction.
class HammingEccTransmitter extends ErrorCheckingTransmitter {
  /// The type of Hamming code to use.
  final HammingType hammingType;

  /// Creates a [transmission] which includes a [code] that protects [data] with
  /// the specified [hammingType].
  HammingEccTransmitter(super.data,
      {super.name = 'hamming_ecc_tx', this.hammingType = HammingType.sec})
      : super(
            definitionName: 'hamming_ecc_transmitter_${hammingType.name}',
            codeWidth:
                _parityBitsRequired(data.width) + hammingType._extraParityBits);

  /// Calculates the number of parity bits required for a Hamming code to
  /// protect [dataWidth] bits.
  static int _parityBitsRequired(int dataWidth) {
    var m = 0;
    double k;
    do {
      m++;
      k = pow(2, m) - m - 1;
    } while (k < dataWidth);
    return m;
  }

  @override
  @protected
  Logic calculateCode() {
    final parityBits = List<Logic?>.generate(code.width, (index) => null);
    final dataBits = List<Logic>.generate(
        data.width, (index) => Logic(name: 'd${index + 1}')..gets(data[index]));

    final hammingCodeWidth = code.width - hammingType._extraParityBits;

    var dataIdx = 0;
    for (var i = 1;
        i <= transmission.width - hammingType._extraParityBits;
        i++) {
      if (!isPowerOfTwo(i)) {
        final ilv = LogicValue.ofInt(i, hammingCodeWidth);

        for (var p = 0; p < hammingCodeWidth; p++) {
          if (ilv[p].toBool()) {
            if (parityBits[p] == null) {
              parityBits[p] = dataBits[dataIdx];
            } else {
              parityBits[p] = parityBits[p]! ^ dataBits[dataIdx];
            }
          }
        }
        dataIdx++;
      }
    }

    var calculatedCode = [
      for (var i = 0; i < hammingCodeWidth; i++)
        Logic(name: 'p${1 << i}')..gets(parityBits[i]!),
    ].rswizzle();

    if (hammingType.hasExtraParityBit) {
      // extra parity bit is calculated by calculating parity across entire rest
      // of the transmission
      final pExtra = Logic(name: 'pExtra')
        ..gets(ParityTransmitter([calculatedCode, data].swizzle()).code);
      calculatedCode = [pExtra, calculatedCode].swizzle();
    }

    return calculatedCode;
  }
}

/// A receiver for transmissions sent with a Hamming code for error detection
/// and possibly correction.
class HammingEccReceiver extends ErrorCheckingReceiver {
  /// The type of Hamming code to use to understand the original [transmission].
  final HammingType hammingType;

  /// Consumes a [transmission] which includes a [code] that can check whether
  /// the [originalData] contains errors and possibly correct it to
  /// [correctedData], depending on the specified [hammingType].
  HammingEccReceiver(super.transmission,
      {super.name = 'hamming_ecc_rx',
      this.hammingType = HammingType.sec,
      String? definitionName})
      : super(
          codeWidth: _codeWidthFromTransmissionWidth(
                  transmission.width - hammingType._extraParityBits) +
              hammingType._extraParityBits,
          definitionName:
              definitionName ?? 'hamming_ecc_receiver_${hammingType.name}',
          supportsErrorCorrection: hammingType.hasCorrection,
        ) {
    final tx = HammingEccTransmitter(originalData, hammingType: hammingType);
    final hammingCode =
        hammingType.hasExtraParityBit ? code.getRange(0, -1) : code;
    final expectedHammingCode =
        tx.hammingType.hasExtraParityBit ? tx.code.getRange(0, -1) : tx.code;

    _syndrome <= hammingCode ^ expectedHammingCode;
    final hammingError = _syndrome.or();

    final hammingTransmissionWidth =
        transmission.width - hammingType._extraParityBits;

    if (hammingType.hasCorrection) {
      final correction =
          Logic(name: 'correction', width: hammingTransmissionWidth)
            ..gets(
              (Const(1, width: hammingTransmissionWidth + 1) << _syndrome)
                  .getRange(1),
            );

      final encodingToDataMap = _encodingToData();

      _correctedData <=
          [
            for (var i = 1; i <= hammingTransmissionWidth; i++)
              if (encodingToDataMap.containsKey(i))
                Logic(name: 'd${encodingToDataMap[i]! + 1}')
                  ..gets(originalData[encodingToDataMap[i]] ^ correction[i - 1])
          ].rswizzle();
    }

    Logic? extraErr;
    if (hammingType.hasExtraParityBit) {
      extraErr = ParityReceiver(transmission).uncorrectableError;
    }

    switch (hammingType) {
      case HammingType.sec:
        _correctableError <= hammingError;
        _uncorrectableError <= Const(0);
      case HammingType.sedded:
        _correctableError <= Const(0);
        _uncorrectableError <= hammingError;
      case HammingType.secded:
        // error location(s) -> meaning
        //  ---------------- | ----------------
        // extra & !hamming  -> bit flip on extra parity, hamming can ignore
        //                      correctable single-bit
        // extra & hamming   -> error on hamming region occurred,
        //                      correctable single-bit
        // !extra & !hamming -> no error
        // !extra & hamming  -> extra parity has no error, but hamming does
        //                      double-bit error, uncorrectable
        _correctableError <= extraErr!;
        _uncorrectableError <= ~extraErr & hammingError;
      case HammingType.seddedted:
        _correctableError <= Const(0);
        _uncorrectableError <= extraErr! | hammingError;
    }
  }

  /// The "syndrome" used to decode an error pattern in Hamming parity bits
  /// into a correction pattern.
  late final Logic _syndrome =
      Logic(name: 'syndrome', width: code.width - hammingType._extraParityBits);

  /// The number of Hamming code bits that must have been included in a
  /// transmission of [transmissionWidth], not including any extra parity bit.
  static int _codeWidthFromTransmissionWidth(int transmissionWidth) =>
      log2Ceil(transmissionWidth + 1);

  /// Builds a mapping from Hamming bits encoding to data position (1-indexed).
  Map<int, int> _encodingToData() {
    final mapping = <int, int>{};
    var dataIdx = 0;
    for (var encodedIdx = 1; encodedIdx <= transmission.width; encodedIdx++) {
      if (!isPowerOfTwo(encodedIdx)) {
        mapping[encodedIdx] = dataIdx++;
      }
    }
    return mapping;
  }

  @override
  @protected
  Logic calculateCorrectableError() => _correctableError;
  late final Logic _correctableError = Logic();

  @override
  @protected
  Logic? calculateCorrectedData() =>
      hammingType.hasCorrection ? _correctedData : null;
  late final Logic _correctedData = Logic(width: originalData.width);

  @override
  @protected
  Logic calculateUncorrectableError() => _uncorrectableError;
  late final Logic _uncorrectableError = Logic();
}
