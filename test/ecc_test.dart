import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/error_checking/ecc.dart';
import 'package:test/test.dart';

void main() {
  test('ecc tx', () async {
    final mod = HammingEccTransmitter(Logic(width: 15));
    await mod.build();
    print(mod.generateSynth());
  });

  test('ecc rx', () async {
    final mod = HammingEccReceiver(Logic(width: 20));
    await mod.build();
    print(mod.generateSynth());
  });
}
