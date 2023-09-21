import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class RippleCarryAdderConfigurator extends Configurator {
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 16);

  @override
  final name = 'Ripple Carry Adder';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'Width': logicWidthKnob,
  };

  @override
  Module createModule() => RippleCarryAdder(
        Logic(width: logicWidthKnob.value),
        Logic(width: logicWidthKnob.value),
      );

  @override
  // TODO: implement exampleTestVectors
  List<Vector> get exampleTestVectors => throw UnimplementedError();
}
