import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/signals/signals.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

bool _isPowerOfTwo(int n) => n != 0 && (n & (n - 1) == 0);

class HammingEccTransmitter extends ErrorCheckingTransmitter {
  HammingEccTransmitter(super.data, {super.name = 'hamming_ecc_tx'})
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
        data.width, (index) => Logic(name: 'd${index + 1}'));

    var dataIdx = 0;
    for (var i = 1; i <= bus.width; i++) {
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

  Map<int, int> get _encodingToData {
    final mapping = <int, int>{};
    var dataIdx = 0;
    for (var encodedIdx = 0; encodedIdx <= bus.width; encodedIdx++) {
      if (!_isPowerOfTwo(encodedIdx)) {
        mapping[encodedIdx] = dataIdx++;
      }
    }
    return mapping;
  }

  ///TODO
  HammingEccReceiver(super.bus, {super.name = 'hamming_ecc_rx'})
      : super(
            codeWidth: _codeWidthFromBusWidth(bus.width),
            supportsErrorCorrection: true) {
    _syndrome <= code ^ HammingEccTransmitter(originalData).code;

    final correction = Logic(name: 'correction', width: bus.width)
      ..gets(mux(
        error,
        BinaryToOneHot(_syndrome - 1).encoded.getRange(0, bus.width),
        Const(0, width: bus.width),
      ));

    _correctedData <=
        [
          for (var i = 0; i < bus.width; i++)
            if (_encodingToData.containsKey(i))
              Logic(name: 'd${_encodingToData[i]! + 1}')
                ..gets(originalData[_encodingToData[i]] ^ correction[i])
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
