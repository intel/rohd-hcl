import 'dart:collection';

import 'package:rohd_hcl/rohd_hcl.dart';

class ListOfKnobsKnob extends ConfigKnob<int> {
  final ConfigKnob<dynamic> Function(int index) generateKnob;

  final Map<int, ConfigKnob<dynamic>> _subKnobs = {};

  final String name;

  List<ConfigKnob<dynamic>> get knobs => UnmodifiableListView(List.generate(
        value,
        (i) => _subKnobs.update(
          i,
          (value) => value,
          ifAbsent: () => generateKnob(i),
        ),
        growable: false,
      ));

  ListOfKnobsKnob(
      {required int count, required this.generateKnob, this.name = 'List'})
      : super(value: count);

  @override
  Map<String, dynamic> toJson() =>
      {'knobs': knobs.map((e) => e.toJson()).toList()};

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    final knobsList = decodedJson['knobs'] as List<dynamic>;
    value = knobsList.length;

    for (final (i, knob) in knobs.indexed) {
      knob.loadJson(knobsList[i] as Map<String, dynamic>);
    }
  }
}
