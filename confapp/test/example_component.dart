import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/simcompare.dart';

enum ExampleEnum { yes, no, maybe }

class ExampleModule extends Module {
  ExampleModule() {
    addInput('inp', Logic());
  }
}

class ExampleConfigurator extends Configurator {
  @override
  Module createModule() => ExampleModule();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'a': StringConfigKnob(value: 'apple'),
    'b': IntConfigKnob(value: 5),
    'c': ToggleConfigKnob(value: true),
    'd': ChoiceConfigKnob<ExampleEnum>(ExampleEnum.values,
        value: ExampleEnum.maybe),
    'e': ListOfKnobsKnob(
        count: 3, generateKnob: (i) => IntConfigKnob(value: i), name: 'MyList'),
    'f': GroupOfKnobs({
      '1': StringConfigKnob(value: '1'),
      '2': StringConfigKnob(value: '2'),
    }, name: 'MyGroup'),
  };

  @override
  String get name => 'exampleName';

  @override
  List<Vector> get exampleTestVectors => throw UnimplementedError();
}
