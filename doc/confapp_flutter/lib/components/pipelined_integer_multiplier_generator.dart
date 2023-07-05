import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd/rohd.dart';
import 'package:confapp_flutter/components/config.dart';

class PipelinedIntegerMultiplierComponent extends Module {
  late final CarrySaveMultiplier csm;
  PipelinedIntegerMultiplierComponent(int width, int clockPeriod) {
    csm = CarrySaveMultiplier(
      Logic(name: 'a', width: width),
      Logic(name: 'b', width: width),
      clk: SimpleClockGenerator(clockPeriod).clk,
      reset: Logic(name: 'reset'),
    );
  }
}

class PipelinedIntegerMultiplierGenerator extends ConfigGenerator {
  final IntConfigKnob logicWidthKnob =
      IntConfigKnob('Logic Width', defaultVal: 16);
  final IntConfigKnob clockPeriodKnob =
      IntConfigKnob('Clock Period', defaultVal: 10);

  @override
  final componentName = 'Carry Save Multiplier';

  @override
  late final List<ConfigKnob> knobs = [logicWidthKnob, clockPeriodKnob];

  @override
  Future<String> generate() async {
    var csm = PipelinedIntegerMultiplierComponent(
      logicWidthKnob.value,
      clockPeriodKnob.value,
    ).csm;

    await csm.build();
    return csm.generateSynth();
  }
}
