import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confapp/app.dart';
import 'package:confapp/hcl_bloc_observer.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

//TODO: temporary example module here!
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
  // TODO: implement exampleTestVectors
  List<Vector> get exampleTestVectors => throw UnimplementedError();
}

final List<Configurator> hclComponents = [
  RotateConfigurator(),
  PriorityArbiterConfigurator(),
  RippleCarryAdderConfigurator(),
  PipelinedIntegerMultiplierConfigurator(),
  BitonicSortConfigurator(),
  ExampleConfigurator(),
];

void main() {
  /// Initializing the [BlocObserver] created and calling runApp
  Bloc.observer = const HCLBlocObserver();

  runApp(HCLApp(
    components: hclComponents,
  ));
}
