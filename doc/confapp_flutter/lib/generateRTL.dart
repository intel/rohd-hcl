import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd/rohd.dart';

abstract class ConfigKnob {
  final String name;
  ConfigKnob(this.name);
}

class IntConfigKnob extends ConfigKnob {
  int? value;
  IntConfigKnob(super.name);
}

class StringConfigKnob extends ConfigKnob {
  String? value;
  StringConfigKnob(super.name);
}

abstract class ConfigGenerator {
  /// A list of config knobs to the specific components.
  List<ConfigKnob> get knobs;

  /// generate system verilog.
  Future<String> generate();
}

/// Use to generate system verilog.
class RotateGenerator extends ConfigGenerator {
  final IntConfigKnob originalKnob = IntConfigKnob('original');
  final IntConfigKnob rotateAmountKnob = IntConfigKnob('rotate_amount');
  final IntConfigKnob maxAmountKnob = IntConfigKnob('max_amount');
  final StringConfigKnob rotateNameKnob = StringConfigKnob('rotateNameKnob');
  // radio button to choose which component to generate? Rotate Left or Right

  @override
  late final List<ConfigKnob> knobs = [
    originalKnob,
    rotateAmountKnob,
    rotateNameKnob,
  ];

  @override
  Future<String> generate() async {
    final rotateLeft = RotateComponent(
      Logic(width: 10), // originalWidthKnob
      Logic(width: 10), // rotateAmountWidthKnob
      maxAmountKnob.value,
    ).rotateLeft;

    await rotateLeft.build();

    return rotateLeft.generateSynth();
  }
}

/// Rotate Component.
class RotateComponent extends Module {
  late final RotateLeft rotateLeft;
  late final RotateRight rotateRight;
  RotateComponent(Logic original, Logic rotateAmount, int? maxAmount) {
    rotateLeft = RotateLeft(original, rotateAmount, maxAmount: maxAmount);
    rotateRight = RotateRight(original, rotateAmount, maxAmount: maxAmount);
  }
}

class WebPageGenerator {
  final List<ConfigGenerator> generators = [RotateGenerator()];
}
