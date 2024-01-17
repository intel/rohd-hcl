import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

bool _isPowerOfTwo(int n) => n != 0 && (n & (n - 1) == 0);

enum HammingType {
  /// Single error correct (SEC), but cannot detect double bit errors.
  sec,

  /// Single error correct, double error detect (SECDED).
  secded
}

class HammingEccTransmitter extends ErrorCheckingTransmitter {
  final HammingType hammingType;

  HammingEccTransmitter(super.data,
      {super.name = 'hamming_ecc_tx', this.hammingType = HammingType.sec})
      : super(codeWidth: _parityBitsRequired(data.width));

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
  Logic calculateCode() {
    final parityBits = List<Logic?>.generate(code.width, (index) => null);
    final dataBits = List<Logic>.generate(
        data.width, (index) => Logic(name: 'd${index + 1}')..gets(data[index]));

    var dataIdx = 0;
    for (var i = 1; i <= transmission.width; i++) {
      if (!_isPowerOfTwo(i)) {
        final ilv = LogicValue.ofInt(i, code.width);

        for (var p = 0; p < code.width; p++) {
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

    return [
      for (var i = 0; i < code.width; i++)
        Logic(name: 'p${1 << i}')..gets(parityBits[i]!),
    ].rswizzle();
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

  @override
  Logic get correctedData => super.correctedData!;

  ///TODO
  HammingEccReceiver(super.transmission,
      {super.name = 'hamming_ecc_rx', this.hammingType = HammingType.sec})
      : super(
            codeWidth: _codeWidthFromBusWidth(transmission.width),
            supportsErrorCorrection: true) {
    _syndrome <=
        code ^
            HammingEccTransmitter(originalData, hammingType: hammingType).code;

    final correction = Logic(name: 'correction', width: transmission.width)
      ..gets(mux(
        error,
        (Const(1, width: transmission.width + 1) << _syndrome).getRange(1),
        Const(0, width: transmission.width),
      ));

    final encodingToDataMap = _encodingToData();

    _correctedData <=
        [
          for (var i = 1; i <= transmission.width; i++)
            if (encodingToDataMap.containsKey(i))
              Logic(name: 'd${encodingToDataMap[i]! + 1}')
                ..gets(originalData[encodingToDataMap[i]] ^ correction[i - 1])
        ].rswizzle();
  }

  late final Logic _correctedData = Logic(width: originalData.width);
  late final Logic _syndrome = Logic(name: 'syndrome', width: code.width);

  @override
  Logic calculateCorrectableError() => _syndrome.or(); //TODO

  @override
  Logic? calculateCorrectedData() => _correctedData;

  @override
  Logic calculateUncorrectableError() => Const(0); //TODO
}
