import 'package:rohd/rohd.dart';

// ignore: implementation_imports
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class RotateConfigurator extends Configurator {
  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'Direction': directionKnob,
    'Original Width': originalWidthKnob,
    'Rotate Amount Width': rotateWidthKnob,
    'Max Rotate Amount': maxAmountKnob,
  };

  final directionKnob = ChoiceConfigKnob<RotateDirection>(
      [RotateDirection.left, RotateDirection.right],
      value: RotateDirection.right);
  final originalWidthKnob = IntConfigKnob(value: 16);
  final rotateWidthKnob = IntConfigKnob(value: 8);
  final maxAmountKnob = IntConfigKnob(value: 20);

  @override
  final String name = 'Rotate';

  @override
  Module createModule() {
    final rotateConstructor = directionKnob.value == RotateDirection.left
        ? RotateLeft.new
        : RotateRight.new;
    return rotateConstructor(
      Logic(width: originalWidthKnob.value),
      Logic(width: rotateWidthKnob.value),
      maxAmount: maxAmountKnob.value,
    );
  }

  @override
  List<Vector> get exampleTestVectors => [
        for (var i = 0; i <= 9; i++)
          Vector({'original': bin('11000'), 'rotate_amount': i}, {}),
      ];
}
