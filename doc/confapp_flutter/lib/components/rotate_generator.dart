import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd/rohd.dart';
import 'package:confapp_flutter/components/config.dart';

class RotateComponent extends Module {
  late final RotateLeft rotateLeft;
  late final RotateRight rotateRight;
  RotateComponent(
    Logic original,
    Logic rotateAmount,
    int? maxAmount,
  ) {
    rotateLeft = RotateLeft(original, rotateAmount, maxAmount: maxAmount);
    rotateRight = RotateRight(
      original,
      rotateAmount,
      maxAmount: maxAmount,
    );
  }
}

class RotateGenerator extends ConfigGenerator {
  final IntConfigKnob originalWidthKnob =
      IntConfigKnob('originalWidthKnob', defaultVal: 16);
  final IntConfigKnob rotateAmountWidthKnob =
      IntConfigKnob('rotateAmountWidthKnob', defaultVal: 8);
  final IntConfigKnob maxAmountKnob =
      IntConfigKnob('maxAmountKnob', defaultVal: 20);
  final StringConfigKnob rotateDirectionKnob =
      StringConfigKnob('rotateDirectionKnob', defaultVal: 'right');
  // radio button to choose which component to generate? Rotate Left or Right

  @override
  final componentName = 'Rotate';

  @override
  late final List<ConfigKnob> knobs = [
    originalWidthKnob,
    rotateAmountWidthKnob,
    rotateDirectionKnob
  ];

  @override
  Future<String> generate() async {
    var rotate = RotateComponent(
      Logic(width: originalWidthKnob.value ?? originalWidthKnob.defaultVal),
      Logic(
          width:
              rotateAmountWidthKnob.value ?? rotateAmountWidthKnob.defaultVal),
      maxAmountKnob.value,
    );

    Module rotateCom;
    if (rotateDirectionKnob.value == 'left') {
      rotateCom = rotate.rotateLeft;
    } else {
      rotateCom = rotate.rotateRight;
    }

    await rotateCom.build();
    return rotateCom.generateSynth();
  }
}
