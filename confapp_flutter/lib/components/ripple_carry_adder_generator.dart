import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd/rohd.dart';
import 'package:confapp_flutter/components/config.dart';

class RippleCarryAdderComponent extends Module {
  late final RippleCarryAdder rca;
  RippleCarryAdderComponent(int width) {
    rca = RippleCarryAdder(
      Logic(name: 'a', width: width),
      Logic(name: 'b', width: width),
    );
  }
}

class RippleCarryAdderGenerator extends ConfigGenerator {
  final IntConfigKnob logicWidthKnob =
      IntConfigKnob('Logic Width', defaultVal: 16);

  @override
  final componentName = 'Ripple Carry Adder';

  @override
  late final List<ConfigKnob> knobs = [logicWidthKnob];

  @override
  Future<String> generate() async {
    var rca = RippleCarryAdderComponent(
            logicWidthKnob.value ?? logicWidthKnob.defaultVal)
        .rca;

    await rca.build();
    return rca.generateSynth();
  }
}
