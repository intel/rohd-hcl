import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/sanitizer.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

abstract class Configurator {
  String get name;

  String get sanitaryName => Sanitizer.sanitizeSV(name);

  Map<String, ConfigKnob<dynamic>> get knobs;

  Future<String> generateSV() async {
    final mod = createModule();

    await mod.build();

    return mod.generateSynth();
  }

  Module createModule();

  List<Vector> get exampleTestVectors;
  void runExampleTest() {}

  String saveYaml() => 'TODO';

  void loadYaml() {}
}


// Things to do:
//  - read/write to YAML
//  - smoke test
//  - pass to config app
//  - create schematic
