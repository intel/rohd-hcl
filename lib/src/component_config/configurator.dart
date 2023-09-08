import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd/src/utilities/simcompare.dart';

abstract class Configurator {
  String get name;

  Map<String, ConfigKnob<dynamic>> get knobs;

  Future<String> generateSV() async {
    print('creating module');
    final mod = createModule();
    print('building module');
    await mod.build();
    print('generating sv');
    return mod.generateSynth();
  }

  Module createModule();

  List<Vector> get exampleTestVectors;
  void runExampleTest() {}

  String saveYaml() {
    return 'TODO';
  }

  void loadYaml() {}
}


// Things to do:
//  - read/write to YAML
//  - smoke test
//  - pass to config app
//  - create schematic