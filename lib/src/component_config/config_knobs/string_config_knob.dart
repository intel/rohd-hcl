import 'package:rohd_hcl/rohd_hcl.dart';

class StringConfigKnob extends ConfigKnob<String> {
  StringConfigKnob({required super.value});

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    value = decodedJson['value'] as String;
  }
}
