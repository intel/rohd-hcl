import 'dart:html';
import 'package:rohd_hcl/rohd_hcl.dart';
// import 'package:rohd/rohd.dart';

Iterable<String> thingsTodo() sync* {
  const actions = ['Walk', 'Wash', 'Feed'];
  const pets = ['cats', 'dogs'];

  for (final action in actions) {
    for (final pet in pets) {
      if (pet != 'cats' || action == 'Feed') {
        yield '$action the $pet';
      }
    }
  }
}

LIElement newLI(String itemText) => LIElement()..text = itemText;

void main() {
  querySelector('#output')?.children.addAll(thingsTodo().map(newLI));
}


// abstract class ConfigKnob {
//   final String name;
//   ConfigKnob(this.name);
// }

// class IntConfigKnob extends ConfigKnob {
//   int? value;
//   IntConfigKnob(super.name);
// }

// class StringConfigKnob extends ConfigKnob {
//   String? value;
//   StringConfigKnob(super.name);
// }

// class BoolConfigKnob extends ConfigKnob {
//   bool? value;
//   BoolConfigKnob(super.name);
// }

// class MultiSelectKnob<EnumType extends Enum> extends ConfigKnob {
//   EnumType? type;
//   MultiSelectKnob(super.name);
// }

// abstract class PrototypeGenerator {
//   // things it needs to do:
//   //  - supply knobs for configurability
//   //  - default configuration
//   //  - generate smoke test
//   //  - collect waveforms of smoke test
//   //  - convert waveforms to wavedrom
//   //  - generate a schematic
//   //  - generate verilog

//   Map<String, ConfigKnob> get knobs;

//   Map<String, dynamic> get defaultKnobValues;

//   List<Vector> exampleStimulus(Map<String, dynamic> knobValues);

//   Prototype generate(Map<String, dynamic> knobValues) {
//     return Prototype(buildModule(knobValues));
//   }

//   @protected
//   Module buildModule(Map<String, dynamic> knobValues);

//   void generateWaves() {
//     //TODO
//   }

//   void generateWaveDrom() {
//     generateWaves();
//   }
// }

// class Prototype {
//   final Module module;
//   Prototype(this.module);
// }