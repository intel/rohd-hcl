import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd/rohd.dart';

Future<void> main() async {
  final original = Logic(width: 16)..put(10);
  final rotateAmount = Logic(width: 8)..put(5);
  final mod = RotateLeft(original, rotateAmount, maxAmount: 10);
  await mod.build();
  print(mod.generateSynth());
  final rotated = mod.rotated;
}
