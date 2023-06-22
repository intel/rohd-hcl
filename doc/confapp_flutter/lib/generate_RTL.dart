import 'package:flutter/material.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd/rohd.dart';

abstract class ConfigKnob<T> {
  final String name;
  T? value;

  ConfigKnob(this.name);
}

class IntConfigKnob<int> extends ConfigKnob {
  IntConfigKnob(super.name);
}

class StringConfigKnob<String> extends ConfigKnob {
  StringConfigKnob(super.name);
}

abstract class ConfigGenerator {
  List<ConfigKnob> get knobs;
  Future<String> generate();
}

class RotateGenerator extends ConfigGenerator {
  final IntConfigKnob originalWidthKnob = IntConfigKnob('originalWidthKnob');
  final IntConfigKnob rotateAmountWidthKnob =
      IntConfigKnob('rotateAmountWidthKnob');
  final IntConfigKnob maxAmountKnob = IntConfigKnob('maxAmountKnob');
  final StringConfigKnob rotateDirectionKnob =
      StringConfigKnob('rotateDirectionKnob');
  // radio button to choose which component to generate? Rotate Left or Right

  @override
  late final List<ConfigKnob> knobs = [
    originalWidthKnob,
    rotateAmountWidthKnob,
    rotateDirectionKnob
  ];

  @override
  Future<String> generate() async {
    var rotate = RotateComponent(
      Logic(width: originalWidthKnob.value ?? 10),
      Logic(width: rotateAmountWidthKnob.value ?? 10),
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

/// Rotate Component.
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

class WebPageGenerator {
  final List<ConfigGenerator> generators = [RotateGenerator()];
}
