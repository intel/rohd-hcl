import 'package:rohd_hcl/rohd_hcl.dart';

class ChoiceConfigKnob<T> extends ConfigKnob<T> {
  List<T> choices;
  ChoiceConfigKnob(this.choices, {required super.value});

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    value = choices.firstWhere(
        (element) => element.toString() == decodedJson['value'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {'value': value.toString()};
}
