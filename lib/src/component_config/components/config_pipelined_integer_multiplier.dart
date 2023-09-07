import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd/rohd.dart';

class PipelinedIntegerMultiplierConfigurator extends Configurator {
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 16);

  @override
  final name = 'Carry Save Multiplier';

  @override
  Module createModule() => CarrySaveMultiplier(
        Logic(width: logicWidthKnob.value),
        Logic(width: logicWidthKnob.value),
        clk: Logic(),
        reset: Logic(),
      );

  @override
  // TODO: implement exampleTestVectors
  List<Vector> get exampleTestVectors => throw UnimplementedError();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'Width': logicWidthKnob,
  };
}
