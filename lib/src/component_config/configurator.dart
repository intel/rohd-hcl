import 'dart:convert';

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

  /// Creates a [Module] instance as configured.
  Module createModule();

  List<Vector> get exampleTestVectors;
  void runExampleTest() {}

  String toJson({bool pretty = false}) =>
      JsonEncoder.withIndent(pretty ? '  ' : null).convert({
        'name': name,
        'knobs': {
          for (final knob in knobs.entries) knob.key: knob.value.toJson(),
        },
      });

  void loadJson(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    assert(decoded['name'] == name, 'Expect name to be the same.');

    for (final decodedKnob in (decoded['knobs'] as Map).entries) {
      knobs[decodedKnob.key]!
          .loadJson(decodedKnob.value as Map<String, dynamic>);
    }
  }
}


// Things to do:
//  - read/write to YAML
//  - smoke test
//  - pass to config app
//  - create schematic
