import 'package:rohd_hcl/rohd_hcl.dart';

class GroupOfKnobs extends ConfigKnob<String> {
  final Map<String, ConfigKnob<dynamic>> subKnobs;

  String get name => value;

  GroupOfKnobs(this.subKnobs, {String name = 'Group'}) : super(value: name);

  @override
  Map<String, dynamic> toJson() => {
        for (final subKnob in subKnobs.entries)
          subKnob.key: subKnob.value.toJson(),
      };

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    for (final subKnobJsonMap in decodedJson.entries) {
      subKnobs[subKnobJsonMap.key]!
          .loadJson(subKnobJsonMap.value as Map<String, dynamic>);
    }
  }
}
