import 'package:rohd_hcl/rohd_hcl.dart';

class ChoiceConfigKnob<T> extends ConfigKnob<T> {
  List<T> choices;
  ChoiceConfigKnob(this.choices, {required super.value});
}
