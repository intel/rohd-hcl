import 'package:rohd/rohd.dart';
import 'package:rohd/src/signals/signals.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class HammingEccTransmitter extends ErrorCheckingTransmitter {
  HammingEccTransmitter(super.data, {super.name = 'hamming_ecc_tx'})
      : super(codeWidth: log2Ceil(data.width));

  bool _isPowerOfTwo(int n) => n != 0 && (n & (n - 1) == 0);

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
