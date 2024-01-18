import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

enum HammingType {
  /// Single error correct (SEC), but cannot detect double bit errors.
  sec(hasExtraParityBit: false, hasCorrection: true),

  /// Double error detect (DED), can detect double-bit errors, but performs no
  /// correction.
  ded(hasExtraParityBit: false, hasCorrection: false),

  /// Single error correct, double error detect (SECDED).
  secded(hasExtraParityBit: true, hasCorrection: true),

  /// Triple error detect (TED), can detect triple-bit errors, but performs no
  /// correction.
  ted(hasExtraParityBit: true, hasCorrection: false);

  final bool hasExtraParityBit;

  final bool hasCorrection;

  const HammingType(
      {required this.hasExtraParityBit, required this.hasCorrection});

  int get _extraParityBits => this.hasExtraParityBit ? 1 : 0;
}

/// Returns whether [n] is a power of two.
bool _isPowerOfTwo(int n) => n != 0 && (n & (n - 1) == 0);

class HammingEccTransmitter extends ErrorCheckingTransmitter {
  final HammingType hammingType;

  ///TODO
  HammingEccTransmitter(super.data,
      {super.name = 'hamming_ecc_tx', this.hammingType = HammingType.sec})
      : super(
            definitionName: 'hamming_ecc_transmitter_${hammingType.name}',
            codeWidth:
                _parityBitsRequired(data.width) + hammingType._extraParityBits);

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
      if (!_isPowerOfTwo(i)) {
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

class HammingEccReceiver extends ErrorCheckingReceiver {
  static int _codeWidthFromBusWidth(int busWidth) => log2Ceil(busWidth + 1);

  final HammingType hammingType;

  Map<int, int> _encodingToData() {
    final mapping = <int, int>{};
    var dataIdx = 0;
    for (var encodedIdx = 1; encodedIdx <= transmission.width; encodedIdx++) {
      if (!_isPowerOfTwo(encodedIdx)) {
        mapping[encodedIdx] = dataIdx++;
      }
    }
    return mapping;
  }

  ///TODO
  HammingEccReceiver(super.transmission,
      {super.name = 'hamming_ecc_rx', this.hammingType = HammingType.sec})
      : super(
          codeWidth: _codeWidthFromBusWidth(
                  transmission.width - hammingType._extraParityBits) +
              hammingType._extraParityBits,
          definitionName: 'hamming_ecc_receiver_${hammingType.name}',
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
      case HammingType.ded:
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
      case HammingType.ted:
        _correctableError <= Const(0);
        _uncorrectableError <= extraErr! | hammingError;
    }
  }

  late final Logic _correctableError = Logic();
  late final Logic _uncorrectableError = Logic();

  late final Logic _correctedData = Logic(width: originalData.width);
  late final Logic _syndrome =
      Logic(name: 'syndrome', width: code.width - hammingType._extraParityBits);

  @override
  @protected
  Logic calculateCorrectableError() => _correctableError;

  @override
  @protected
  Logic? calculateCorrectedData() =>
      hammingType.hasCorrection ? _correctedData : null;

  @override
  @protected
  Logic calculateUncorrectableError() => _uncorrectableError;
}
